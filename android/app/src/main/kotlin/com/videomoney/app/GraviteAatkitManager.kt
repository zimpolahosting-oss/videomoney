package com.videomoney.app

import android.app.Activity
import android.app.Application
import android.util.Log
import com.intentsoftware.addapptr.AATKit
import com.intentsoftware.addapptr.AATKitAdNetworkOptions
import com.intentsoftware.addapptr.AATKitConfiguration
import com.intentsoftware.addapptr.AATKitReward
import com.intentsoftware.addapptr.AATKitRuntimeConfiguration
import com.intentsoftware.addapptr.GraviteRTBOptions
import com.intentsoftware.addapptr.ManagedConsent
import com.intentsoftware.addapptr.Placement
import com.intentsoftware.addapptr.RewardedVideoPlacement
import com.intentsoftware.addapptr.RewardedVideoPlacementListener
import com.intentsoftware.addapptr.consent.google.CMPGoogle

object GraviteAatkitManager :
    RewardedVideoPlacementListener,
    ManagedConsent.ManagedConsentDelegate {
    private const val LOG_TAG = "GraviteAATKit"

    private var initialized = false
    private var rewardedPlacement: RewardedVideoPlacement? = null
    private var rewardedLoaded = false
    private var currentActivity: Activity? = null
    private var managedConsent: ManagedConsent? = null
    private var eventListener: ((String, Map<String, Any?>) -> Unit)? = null

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
        managedConsent?.editConsent(activity)
    }

    fun onActivityResume(activity: Activity) {
        currentActivity = activity
        ensureInitialized(activity.application)
        ensureManagedConsent(activity)
        AATKit.onActivityResume(activity)
        rewardedPlacement?.listener = this
        rewardedPlacement?.startAutoReload()
        rewardedLoaded = rewardedPlacement?.hasAd() == true
    }

    fun onActivityPause(activity: Activity) {
        rewardedPlacement?.stopAutoReload()
        AATKit.onActivityPause(activity)
        if (currentActivity === activity) {
            currentActivity = null
        }
    }

    fun preloadRewardedVideo() {
        rewardedPlacement?.startAutoReload()
        rewardedLoaded = rewardedPlacement?.hasAd() == true
    }

    fun isRewardedVideoLoaded(): Boolean {
        return rewardedPlacement?.hasAd() == true || rewardedLoaded
    }

    fun showRewardedVideo(): Boolean {
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

    private fun ensureManagedConsent(activity: Activity) {
        if (managedConsent != null) return
        val consent = ManagedConsent(
            CMPGoogle(activity),
            activity.applicationContext,
            this,
            ManagedConsent.ShowIfNeededSetting.SERVER_SIDE_CONTROL,
        )
        managedConsent = consent
        val newConfiguration = AATKitRuntimeConfiguration().apply {
            this.consent = consent
        }
        AATKit.reconfigure(newConfiguration)
        consent.showIfNeeded(activity)
    }

    override fun managedConsentNeedsUserInterface(managedConsent: ManagedConsent) {
        currentActivity?.let { managedConsent.showIfNeeded(it) }
    }

    override fun managedConsentCMPFinished(state: ManagedConsent.ManagedConsentState) {
        Log.d(LOG_TAG, "[consent] managed consent finished with state=$state")
    }

    override fun managedConsentCMPFailedToLoad(
        managedConsent: ManagedConsent,
        error: String?,
    ) {
        Log.w(LOG_TAG, "[consent] managed consent failed to load: $error")
    }

    override fun managedConsentCMPFailedToShow(
        managedConsent: ManagedConsent,
        error: String?,
    ) {
        Log.w(LOG_TAG, "[consent] managed consent failed to show: $error")
    }
}
