package com.videomoney.app

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.StringReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Document
import org.w3c.dom.Element
import org.w3c.dom.Node
import org.xml.sax.InputSource

data class MobFoxRewardedAdPayload(
    val mediaUrl: String,
    val durationMs: Long,
    val impressionUrls: List<String>,
    val trackingUrls: Map<String, List<String>>,
    val clickThroughUrl: String?,
)

object MobFoxRewardedManager {
    private const val LOG_TAG = "MobFoxRewarded"
    private const val REQUEST_TIMEOUT_MS = 7000
    private const val MAX_WRAPPER_DEPTH = 4

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var cachedAd: MobFoxRewardedAdPayload? = null

    @Volatile
    private var isLoading = false

    fun preload(context: Context, onLoaded: () -> Unit, onError: (String) -> Unit) {
        if (cachedAd != null || isLoading) return
        isLoading = true
        val appContext = context.applicationContext
        executor.execute {
            try {
                val tagUrl = buildTagUrl(appContext)
                val payload = fetchVastChain(tagUrl, 0)
                    ?: throw IllegalStateException("MobFox rewarded ad returned no fill.")
                cachedAd = payload
                mainHandler.post(onLoaded)
            } catch (error: Exception) {
                cachedAd = null
                val message = error.message ?: "MobFox rewarded ad failed to load."
                Log.w(LOG_TAG, message, error)
                mainHandler.post { onError(message) }
            } finally {
                isLoading = false
            }
        }
    }

    fun isLoaded(): Boolean = cachedAd != null

    fun consumeAd(): MobFoxRewardedAdPayload? {
        val ad = cachedAd
        cachedAd = null
        return ad
    }

    fun clear() {
        cachedAd = null
        isLoading = false
    }

    fun pingTrackingUrls(urls: List<String>) {
        if (urls.isEmpty()) return
        executor.execute {
            urls.forEach(::fireTrackingUrl)
        }
    }

    private fun buildTagUrl(context: Context): String {
        val metrics = context.resources.displayMetrics
        val packageManager = context.packageManager
        val packageName = context.packageName
        val appLabel = runCatching {
            packageManager.getApplicationLabel(context.applicationInfo).toString()
        }.getOrDefault("VideoMoney")
        val versionName = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                ).versionName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0).versionName
            }
        }.getOrDefault("1.0.0") ?: "1.0.0"

        val replacements = mapOf(
            "[VIDEO_TYPE]" to "rewarded",
            "[IP]" to "",
            "[UA]" to (System.getProperty("http.agent") ?: "Android"),
            "[APP_NAME]" to appLabel,
            "[APP_BUNDLE]" to packageName,
            "[APP_VERSION]" to versionName,
            "[DEVICE_OS]" to "Android",
            "[DEVICE_OS_VERSION]" to (Build.VERSION.RELEASE ?: ""),
            "[DEVICE_MAKE]" to Build.MANUFACTURER,
            "[DEVICE_MODEL]" to Build.MODEL,
            "[DEVICE_W]" to metrics.widthPixels.toString(),
            "[DEVICE_H]" to metrics.heightPixels.toString(),
            "[PLAYER_W]" to metrics.widthPixels.toString(),
            "[PLAYER_H]" to metrics.heightPixels.toString(),
            "[DEVICE_HW_VERSION]" to Build.HARDWARE,
            "[IFA]" to "",
            "[JS]" to "0",
            "[CARRIER]" to "",
            "[PAID]" to "0",
            "[GEO_COUNTRY]" to "",
            "[GEO_TYPE]" to "",
            "[GEO_CITY]" to "",
            "[GEO_LAT]" to "",
            "[GEO_LON]" to "",
            "[BIDFLOOR]" to "0",
            "[GDPR_CONSENT]" to "",
            "[COPPA]" to "0",
            "[GPP]" to "",
            "[GPP_SID]" to "",
        )

        var tagUrl = BuildConfig.MOBFOX_VAST_TAG_URL
        replacements.forEach { (placeholder, value) ->
            tagUrl = tagUrl.replace(
                placeholder,
                URLEncoder.encode(value, Charsets.UTF_8.name()),
            )
        }
        return tagUrl
    }

    private fun fetchVastChain(url: String, depth: Int): MobFoxRewardedAdPayload? {
        if (depth > MAX_WRAPPER_DEPTH) {
            throw IllegalStateException("MobFox VAST wrapper depth exceeded.")
        }
        val xml = fetchText(url)
        val document = parseXml(xml)
        val wrapperUrl = firstTagText(document, "VASTAdTagURI")
        val impressionUrls = tagTexts(document, "Impression")
        val trackingUrls = extractTrackingUrls(document)
        val clickThroughUrl = firstTagText(document, "ClickThrough")

        if (!wrapperUrl.isNullOrBlank()) {
            val wrappedAd = fetchVastChain(wrapperUrl.trim(), depth + 1)
                ?: return null
            return wrappedAd.copy(
                impressionUrls = impressionUrls + wrappedAd.impressionUrls,
                trackingUrls = mergeTracking(trackingUrls, wrappedAd.trackingUrls),
                clickThroughUrl = wrappedAd.clickThroughUrl ?: clickThroughUrl,
            )
        }

        val mediaUrl = extractMediaUrl(document) ?: return null
        val durationMs = parseDurationToMs(firstTagText(document, "Duration")) ?: 30_000L
        return MobFoxRewardedAdPayload(
            mediaUrl = mediaUrl,
            durationMs = durationMs,
            impressionUrls = impressionUrls,
            trackingUrls = trackingUrls,
            clickThroughUrl = clickThroughUrl,
        )
    }

    private fun fetchText(url: String): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            instanceFollowRedirects = true
            connectTimeout = REQUEST_TIMEOUT_MS
            readTimeout = REQUEST_TIMEOUT_MS
            setRequestProperty("User-Agent", System.getProperty("http.agent") ?: "Android")
        }
        return try {
            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream ?: throw IllegalStateException("MobFox HTTP $statusCode")
            }
            BufferedReader(InputStreamReader(stream)).use { reader ->
                reader.readText()
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun parseXml(xml: String): Document {
        val factory = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = false
            setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
            setFeature("http://xml.org/sax/features/external-general-entities", false)
            setFeature("http://xml.org/sax/features/external-parameter-entities", false)
        }
        val builder = factory.newDocumentBuilder()
        return StringReader(xml).use { reader ->
            builder.parse(InputSource(reader))
        }
    }

    private fun firstTagText(document: Document, tagName: String): String? {
        val nodes = document.getElementsByTagName(tagName)
        for (index in 0 until nodes.length) {
            val value = nodes.item(index)?.textContent?.trim()
            if (!value.isNullOrBlank()) {
                return value
            }
        }
        return null
    }

    private fun tagTexts(document: Document, tagName: String): List<String> {
        val nodes = document.getElementsByTagName(tagName)
        val values = mutableListOf<String>()
        for (index in 0 until nodes.length) {
            val value = nodes.item(index)?.textContent?.trim()
            if (!value.isNullOrBlank()) {
                values += value
            }
        }
        return values
    }

    private fun extractTrackingUrls(document: Document): Map<String, List<String>> {
        val trackingMap = mutableMapOf<String, MutableList<String>>()
        val nodes = document.getElementsByTagName("Tracking")
        for (index in 0 until nodes.length) {
            val node = nodes.item(index) as? Element ?: continue
            val event = node.getAttribute("event")?.trim().orEmpty()
            val url = node.textContent?.trim().orEmpty()
            if (event.isBlank() || url.isBlank()) continue
            trackingMap.getOrPut(event) { mutableListOf() }.add(url)
        }
        return trackingMap
    }

    private fun mergeTracking(
        first: Map<String, List<String>>,
        second: Map<String, List<String>>,
    ): Map<String, List<String>> {
        val merged = mutableMapOf<String, MutableList<String>>()
        first.forEach { (event, urls) ->
            merged.getOrPut(event) { mutableListOf() }.addAll(urls)
        }
        second.forEach { (event, urls) ->
            merged.getOrPut(event) { mutableListOf() }.addAll(urls)
        }
        return merged
    }

    private fun extractMediaUrl(document: Document): String? {
        val nodes = document.getElementsByTagName("MediaFile")
        var fallback: String? = null
        for (index in 0 until nodes.length) {
            val node = nodes.item(index) as? Element ?: continue
            val value = node.textContent?.trim().orEmpty()
            if (value.isBlank()) continue
            val type = node.getAttribute("type")?.lowercase().orEmpty()
            if (type.contains("mp4")) {
                return value
            }
            if (fallback == null) {
                fallback = value
            }
        }
        return fallback
    }

    private fun parseDurationToMs(rawDuration: String?): Long? {
        val parts = rawDuration
            ?.trim()
            ?.split(':')
            ?.mapNotNull { it.toLongOrNull() }
            ?: return null
        if (parts.size != 3) return null
        val (hours, minutes, seconds) = parts
        return ((hours * 3600) + (minutes * 60) + seconds) * 1000L
    }

    private fun fireTrackingUrl(url: String) {
        if (url.isBlank()) return
        runCatching {
            val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = REQUEST_TIMEOUT_MS
                readTimeout = REQUEST_TIMEOUT_MS
                instanceFollowRedirects = true
                setRequestProperty("User-Agent", System.getProperty("http.agent") ?: "Android")
            }
            connection.inputStream.use { it.readBytes() }
            connection.disconnect()
        }.onFailure { error ->
            Log.w(LOG_TAG, "MobFox tracking ping failed for $url", error)
        }
    }
}
