package com.videomoney.app

import android.os.Bundle
import android.util.Log
import com.appnext.ads.fullscreen.RewardedVideo
import com.appnext.core.Appnext
import com.appnext.core.callbacks.OnAdClosed
import com.appnext.core.callbacks.OnAdError
import com.appnext.core.callbacks.OnAdOpened
import com.appnext.core.callbacks.OnVideoEnded
import com.appodeal.ads.Appodeal
import com.appodeal.ads.RewardedVideoCallbacks
import com.appodeal.ads.initializing.ApdInitializationCallback
import com.appodeal.ads.initializing.ApdInitializationError
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var rewardedVideoChannel: MethodChannel? = null
    private var appnextRewardedVideo: RewardedVideo? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureRewardedVideoCallbacks()
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
        super.onDestroy()
    }

    private fun configureRewardedVideoCallbacks() {
        Appodeal.setRewardedVideoCallbacks(object : RewardedVideoCallbacks {
            override fun onRewardedVideoLoaded(isPrecache: Boolean) {
                emitEvent("onRewardedVideoLoaded", mapOf("isPrecache" to isPrecache))
            }

            override fun onRewardedVideoFailedToLoad() {
                emitEvent("onRewardedVideoFailedToLoad")
            }

            override fun onRewardedVideoShown() {
                emitEvent("onRewardedVideoShown")
            }

            override fun onRewardedVideoShowFailed() {
                emitEvent("onRewardedVideoShowFailed")
                cacheRewardedVideo()
            }

            override fun onRewardedVideoClicked() = Unit

            override fun onRewardedVideoFinished(amount: Double, currency: String) {
                emitEvent(
                    "onRewardedVideoFinished",
                    mapOf(
                        "amount" to amount,
                        "currency" to currency,
                    ),
                )
            }

            override fun onRewardedVideoClosed(finished: Boolean) {
                emitEvent("onRewardedVideoClosed", mapOf("finished" to finished))
                cacheRewardedVideo()
            }

            override fun onRewardedVideoExpired() {
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

    private fun initializeAppnextIfNeeded() {
        Appnext.init(this)
        Log.d(LOG_TAG, "Appnext SDK initialized for app ID ${BuildConfig.APPNEXT_APP_ID}")
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
            rewardedVideo.loadAd()
        }
    }

    private fun cacheRewardedVideo() {
        if (Appodeal.isInitialized(REWARDED_VIDEO_TYPE) &&
            !Appodeal.isLoaded(REWARDED_VIDEO_TYPE)
        ) {
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
