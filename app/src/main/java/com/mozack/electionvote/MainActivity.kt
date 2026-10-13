package com.mozack.electionvote

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.ProgressBar
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject

/**
 * Hosts the student website and exposes ONE capability to it: scanning for polling-node beacons.
 * The bridge is an androidx.webkit WebMessageListener restricted to the student site's origin, so no other
 * page (and no injected frame from another origin) can reach it. The app never sees credentials or ballots.
 */
class MainActivity : AppCompatActivity() {
    private lateinit var web: WebView
    private lateinit var offline: View
    private lateinit var progress: ProgressBar
    private lateinit var scanner: BleScanner
    private val home = Uri.parse(BuildConfig.STUDENT_URL)
    private var pending: Pair<String, Long>? = null          // (request id, timeout) waiting on a permission prompt
    private var reply: JavaScriptReplyProxy? = null
    @Volatile private var ready = false                        // true once the first page load finished or failed

    private val permission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val p = pending; pending = null
        if (p == null) return@registerForActivityResult
        if (granted) runScan(p.first, p.second) else sendError(p.first, "PERMISSION_DENIED", "Bluetooth permission is required to verify you are at the polling location.")
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        // Keep the logo fixed on screen until the website has finished loading (or failed, or 12 s have passed).
        val splash = installSplashScreen()
        splash.setKeepOnScreenCondition { !ready }
        super.onCreate(savedInstanceState)
        window.decorView.postDelayed({ ready = true }, 12_000)
        setContentView(R.layout.activity_main)
        web = findViewById(R.id.web); offline = findViewById(R.id.offline); progress = findViewById(R.id.progress)
        scanner = BleScanner(this)
        findViewById<Button>(R.id.retry).setOnClickListener { offline.visibility = View.GONE; web.reload() }

        web.settings.apply {
            javaScriptEnabled = true; domStorageEnabled = true
            allowFileAccess = false; allowContentAccess = false
            @Suppress("DEPRECATION") run { allowFileAccessFromFileURLs = false; allowUniversalAccessFromFileURLs = false }
            mediaPlaybackRequiresUserGesture = true
            userAgentString = "$userAgentString ElectionApp/${BuildConfig.VERSION_NAME}"
        }
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)

        web.webViewClient = object : WebViewClient() {
            // Keep navigation inside the student site; send everything else to the system browser.
            override fun shouldOverrideUrlLoading(view: WebView, req: WebResourceRequest): Boolean {
                val u = req.url
                if (u.scheme == home.scheme && u.host == home.host && u.port == home.port) return false
                if (u.scheme == "https") runCatching { startActivity(Intent(Intent.ACTION_VIEW, u)) }   // never launch other schemes (intent:, file:, etc.)
                return true
            }
            override fun onPageStarted(v: WebView, url: String, favicon: Bitmap?) { progress.visibility = View.VISIBLE }
            override fun onPageFinished(v: WebView, url: String) { progress.visibility = View.GONE; ready = true }
            override fun onReceivedError(v: WebView, r: WebResourceRequest, e: WebResourceError) { if (r.isForMainFrame) { offline.visibility = View.VISIBLE; ready = true } }
        }
        web.webChromeClient = object : android.webkit.WebChromeClient() { override fun onProgressChanged(v: WebView, p: Int) { progress.progress = p } }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            val origin = "${home.scheme}://${home.authority}"
            WebViewCompat.addWebMessageListener(web, "ElectionNative", setOf(origin)) { _, message, sourceOrigin, isMainFrame, replyProxy ->
                // Only the top-level student page may use the bridge.
                if (!isMainFrame || sourceOrigin.toString() != origin) return@addWebMessageListener
                reply = replyProxy
                handle(message)
            }
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() { if (web.canGoBack()) web.goBack() else finish() }
        })
        if (savedInstanceState != null) web.restoreState(savedInstanceState) else web.loadUrl(BuildConfig.STUDENT_URL)
    }

    override fun onSaveInstanceState(out: Bundle) { super.onSaveInstanceState(out); web.saveState(out) }
    override fun onStop() { scanner.stop(); super.onStop() }
    override fun onDestroy() { scanner.stop(); web.destroy(); super.onDestroy() }

    private fun handle(m: WebMessageCompat) {
        val json = runCatching { JSONObject(m.data ?: return) }.getOrNull() ?: return
        when (json.optString("type")) {
            "scan" -> {
                val id = json.optString("id").takeIf { it.length in 8..64 } ?: return
                val timeout = json.optLong("timeoutMs", 15000).coerceIn(3000, 30000)
                val perm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Manifest.permission.BLUETOOTH_SCAN else Manifest.permission.ACCESS_FINE_LOCATION
                if (ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED) runScan(id, timeout)
                else { pending = id to timeout; permission.launch(perm) }
            }
            "openSettings" -> startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        }
    }

    private fun runScan(id: String, timeoutMs: Long) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            val lm = getSystemService(LOCATION_SERVICE) as android.location.LocationManager
            if (!androidx.core.location.LocationManagerCompat.isLocationEnabled(lm)) return sendError(id, "BLUETOOTH_OFF", "On this Android version, Bluetooth scanning needs Location turned on. Turn on Location and try again.")
        }
        scanner.scan(timeoutMs) { out ->
            when (out) {
                is BleScanner.Outcome.Found -> post("""{"type":"scanResult","id":${JSONObject.quote(id)},"claims":[${out.claims.joinToString(",") { it.first.toJson() }}]}""")
                is BleScanner.Outcome.Failed -> sendError(id, out.code, out.message)
            }
        }
    }

    private fun sendError(id: String, code: String, message: String) =
        post("""{"type":"error","id":${JSONObject.quote(id)},"code":${JSONObject.quote(code)},"message":${JSONObject.quote(message)}}""")

    private fun post(json: String) = runOnUiThread { reply?.postMessage(json) }
}
