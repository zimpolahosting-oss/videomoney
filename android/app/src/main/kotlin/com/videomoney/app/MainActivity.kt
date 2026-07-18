package com.videomoney.app

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
import com.startapp.sdk.adsbase.Ad as StartioAd
import com.startapp.sdk.adsbase.StartAppAd
import com.startapp.sdk.adsbase.StartAppAd.AdMode
import com.startapp.sdk.adsbase.adlisteners.AdDisplayListener
import com.startapp.sdk.adsbase.adlisteners.AdEventListener
import com.startapp.sdk.adsbase.adlisteners.VideoListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var rewardedVideoChannel: MethodChannel? = null
    private var appnextRewardedVideo: RewardedVideo? = null
    private var metaRewardedInterstitialAd: RewardedInterstitialAd? = null
    private var metaInterstitialAd: InterstitialAd? = null
    private var metaBannerAdView: AdView? = null
    private var startioRewardedAd: StartAppAd? = null
    private var startioInterstitialAd: StartAppAd? = null
    private var startioRewardedLoaded = false
    private var startioInterstitialLoaded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureRewardedVideoCallbacks()
        initializeMetaAudienceNetwork()
        initializeStartioIfNeeded()
        initializeAppnextIfNeeded()
        initializeAppodealIfNeeded()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        rewardedVideoChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REWARDED_VIDEO_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
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
                            rewardedInterstitialAd?.show()
                            result.success(true)
                        } else {
                            preloadMetaRewardedInterstitial()
                            result.success(false)
                        }
                    }

                    "preloadStartioRewardedVideo" -> {
                        preloadStartioRewardedVideo()
                        result.success(null)
                    }

                    "isStartioRewardedVideoLoaded" -> {
                        result.success(startioRewardedLoaded)
                    }

                    "showStartioRewardedVideo" -> {
                        val rewardedAd = startioRewardedAd
                        if (rewardedAd != null && startioRewardedLoaded) {
                            startioRewardedLoaded = false
                            rewardedAd.showAd(createStartioRewardedDisplayListener())
                            result.success(true)
                        } else {
                            preloadStartioRewardedVideo()
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
        metaRewardedInterstitialAd?.destroy()
        metaRewardedInterstitialAd = null
        metaInterstitialAd?.destroy()
        metaInterstitialAd = null
        metaBannerAdView?.destroy()
        metaBannerAdView = null
        startioRewardedAd = null
        startioInterstitialAd = null
        super.onDestroy()
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

    private fun initializeStartioIfNeeded() {
        preloadStartioRewardedVideo()
        preloadStartioInterstitial()
    }

    private fun preloadMetaRewardedInterstitial() {
        val placementId = BuildConfig.META_REWARDED_INTERSTITIAL_PLACEMENT_ID
        if (placementId.isBlank()) {
            Log.w(LOG_TAG, "Meta rewarded interstitial placement ID is missing.")
            return
        }

        Log.d(LOG_TAG, "[rewarded][meta] requesting rewarded interstitial for placement $placementId")
        metaRewardedInterstitialAd?.destroy()
        metaRewardedInterstitialAd = RewardedInterstitialAd(this, placementId).apply {
            loadAd(
                buildLoadAdConfig()
                    .withAdListener(object : RewardedInterstitialAdListener {
                        override fun onError(ad: Ad?, adError: AdError) {
                            emitEvent(
                                "onMetaRewardedInterstitialError",
                                mapOf("error" to adError.errorMessage),
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

    private fun preloadStartioRewardedVideo() {
        startioRewardedLoaded = false
        startioRewardedAd = StartAppAd(this).apply {
            setVideoListener(object : VideoListener {
                override fun onVideoCompleted() {
                    emitEvent("onStartioRewardedVideoCompleted")
                    Log.d(LOG_TAG, "[rewarded][startio] completed.")
                }
            })
            loadAd(
                AdMode.REWARDED_VIDEO,
                object : AdEventListener {
                    override fun onReceiveAd(ad: StartioAd) {
                        startioRewardedLoaded = true
                        emitEvent("onStartioRewardedVideoLoaded")
                        Log.d(LOG_TAG, "[rewarded][startio] loaded.")
                    }

                    override fun onFailedToReceiveAd(ad: StartioAd?) {
                        startioRewardedLoaded = false
                        emitEvent("onStartioRewardedVideoError")
                        Log.w(LOG_TAG, "[rewarded][startio] failed to load.")
                    }
                },
            )
        }
    }

    private fun preloadStartioInterstitial() {
        startioInterstitialLoaded = false
        startioInterstitialAd = StartAppAd(this).apply {
            loadAd(object : AdEventListener {
                override fun onReceiveAd(ad: StartioAd) {
                    startioInterstitialLoaded = true
                    Log.d(LOG_TAG, "[interstitial][startio] loaded.")
                }

                override fun onFailedToReceiveAd(ad: StartioAd?) {
                    startioInterstitialLoaded = false
                    Log.w(LOG_TAG, "[interstitial][startio] failed to load.")
                }
            })
        }
    }

    private fun createStartioRewardedDisplayListener(): AdDisplayListener {
        return object : AdDisplayListener {
            override fun adHidden(ad: StartioAd) {
                emitEvent("onStartioRewardedVideoClosed")
                Log.d(LOG_TAG, "[rewarded][startio] closed.")
                preloadStartioRewardedVideo()
            }

            override fun adDisplayed(ad: StartioAd) {
                emitEvent("onStartioRewardedVideoShown")
                Log.d(LOG_TAG, "[rewarded][startio] shown.")
            }

            override fun adClicked(ad: StartioAd) = Unit

            override fun adNotDisplayed(ad: StartioAd) {
                emitEvent("onStartioRewardedVideoError")
                Log.w(LOG_TAG, "[rewarded][startio] failed to show.")
                preloadStartioRewardedVideo()
            }
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

    private fun emitEvent(method: String, arguments: Map<String, Any?> = emptyMap()) {
        rewardedVideoChannel?.invokeMethod(method, arguments)
    }

    companion object {
        private const val REWARDED_VIDEO_CHANNEL = "com.videomoney.app/rewarded_video"
        private const val REWARDED_VIDEO_TYPE = Appodeal.REWARDED_VIDEO
        private const val APP_KEY_PLACEHOLDER = "APPODEAL_APP_KEY"
        private const val LOG_TAG = "VideoMoneyAppodeal"
    }
}
