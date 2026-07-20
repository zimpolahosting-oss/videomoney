package com.videomoney.app

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageButton
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

class MobFoxRewardedActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())

    private var player: ExoPlayer? = null
    private var adPayload: MobFoxRewardedAdPayload? = null
    private var hasStarted = false
    private var firstQuartileSent = false
    private var midpointSent = false
    private var thirdQuartileSent = false
    private var finished = false

    private val progressTracker = object : Runnable {
        override fun run() {
            val localPlayer = player ?: return
            val payload = adPayload ?: return
            val duration = if (localPlayer.duration > 0) {
                localPlayer.duration
            } else {
                payload.durationMs
            }
            val currentPosition = localPlayer.currentPosition.coerceAtLeast(0L)
            if (duration > 0) {
                val progress = currentPosition.toDouble() / duration.toDouble()
                if (!firstQuartileSent && progress >= 0.25) {
                    firstQuartileSent = true
                    MobFoxRewardedManager.pingTrackingUrls(
                        payload.trackingUrls["firstQuartile"].orEmpty(),
                    )
                }
                if (!midpointSent && progress >= 0.50) {
                    midpointSent = true
                    MobFoxRewardedManager.pingTrackingUrls(
                        payload.trackingUrls["midpoint"].orEmpty(),
                    )
                }
                if (!thirdQuartileSent && progress >= 0.75) {
                    thirdQuartileSent = true
                    MobFoxRewardedManager.pingTrackingUrls(
                        payload.trackingUrls["thirdQuartile"].orEmpty(),
                    )
                }
            }
            if (!finished) {
                handler.postDelayed(this, 250)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        adPayload = MobFoxRewardedManager.consumeAd()
        val payload = adPayload
        if (payload == null) {
            finishWithResult(rewarded = false, error = "MobFox ad was not ready to show.")
            return
        }

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
        }
        val playerView = PlayerView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            useController = false
            setShutterBackgroundColor(Color.BLACK)
        }
        val closeButton = ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setBackgroundColor(Color.parseColor("#66000000"))
            setColorFilter(Color.WHITE)
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.END,
            ).apply {
                topMargin = 32
                marginEnd = 24
            }
            setOnClickListener {
                finishWithResult(rewarded = false)
            }
        }
        root.addView(playerView)
        root.addView(closeButton)
        setContentView(root)

        val exoPlayer = ExoPlayer.Builder(this).build().also { localPlayer ->
            playerView.player = localPlayer
            localPlayer.setMediaItem(MediaItem.fromUri(payload.mediaUrl))
            localPlayer.repeatMode = Player.REPEAT_MODE_OFF
            localPlayer.playWhenReady = true
            localPlayer.addListener(
                object : Player.Listener {
                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        if (isPlaying && !hasStarted) {
                            hasStarted = true
                            MobFoxRewardedManager.pingTrackingUrls(payload.impressionUrls)
                            MobFoxRewardedManager.pingTrackingUrls(
                                payload.trackingUrls["start"].orEmpty(),
                            )
                            handler.post(progressTracker)
                        }
                    }

                    override fun onPlaybackStateChanged(playbackState: Int) {
                        if (playbackState == Player.STATE_ENDED) {
                            MobFoxRewardedManager.pingTrackingUrls(
                                payload.trackingUrls["complete"].orEmpty(),
                            )
                            finishWithResult(rewarded = true)
                        }
                    }

                    override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                        MobFoxRewardedManager.pingTrackingUrls(
                            payload.trackingUrls["error"].orEmpty(),
                        )
                        finishWithResult(
                            rewarded = false,
                            error = "MobFox playback failed: ${error.message ?: "unknown"}",
                        )
                    }
                },
            )
            localPlayer.prepare()
        }
        player = exoPlayer
    }

    override fun onBackPressed() {
        finishWithResult(rewarded = false)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        player?.release()
        player = null
        super.onDestroy()
    }

    private fun finishWithResult(rewarded: Boolean, error: String? = null) {
        if (finished) return
        finished = true
        handler.removeCallbacksAndMessages(null)
        setResult(
            RESULT_OK,
            Intent().apply {
                putExtra(EXTRA_REWARDED, rewarded)
                if (!error.isNullOrBlank()) {
                    putExtra(EXTRA_ERROR, error)
                }
            },
        )
        finish()
    }

    companion object {
        const val EXTRA_REWARDED = "mobfox_rewarded"
        const val EXTRA_ERROR = "mobfox_error"
    }
}
