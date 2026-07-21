package com.videomoney.app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.appnext.ads.fullscreen.RewardedVideo
import com.appnext.core.callbacks.OnAdClosed
import com.appnext.core.callbacks.OnAdError
import com.appnext.core.callbacks.OnAdOpened
import com.appnext.core.callbacks.OnVideoEnded
import com.appodeal.ads.Appodeal
import com.appodeal.ads.RewardedVideoCallbacks
import com.appodeal.ads.initializing.ApdInitializationCallback
import com.appodeal.ads.initializing.ApdInitializationError
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.AdListener
import com.facebook.ads.AdSize
import com.facebook.ads.AdView
import com.facebook.ads.AudienceNetworkAds
import com.facebook.ads.InterstitialAd
import com.facebook.ads.InterstitialAdListener
import com.facebook.ads.RewardedInterstitialAd
import com.facebook.ads.RewardedInterstitialAdListener
import com.vungle.ads.AdConfig
import com.vungle.ads.BaseAd
import com.vungle.ads.InitializationListener
import com.vungle.ads.RewardedAd as LiftoffRewardedAd
import com.vungle.ads.RewardedAdListener
import com.vungle.ads.VungleAds
import com.vungle.ads.VungleError
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var rewardedVideoChannel: MethodChannel? = null
    private var appnextRewardedVideo: RewardedVideo? = null
    private var liftoffRewardedAd: LiftoffRewardedAd? = null
    private var metaRewardedInterstitialAd: RewardedInterstitialAd? = null
    private var metaInterstitialAd: InterstitialAd? = null
    private var metaBannerAdView: AdView? = null
    private var liftoffInitialized = false
    private var liftoffInitStarted = false
    private var liftoffRewardedLoaded = false
    private var mobFoxRewardedLoaded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GraviteAatkitManager.setEventListener(::emitEvent)
        initializeLiftoffIfNeeded()
        configureRewardedVideoCallbacks()
        initializeAppnextIfNeeded()
        initializeAppodealIfNeeded()
        preloadMobFoxRewardedVideo()
    }

    override fun onResume() {
        super.onResume()
        GraviteAatkitManager.onActivityResume(this)
    }

    override fun onPause() {
        GraviteAatkitManager.onActivityPause(this)
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        rewardedVideoChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REWARDED_VIDEO_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "preloadMobFoxRewardedVideo" -> {
                        preloadMobFoxRewardedVideo()
                        result.success(null)
                    }

                    "isMobFoxRewardedVideoLoaded" -> {
                        result.success(mobFoxRewardedLoaded && MobFoxRewardedManager.isLoaded())
                    }

                    "showMobFoxRewardedVideo" -> {
                        result.success(showMobFoxRewardedVideo())
                    }

                    "preloadGraviteRewardedVideo" -> {
                        GraviteAatkitManager.preloadRewardedVideo()
                        result.success(null)
                    }

                    "isGraviteRewardedVideoLoaded" -> {
                        result.success(GraviteAatkitManager.isRewardedVideoLoaded())
                    }

                    "showGraviteRewardedVideo" -> {
                        result.success(GraviteAatkitManager.showRewardedVideo())
                    }

                    "preloadLiftoffRewardedVideo" -> {
                        preloadLiftoffRewardedVideo()
                        result.success(null)
                    }

                    "isLiftoffRewardedVideoLoaded" -> {
                        result.success(liftoffRewardedLoaded && liftoffRewardedAd?.canPlayAd() == true)
                    }

                    "showLiftoffRewardedVideo" -> {
                        val rewardedAd = liftoffRewardedAd
                        if (rewardedAd != null && liftoffRewardedLoaded && rewardedAd.canPlayAd()) {
                            liftoffRewardedLoaded = false
                            rewardedAd.play()
                            result.success(true)
                        } else {
                            preloadLiftoffRewardedVideo()
                            result.success(false)
                        }
                    }

                    "ensureAppodealInitialized" -> {
                        initializeAppodealIfNeeded()
                        result.success(Appodeal.isInitialized(REWARDED_VIDEO_TYPE))
                    }

                    "isRewardedVideoLoaded" -> {
                        result.success(Appodeal.isLoaded(REWARDED_VIDEO_TYPE))
                    }

                    "preloadRewardedVideo" -> {
                        cacheRewardedVideo()
                        result.success(null)
                    }

                    "preloadAppnextRewardedVideo" -> {
                        preloadAppnextRewardedVideo()
                        result.success(null)
                    }

                    "preloadMetaRewardedInterstitial" -> {
                        preloadMetaRewardedInterstitial()
                        result.success(null)
                    }

                    "isMetaRewardedInterstitialLoaded" -> {
                        result.success(
                            metaRewardedInterstitialAd?.isAdLoaded == true &&
                                metaRewardedInterstitialAd?.isAdInvalidated != true,
                        )
                    }

                    "showMetaRewardedInterstitial" -> {
                        val rewardedInterstitialAd = metaRewardedInterstitialAd
                        val canShow = rewardedInterstitialAd?.isAdLoaded == true &&
                            rewardedInterstitialAd.isAdInvalidated != true
                        if (canShow) {
                            Log.d(
                                LOG_TAG,
                                "[rewarded][meta] show requested placement=" +
                                    "${BuildConfig.META_REWARDED_INTERSTITIAL_PLACEMENT_ID} " +
                                    "loaded=${rewardedInterstitialAd?.isAdLoaded} " +
                                    "invalidated=${rewardedInterstitialAd?.isAdInvalidated}",
                            )
                            rewardedInterstitialAd?.show()
                            result.success(true)
                        } else {
                            val loaded = rewardedInterstitialAd?.isAdLoaded == true
                            val invalidated = rewardedInterstitialAd?.isAdInvalidated == true
                            val message =
                                "Meta show blocked: loaded=$loaded invalidated=$invalidated " +
                                    "placement=${BuildConfig.META_REWARDED_INTERSTITIAL_PLACEMENT_ID}"
                            Log.w(LOG_TAG, "[rewarded][meta] $message")
                            emitEvent(
                                "onMetaRewardedInterstitialError",
                                mapOf(
                                    "error" to message,
                                    "code" to -1,
                                ),
                            )
                            preloadMetaRewardedInterstitial()
                            result.success(false)
                        }
                    }

                    "isAppnextRewardedVideoLoaded" -> {
                        result.success(appnextRewardedVideo?.isAdLoaded == true)
                    }

                    "showRewardedVideo" -> {
                        if (!Appodeal.isLoaded(REWARDED_VIDEO_TYPE)) {
                            cacheRewardedVideo()
                            result.success(false)
                        } else {
                            result.success(Appodeal.show(this, REWARDED_VIDEO_TYPE))
                        }
                    }

                    "showAppnextRewardedVideo" -> {
                        val rewardedVideo = appnextRewardedVideo
                        if (rewardedVideo?.isAdLoaded == true) {
                            Log.d(LOG_TAG, "[rewarded][appnext] showing.")
                            rewardedVideo.showAd()
                            result.success(true)
                        } else {
                            preloadAppnextRewardedVideo()
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        rewardedVideoChannel?.setMethodCallHandler(null)
        rewardedVideoChannel = null
        GraviteAatkitManager.setEventListener(null)
        liftoffRewardedAd = null
        metaRewardedInterstitialAd?.destroy()
        metaRewardedInterstitialAd = null
        metaInterstitialAd?.destroy()
        metaInterstitialAd = null
        metaBannerAdView?.destroy()
        metaBannerAdView = null
        MobFoxRewardedManager.clear()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != MOBFOX_REWARDED_REQUEST_CODE) {
            return
        }
        val rewarded =
            data?.getBooleanExtra(MobFoxRewardedActivity.EXTRA_REWARDED, false) == true
        val error = data?.getStringExtra(MobFoxRewardedActivity.EXTRA_ERROR)
        if (rewarded) {
            emitEvent("onMobFoxRewardedVideoCompleted")
        }
        if (!error.isNullOrBlank()) {
            emitEvent("onMobFoxRewardedVideoError", mapOf("error" to error))
        }
        emitEvent("onMobFoxRewardedVideoClosed")
        preloadMobFoxRewardedVideo()
    }

    private fun configureRewardedVideoCallbacks() {
        Appodeal.setRewardedVideoCallbacks(object : RewardedVideoCallbacks {
            override fun onRewardedVideoLoaded(isPrecache: Boolean) {
                Log.d(LOG_TAG, "[rewarded][appodeal] loaded.")
                emitEvent("onRewardedVideoLoaded", mapOf("isPrecache" to isPrecache))
            }

            override fun onRewardedVideoFailedToLoad() {
                Log.w(LOG_TAG, "[rewarded][appodeal] failed to load.")
                emitEvent("onRewardedVideoFailedToLoad")
            }

            override fun onRewardedVideoShown() {
                Log.d(LOG_TAG, "[rewarded][appodeal] shown.")
                emitEvent("onRewardedVideoShown")
            }

            override fun onRewardedVideoShowFailed() {
                Log.w(LOG_TAG, "[rewarded][appodeal] failed to show.")
                emitEvent("onRewardedVideoShowFailed")
                cacheRewardedVideo()
            }

            override fun onRewardedVideoClicked() = Unit

            override fun onRewardedVideoFinished(amount: Double, currency: String) {
                Log.d(LOG_TAG, "[rewarded][appodeal] completed.")
                emitEvent(
                    "onRewardedVideoFinished",
                    mapOf(
                        "amount" to amount,
                        "currency" to currency,
                    ),
                )
            }

            override fun onRewardedVideoClosed(finished: Boolean) {
                Log.d(LOG_TAG, "[rewarded][appodeal] closed.")
                emitEvent("onRewardedVideoClosed", mapOf("finished" to finished))
                cacheRewardedVideo()
            }

            override fun onRewardedVideoExpired() {
                Log.w(LOG_TAG, "[rewarded][appodeal] expired.")
                emitEvent("onRewardedVideoExpired")
                cacheRewardedVideo()
            }
        })
    }

    private fun initializeLiftoffIfNeeded() {
        if (liftoffInitStarted) {
            return
        }

        val appId = BuildConfig.LIFTOFF_APP_ID
        if (appId.isBlank()) {
            Log.w(LOG_TAG, "Liftoff app ID is missing.")
            return
        }

        liftoffInitStarted = true
        VungleAds.init(
            this,
            appId,
            object : InitializationListener {
                override fun onSuccess() {
                    liftoffInitialized = true
                    Log.d(LOG_TAG, "[rewarded][liftoff] init success for app $appId")
                    preloadLiftoffRewardedVideo()
                }

                override fun onError(vungleError: VungleError) {
                    liftoffInitialized = false
                    Log.w(
                        LOG_TAG,
                        "[rewarded][liftoff] init failed: ${vungleError.code} ${vungleError.errorMessage}",
                    )
                    emitEvent(
                        "onLiftoffRewardedVideoError",
                        mapOf("error" to "Liftoff init failed: ${vungleError.errorMessage}"),
                    )
                }
            },
        )
    }

    private fun preloadLiftoffRewardedVideo() {
        val placementId = BuildConfig.LIFTOFF_REWARDED_PLACEMENT_ID
        if (placementId.isBlank()) {
            Log.w(LOG_TAG, "Liftoff rewarded placement ID is missing.")
            return
        }
        if (!liftoffInitialized) {
            initializeLiftoffIfNeeded()
            return
        }
        if (liftoffRewardedLoaded && liftoffRewardedAd?.canPlayAd() == true) {
            return
        }

        liftoffRewardedLoaded = false
        liftoffRewardedAd = LiftoffRewardedAd(this, placementId, AdConfig()).apply {
            adListener = object : RewardedAdListener {
                override fun onAdLoaded(baseAd: BaseAd) {
                    liftoffRewardedLoaded = true
                    emitEvent("onLiftoffRewardedVideoLoaded")
                    Log.d(
                        LOG_TAG,
                        "[rewarded][liftoff] loaded placement=$placementId creative=${baseAd.creativeId}",
                    )
                }

                override fun onAdStart(baseAd: BaseAd) {
                    emitEvent("onLiftoffRewardedVideoShown")
                    Log.d(LOG_TAG, "[rewarded][liftoff] started placement=$placementId")
                }

                override fun onAdImpression(baseAd: BaseAd) {
                    emitEvent("onLiftoffRewardedVideoImpression")
                    Log.d(LOG_TAG, "[rewarded][liftoff] impression placement=$placementId")
                }

                override fun onAdEnd(baseAd: BaseAd) {
                    emitEvent("onLiftoffRewardedVideoClosed")
                    Log.d(LOG_TAG, "[rewarded][liftoff] closed placement=$placementId")
                    preloadLiftoffRewardedVideo()
                }

                override fun onAdClicked(baseAd: BaseAd) {
                    emitEvent("onLiftoffRewardedVideoClicked")
                    Log.d(LOG_TAG, "[rewarded][liftoff] clicked placement=$placementId")
                }

                override fun onAdLeftApplication(baseAd: BaseAd) = Unit

                override fun onAdRewarded(baseAd: BaseAd) {
                    emitEvent("onLiftoffRewardedVideoCompleted")
                    Log.d(LOG_TAG, "[rewarded][liftoff] rewarded placement=$placementId")
                }

                override fun onAdFailedToLoad(baseAd: BaseAd, adError: VungleError) {
                    liftoffRewardedLoaded = false
                    emitEvent(
                        "onLiftoffRewardedVideoError",
                        mapOf(
                            "error" to "Liftoff load failed: ${adError.errorMessage}",
                            "code" to adError.code,
                        ),
                    )
                    Log.w(
                        LOG_TAG,
                        "[rewarded][liftoff] load failed placement=$placementId: " +
                            "${adError.errorMessage} code=${adError.code}",
                    )
                }

                override fun onAdFailedToPlay(baseAd: BaseAd, adError: VungleError) {
                    liftoffRewardedLoaded = false
                    emitEvent(
                        "onLiftoffRewardedVideoError",
                        mapOf(
                            "error" to "Liftoff play failed: ${adError.errorMessage}",
                            "code" to adError.code,
                        ),
                    )
                    Log.w(
                        LOG_TAG,
                        "[rewarded][liftoff] play failed placement=$placementId: " +
                            "${adError.errorMessage} code=${adError.code}",
                    )
                    preloadLiftoffRewardedVideo()
                }
            }
            load()
        }
    }

    private fun initializeAppodealIfNeeded() {
        if (Appodeal.isInitialized(REWARDED_VIDEO_TYPE)) {
            return
        }

        val appKey = BuildConfig.APPODEAL_APP_KEY
        if (appKey == APP_KEY_PLACEHOLDER) {
            Log.w(LOG_TAG, "Appodeal app key is still using the placeholder value.")
        }

        Appodeal.initialize(
            this,
            appKey,
            REWARDED_VIDEO_TYPE,
            object : ApdInitializationCallback {
                override fun onInitializationFinished(errors: List<ApdInitializationError>?) {
                    if (errors.isNullOrEmpty()) {
                        cacheRewardedVideo()
                    } else {
                        Log.w(LOG_TAG, "Appodeal initialization completed with ${errors.size} issue(s).")
                    }
                }
            },
        )
    }

    private fun initializeMetaAudienceNetwork() {
        AudienceNetworkAds.initialize(this)
        Log.d(
            LOG_TAG,
            "Meta Audience Network SDK initialized for app ID ${BuildConfig.META_APP_ID} " +
                "and rewarded placement ${BuildConfig.META_REWARDED_INTERSTITIAL_PLACEMENT_ID}",
        )
        preloadMetaRewardedInterstitial()
        preloadMetaInterstitial()
        preloadMetaBanner()
    }

    private fun preloadMetaRewardedInterstitial() {
        val placementId = BuildConfig.META_REWARDED_INTERSTITIAL_PLACEMENT_ID
        if (placementId.isBlank()) {
            Log.w(LOG_TAG, "Meta rewarded interstitial placement ID is missing.")
            return
        }

        Log.d(
            LOG_TAG,
            "[rewarded][meta] requesting rewarded interstitial for placement $placementId " +
                "appId=${BuildConfig.META_APP_ID}",
        )
        metaRewardedInterstitialAd?.destroy()
        metaRewardedInterstitialAd = RewardedInterstitialAd(this, placementId).apply {
            loadAd(
                buildLoadAdConfig()
                    .withAdListener(object : RewardedInterstitialAdListener {
                        override fun onError(ad: Ad?, adError: AdError) {
                            emitEvent(
                                "onMetaRewardedInterstitialError",
                                mapOf(
                                    "error" to adError.errorMessage,
                                    "code" to adError.errorCode,
                                    "placementId" to placementId,
                                ),
                            )
                            Log.w(
                                LOG_TAG,
                                "[rewarded][meta] load failed for placement $placementId: " +
                                    "${adError.errorMessage} (code=${adError.errorCode})",
                            )
                        }

                        override fun onAdLoaded(ad: Ad?) {
                            emitEvent("onMetaRewardedInterstitialLoaded")
                            Log.d(
                                LOG_TAG,
                                "[rewarded][meta] loaded for placement $placementId " +
                                    "invalidated=${metaRewardedInterstitialAd?.isAdInvalidated}",
                            )
                        }

                        override fun onAdClicked(ad: Ad?) {
                            emitEvent("onMetaRewardedInterstitialClicked")
                            Log.d(LOG_TAG, "[rewarded][meta] clicked for placement $placementId")
                        }

                        override fun onLoggingImpression(ad: Ad?) {
                            emitEvent("onMetaRewardedInterstitialShown")
                            Log.d(LOG_TAG, "[rewarded][meta] impression logged for placement $placementId")
                        }

                        override fun onRewardedInterstitialCompleted() {
                            emitEvent("onMetaRewardedInterstitialCompleted")
                            Log.d(LOG_TAG, "[rewarded][meta] reward completed for placement $placementId")
                        }

                        override fun onRewardedInterstitialClosed() {
                            emitEvent("onMetaRewardedInterstitialClosed")
                            Log.d(LOG_TAG, "[rewarded][meta] closed for placement $placementId")
                            preloadMetaRewardedInterstitial()
                        }
                    })
                    .build(),
            )
        }
    }

    private fun preloadMetaInterstitial() {
        val placementId = BuildConfig.META_INTERSTITIAL_PLACEMENT_ID
        if (placementId.isBlank()) {
            Log.w(LOG_TAG, "Meta interstitial placement ID is missing.")
            return
        }

        metaInterstitialAd?.destroy()
        metaInterstitialAd = InterstitialAd(this, placementId).apply {
            loadAd(
                buildLoadAdConfig()
                    .withAdListener(object : InterstitialAdListener {
                        override fun onInterstitialDisplayed(ad: Ad?) {
                            Log.d(LOG_TAG, "[interstitial][meta] shown.")
                        }

                        override fun onInterstitialDismissed(ad: Ad?) {
                            preloadMetaInterstitial()
                            Log.d(LOG_TAG, "Meta interstitial dismissed.")
                        }

                        override fun onError(ad: Ad?, adError: AdError) {
                            Log.w(LOG_TAG, "Meta interstitial load failed: ${adError.errorMessage}")
                        }

                        override fun onAdLoaded(ad: Ad?) {
                            Log.d(LOG_TAG, "Meta interstitial loaded.")
                        }

                        override fun onAdClicked(ad: Ad?) = Unit

                        override fun onLoggingImpression(ad: Ad?) = Unit
                    })
                    .build(),
            )
        }
    }

    private fun preloadMetaBanner() {
        val placementId = BuildConfig.META_BANNER_PLACEMENT_ID
        if (placementId.isBlank()) {
            Log.w(LOG_TAG, "Meta banner placement ID is missing.")
            return
        }

        metaBannerAdView?.destroy()
        metaBannerAdView = AdView(this, placementId, AdSize.BANNER_HEIGHT_50).apply {
            loadAd(
                buildLoadAdConfig()
                    .withAdListener(object : AdListener {
                        override fun onError(ad: Ad?, adError: AdError) {
                            Log.w(LOG_TAG, "Meta banner load failed: ${adError.errorMessage}")
                        }

                        override fun onAdLoaded(ad: Ad?) {
                            Log.d(LOG_TAG, "Meta banner loaded.")
                        }

                        override fun onAdClicked(ad: Ad?) = Unit

                        override fun onLoggingImpression(ad: Ad?) = Unit
                    })
                    .build(),
            )
        }
    }

    private fun initializeAppnextIfNeeded() {
        createAppnextRewardedIfNeeded()
    }

    private fun createAppnextRewardedIfNeeded() {
        val placementId = BuildConfig.APPNEXT_PLACEMENT_ID
        if (placementId.isBlank()) {
            Log.w(LOG_TAG, "Appnext placement ID is missing, rewarded fallback disabled.")
            return
        }
        if (appnextRewardedVideo != null) {
            return
        }

        appnextRewardedVideo = RewardedVideo(this, placementId).apply {
            setOnAdOpenedCallback(object : OnAdOpened {
                override fun adOpened() {
                    emitEvent("onAppnextRewardedVideoOpened")
                }
            })
            setOnAdClosedCallback(object : OnAdClosed {
                override fun onAdClosed() {
                    emitEvent("onAppnextRewardedVideoClosed")
                    preloadAppnextRewardedVideo()
                }
            })
            setOnAdErrorCallback(object : OnAdError {
                override fun adError(error: String) {
                    emitEvent("onAppnextRewardedVideoError", mapOf("error" to error))
                }
            })
            setOnVideoEndedCallback(object : OnVideoEnded {
                override fun videoEnded() {
                    emitEvent("onAppnextRewardedVideoEnded")
                }
            })
        }
        preloadAppnextRewardedVideo()
    }

    private fun preloadAppnextRewardedVideo() {
        val rewardedVideo = appnextRewardedVideo ?: return
        if (!rewardedVideo.isAdLoaded) {
            Log.d(LOG_TAG, "[rewarded][appnext] requesting load.")
            rewardedVideo.loadAd()
        }
    }

    private fun cacheRewardedVideo() {
        if (Appodeal.isInitialized(REWARDED_VIDEO_TYPE) &&
            !Appodeal.isLoaded(REWARDED_VIDEO_TYPE)
        ) {
            Log.d(LOG_TAG, "[rewarded][appodeal] requesting load.")
            Appodeal.cache(this, REWARDED_VIDEO_TYPE)
        }
    }

    private fun preloadMobFoxRewardedVideo() {
        if (mobFoxRewardedLoaded || MobFoxRewardedManager.isLoaded()) {
            mobFoxRewardedLoaded = true
            return
        }
        MobFoxRewardedManager.preload(
            context = this,
            onLoaded = {
                mobFoxRewardedLoaded = true
                emitEvent("onMobFoxRewardedVideoLoaded")
                Log.d(LOG_TAG, "[rewarded][mobfox] loaded VAST tag.")
            },
            onError = { message ->
                mobFoxRewardedLoaded = false
                emitEvent("onMobFoxRewardedVideoError", mapOf("error" to message))
                Log.w(LOG_TAG, "[rewarded][mobfox] failed: $message")
            },
        )
    }

    private fun showMobFoxRewardedVideo(): Boolean {
        if (!MobFoxRewardedManager.isLoaded()) {
            mobFoxRewardedLoaded = false
            preloadMobFoxRewardedVideo()
            return false
        }
        mobFoxRewardedLoaded = false
        emitEvent("onMobFoxRewardedVideoShown")
        @Suppress("DEPRECATION")
        startActivityForResult(
            Intent(this, MobFoxRewardedActivity::class.java),
            MOBFOX_REWARDED_REQUEST_CODE,
        )
        Log.d(LOG_TAG, "[rewarded][mobfox] showing rewarded video.")
        return true
    }

    private fun emitEvent(method: String, arguments: Map<String, Any?> = emptyMap()) {
        rewardedVideoChannel?.invokeMethod(method, arguments)
    }

    companion object {
        private const val REWARDED_VIDEO_CHANNEL = "com.videomoney.app/rewarded_video"
        private const val REWARDED_VIDEO_TYPE = Appodeal.REWARDED_VIDEO
        private const val APP_KEY_PLACEHOLDER = "APPODEAL_APP_KEY"
        private const val MOBFOX_REWARDED_REQUEST_CODE = 7149
        private const val LOG_TAG = "VideoMoneyAppodeal"
    }
}
