package com.videomoney.app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.appnext.ads.fullscreen.RewardedVideo
import com.appnext.core.callbacks.OnAdClosed
import com.appnext.core.callbacks.OnAdError
import com.appnext.core.callbacks.OnAdOpened
import com.appnext.core.callbacks.OnVideoEnded
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
import com.unity3d.mediation.LevelPlay
import com.unity3d.mediation.LevelPlayAdError
import com.unity3d.mediation.LevelPlayAdInfo
import com.unity3d.mediation.LevelPlayConfiguration
import com.unity3d.mediation.LevelPlayInitError
import com.unity3d.mediation.LevelPlayInitListener
import com.unity3d.mediation.LevelPlayInitRequest
import com.unity3d.mediation.LevelPlayReward
import com.unity3d.mediation.LevelPlayRewardedAd
import com.unity3d.mediation.LevelPlayRewardedAdListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var rewardedVideoChannel: MethodChannel? = null
    private var appnextRewardedVideo: RewardedVideo? = null
    private var metaRewardedInterstitialAd: RewardedInterstitialAd? = null
    private var metaInterstitialAd: InterstitialAd? = null
    private var metaBannerAdView: AdView? = null
    private var mobFoxRewardedLoaded = false
    private var levelPlayRewardedAd: LevelPlayRewardedAd? = null
    private var levelPlayRewardedLoaded = false
    private var levelPlayRewardedLoading = false
    private var levelPlayInitializing = false
    private var levelPlayInitialized = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        GraviteAatkitManager.setEventListener(::emitEvent)
        initializeLevelPlayIfNeeded()
        initializeAppnextIfNeeded()
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

                    "ensureUnityInitialized" -> {
                        initializeLevelPlayIfNeeded()
                        result.success(levelPlayInitialized)
                    }

                    "isUnityRewardedVideoLoaded" -> {
                        result.success(levelPlayRewardedLoaded || levelPlayRewardedAd?.isAdReady == true)
                    }

                    "preloadUnityRewardedVideo" -> {
                        preloadLevelPlayRewardedVideo()
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

                    "showUnityRewardedVideo" -> {
                        result.success(showLevelPlayRewardedVideo())
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
        metaRewardedInterstitialAd?.destroy()
        metaRewardedInterstitialAd = null
        metaInterstitialAd?.destroy()
        metaInterstitialAd = null
        metaBannerAdView?.destroy()
        metaBannerAdView = null
        levelPlayRewardedAd = null
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

    private fun initializeLevelPlayIfNeeded() {
        if (levelPlayInitialized || levelPlayInitializing) {
            if (levelPlayInitialized) {
                createLevelPlayRewardedIfNeeded()
            }
            return
        }

        val appKey = BuildConfig.LEVELPLAY_APP_KEY
        val adUnitId = BuildConfig.LEVELPLAY_REWARDED_AD_UNIT_ID
        if (appKey.isBlank() || adUnitId.isBlank()) {
            Log.w(LOG_TAG, "LevelPlay app key or rewarded ad unit ID is missing.")
            return
        }

        levelPlayInitializing = true
        val initRequest = LevelPlayInitRequest.Builder(appKey).build()
        LevelPlay.init(
            this,
            initRequest,
            object : LevelPlayInitListener {
                override fun onInitSuccess(configuration: LevelPlayConfiguration) {
                    levelPlayInitializing = false
                    levelPlayInitialized = true
                    Log.d(
                        LOG_TAG,
                        "[rewarded][levelplay] init success for ad unit ${BuildConfig.LEVELPLAY_REWARDED_AD_UNIT_ID}.",
                    )
                    createLevelPlayRewardedIfNeeded()
                    preloadLevelPlayRewardedVideo()
                }

                override fun onInitFailed(error: LevelPlayInitError) {
                    levelPlayInitializing = false
                    levelPlayInitialized = false
                    levelPlayRewardedLoaded = false
                    levelPlayRewardedLoading = false
                    emitEvent(
                        "onUnityRewardedVideoFailedToLoad",
                        mapOf("error" to error.toString()),
                    )
                    Log.w(
                        LOG_TAG,
                        "[rewarded][levelplay] init failed: $error",
                    )
                }
            },
        )
    }

    private fun createLevelPlayRewardedIfNeeded() {
        if (!levelPlayInitialized || levelPlayRewardedAd != null) {
            return
        }

        val adUnitId = BuildConfig.LEVELPLAY_REWARDED_AD_UNIT_ID
        if (adUnitId.isBlank()) {
            Log.w(LOG_TAG, "LevelPlay rewarded ad unit ID is missing.")
            return
        }

        levelPlayRewardedAd = LevelPlayRewardedAd(adUnitId).apply {
            setListener(
                object : LevelPlayRewardedAdListener {
                    override fun onAdLoaded(adInfo: LevelPlayAdInfo) {
                        levelPlayRewardedLoaded = true
                        levelPlayRewardedLoading = false
                        emitEvent("onUnityRewardedVideoLoaded")
                        Log.d(LOG_TAG, "[rewarded][levelplay] loaded.")
                    }

                    override fun onAdLoadFailed(error: LevelPlayAdError) {
                        levelPlayRewardedLoaded = false
                        levelPlayRewardedLoading = false
                        emitEvent(
                            "onUnityRewardedVideoFailedToLoad",
                            mapOf("error" to error.toString()),
                        )
                        Log.w(LOG_TAG, "[rewarded][levelplay] failed to load: $error")
                    }

                    override fun onAdDisplayed(adInfo: LevelPlayAdInfo) {
                        levelPlayRewardedLoaded = false
                        levelPlayRewardedLoading = false
                        emitEvent("onUnityRewardedVideoShown")
                        Log.d(LOG_TAG, "[rewarded][levelplay] shown.")
                    }

                    override fun onAdRewarded(reward: LevelPlayReward, adInfo: LevelPlayAdInfo) {
                        emitEvent(
                            "onUnityRewardedVideoFinished",
                            mapOf(
                                "amount" to reward.amount,
                                "currency" to reward.name,
                            ),
                        )
                        Log.d(
                            LOG_TAG,
                            "[rewarded][levelplay] completed reward=${reward.amount} ${reward.name}",
                        )
                    }

                    override fun onAdDisplayFailed(
                        error: LevelPlayAdError,
                        adInfo: LevelPlayAdInfo,
                    ) {
                        levelPlayRewardedLoaded = false
                        levelPlayRewardedLoading = false
                        emitEvent(
                            "onUnityRewardedVideoShowFailed",
                            mapOf("error" to error.toString()),
                        )
                        Log.w(LOG_TAG, "[rewarded][levelplay] failed to show: $error")
                        preloadLevelPlayRewardedVideo()
                    }

                    override fun onAdClicked(adInfo: LevelPlayAdInfo) = Unit

                    override fun onAdClosed(adInfo: LevelPlayAdInfo) {
                        emitEvent("onUnityRewardedVideoClosed")
                        Log.d(LOG_TAG, "[rewarded][levelplay] closed.")
                        preloadLevelPlayRewardedVideo()
                    }

                    override fun onAdInfoChanged(adInfo: LevelPlayAdInfo) = Unit
                },
            )
        }
    }

    private fun preloadLevelPlayRewardedVideo() {
        initializeLevelPlayIfNeeded()
        if (!levelPlayInitialized) {
            return
        }
        createLevelPlayRewardedIfNeeded()
        val rewardedAd = levelPlayRewardedAd ?: return
        if (levelPlayRewardedLoaded || rewardedAd.isAdReady || levelPlayRewardedLoading) {
            levelPlayRewardedLoaded = levelPlayRewardedLoaded || rewardedAd.isAdReady
            return
        }
        levelPlayRewardedLoading = true
        Log.d(LOG_TAG, "[rewarded][levelplay] requesting load.")
        rewardedAd.loadAd()
    }

    private fun showLevelPlayRewardedVideo(): Boolean {
        initializeLevelPlayIfNeeded()
        val rewardedAd = levelPlayRewardedAd
        val canShow = levelPlayInitialized && rewardedAd?.isAdReady == true
        if (!canShow) {
            levelPlayRewardedLoaded = false
            preloadLevelPlayRewardedVideo()
            return false
        }
        levelPlayRewardedLoaded = false
        levelPlayRewardedLoading = false
        rewardedAd?.showAd(this)
        Log.d(LOG_TAG, "[rewarded][levelplay] showing rewarded video.")
        return true
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
        private const val MOBFOX_REWARDED_REQUEST_CODE = 7149
        private const val LOG_TAG = "VideoMoneyAds"
    }
}
