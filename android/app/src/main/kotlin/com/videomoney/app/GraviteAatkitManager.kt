package com.videomoney.app

import android.app.Activity
import android.app.Application
import android.util.Log
import com.intentsoftware.addapptr.AATKit
import com.intentsoftware.addapptr.AATKitAdNetworkOptions
import com.intentsoftware.addapptr.AATKitConfiguration
import com.intentsoftware.addapptr.AATKitReward
import com.intentsoftware.addapptr.GraviteRTBOptions
import com.intentsoftware.addapptr.Placement
import com.intentsoftware.addapptr.RewardedVideoPlacement
import com.intentsoftware.addapptr.RewardedVideoPlacementListener
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform

object GraviteAatkitManager :
    RewardedVideoPlacementListener {
    private const val LOG_TAG = "GraviteAATKit"

    private var initialized = false
    private var rewardedPlacement: RewardedVideoPlacement? = null
    private var rewardedLoaded = false
    private var currentActivity: Activity? = null
    private var eventListener: ((String, Map<String, Any?>) -> Unit)? = null
    private var consentInformation: ConsentInformation? = null
    private var consentFlowStarted = false
    private var consentFlowCompleted = false
    private var canRequestAds = false
    private var pendingPreload = false

    fun initialize(application: Application) {
        if (initialized) {
            return
        }

        val configuration = AATKitConfiguration(application).apply {
            adNetworkOptions = AATKitAdNetworkOptions().apply {
                graviteRTBOptions = GraviteRTBOptions(false)
            }
            isUseDebugShake = BuildConfig.DEBUG
        }

        BuildConfig.GRAVITE_TEST_MODE_ACCOUNT_ID
            .trim()
            .toIntOrNull()
            ?.let { configuration.setTestModeAccountId(it) }

        AATKit.init(configuration)
        rewardedPlacement = AATKit.createRewardedVideoPlacement(
            BuildConfig.GRAVITE_REWARDED_PLACEMENT_NAME,
        )?.also {
            it.listener = this
        }
        initialized = true
        Log.d(
            LOG_TAG,
            "AATKit initialized for bundle ${application.packageName} with rewarded placement " +
                BuildConfig.GRAVITE_REWARDED_PLACEMENT_NAME,
        )
    }

    fun setEventListener(listener: ((String, Map<String, Any?>) -> Unit)?) {
        eventListener = listener
    }

    fun showPrivacyOptions(activity: Activity) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { formError ->
            if (formError != null) {
                Log.w(LOG_TAG, "[consent] privacy options failed: ${formError.message}")
            }
        }
    }

    fun onActivityResume(activity: Activity) {
        currentActivity = activity
        requestConsentAndMaybeInitialize(activity)
        if (initialized && canRequestAds) {
            AATKit.onActivityResume(activity)
            rewardedPlacement?.listener = this
            if (pendingPreload || rewardedPlacement?.hasAd() != true) {
                rewardedPlacement?.startAutoReload()
            }
            rewardedLoaded = rewardedPlacement?.hasAd() == true
        }
    }

    fun onActivityPause(activity: Activity) {
        if (initialized) {
            rewardedPlacement?.stopAutoReload()
            AATKit.onActivityPause(activity)
        }
        if (currentActivity === activity) {
            currentActivity = null
        }
    }

    fun preloadRewardedVideo() {
        pendingPreload = true
        currentActivity?.let { requestConsentAndMaybeInitialize(it) }
        if (!initialized || !canRequestAds) {
            rewardedLoaded = false
            return
        }
        rewardedPlacement?.startAutoReload()
        rewardedLoaded = rewardedPlacement?.hasAd() == true
    }

    fun isRewardedVideoLoaded(): Boolean {
        if (!initialized || !canRequestAds) return false
        return rewardedPlacement?.hasAd() == true || rewardedLoaded
    }

    fun showRewardedVideo(): Boolean {
        if (!initialized || !canRequestAds) {
            currentActivity?.let { requestConsentAndMaybeInitialize(it) }
            return false
        }
        val placement = rewardedPlacement ?: return false
        val shown = placement.show()
        if (!shown) {
            rewardedLoaded = placement.hasAd()
            placement.startAutoReload()
        }
        return shown
    }

    override fun onHaveAd(placement: Placement) {
        rewardedLoaded = true
        eventListener?.invoke("onGraviteRewardedVideoLoaded", emptyMap())
        Log.d(LOG_TAG, "[rewarded][gravite] loaded placement=${placement.name}")
    }

    override fun onNoAd(placement: Placement) {
        rewardedLoaded = false
        eventListener?.invoke(
            "onGraviteRewardedVideoError",
            mapOf("error" to "No Gravite rewarded ad available."),
        )
        Log.w(LOG_TAG, "[rewarded][gravite] no ad placement=${placement.name}")
    }

    override fun onPauseForAd(placement: Placement) {
        rewardedLoaded = false
        eventListener?.invoke("onGraviteRewardedVideoShown", emptyMap())
        Log.d(LOG_TAG, "[rewarded][gravite] shown placement=${placement.name}")
    }

    override fun onResumeAfterAd(placement: Placement) {
        eventListener?.invoke("onGraviteRewardedVideoClosed", emptyMap())
        rewardedPlacement?.startAutoReload()
        rewardedLoaded = rewardedPlacement?.hasAd() == true
        Log.d(LOG_TAG, "[rewarded][gravite] closed placement=${placement.name}")
    }

    override fun onUserEarnedIncentive(
        placement: Placement,
        aatKitReward: AATKitReward?,
    ) {
        eventListener?.invoke("onGraviteRewardedVideoCompleted", emptyMap())
        Log.d(
            LOG_TAG,
            "[rewarded][gravite] rewarded placement=${placement.name} " +
                "reward=${aatKitReward?.name ?: "unknown"}",
        )
    }

    private fun ensureInitialized(application: Application) {
        if (!initialized) {
            initialize(application)
        }
    }

    private fun requestConsentAndMaybeInitialize(activity: Activity) {
        if (consentFlowCompleted) {
            if (canRequestAds) {
                ensureInitialized(activity.application)
            }
            return
        }
        if (consentFlowStarted) {
            return
        }

        consentFlowStarted = true
        val info = UserMessagingPlatform.getConsentInformation(activity)
        consentInformation = info
        val params = ConsentRequestParameters.Builder().build()
        info.requestConsentInfoUpdate(
            activity,
            params,
            {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { formError ->
                    if (formError != null) {
                        Log.w(LOG_TAG, "[consent] UMP form issue: ${formError.message}")
                    }
                    completeConsentFlow(activity)
                }
            },
            { requestError ->
                Log.w(LOG_TAG, "[consent] UMP request failed: ${requestError.message}")
                completeConsentFlow(activity)
            },
        )
    }

    private fun completeConsentFlow(activity: Activity) {
        consentFlowCompleted = true
        canRequestAds = consentInformation?.canRequestAds() == true
        Log.d(LOG_TAG, "[consent] UMP finished. canRequestAds=$canRequestAds")
        if (canRequestAds) {
            ensureInitialized(activity.application)
            AATKit.onActivityResume(activity)
            rewardedPlacement?.listener = this
            if (pendingPreload || rewardedPlacement?.hasAd() != true) {
                rewardedPlacement?.startAutoReload()
            }
            rewardedLoaded = rewardedPlacement?.hasAd() == true
        } else {
            rewardedLoaded = false
            eventListener?.invoke(
                "onGraviteRewardedVideoError",
                mapOf("error" to "Consent not granted or ads not yet available."),
            )
        }
    }
}
