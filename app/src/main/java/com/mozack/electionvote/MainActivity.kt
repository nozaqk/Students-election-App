package com.mozack.electionvote

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
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
    private val connectivity by lazy { getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager }
    private val netCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onLost(network: Network) { runOnUiThread { if (!isOnline()) showOffline() } }
        override fun onAvailable(network: Network) { runOnUiThread { if (offline.visibility == View.VISIBLE && isOnline()) goOnline() } }
    }
    private val btAdapter: BluetoothAdapter? by lazy { (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter }
    private val btReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) { if (i.action == BluetoothAdapter.ACTION_STATE_CHANGED) pushBluetoothState() }
    }
    // System dialog "Allow Student Election to turn on Bluetooth?" (apps cannot switch Bluetooth on silently on modern Android).
    private val enableBluetooth = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { pushBluetoothState() }
    private val connectPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> if (granted) askToEnableBluetooth() else pushBluetoothState() }
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
        findViewById<Button>(R.id.retry).setOnClickListener { if (isOnline()) goOnline() }

        web.overScrollMode = View.OVER_SCROLL_NEVER                      // no stretch/bounce when dragging past the top or bottom
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
        if (savedInstanceState == null) ensureBluetooth()                // ask to turn Bluetooth on each time the app is opened
        if (!isOnline()) showOffline()                                   // no internet: do not open the app at all
        else if (savedInstanceState != null && web.restoreState(savedInstanceState) != null) { /* restored */ }
        else web.loadUrl(BuildConfig.STUDENT_URL)
    }

    override fun onSaveInstanceState(out: Bundle) { super.onSaveInstanceState(out); web.saveState(out) }
    override fun onStart() {
        super.onStart()
        runCatching { connectivity.registerDefaultNetworkCallback(netCallback) }; if (!isOnline()) showOffline()
        runCatching { registerReceiver(btReceiver, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)) }
        pushBluetoothState()
    }
    override fun onStop() { scanner.stop(); runCatching { connectivity.unregisterNetworkCallback(netCallback) }; runCatching { unregisterReceiver(btReceiver) }; super.onStop() }

    private fun isBluetoothOn() = btAdapter?.isEnabled == true
    /** Tell the website whether Bluetooth is on, so it can show the BT badge (green = on, red = off). */
    private fun pushBluetoothState() = post("""{"type":"bluetooth","supported":${btAdapter != null},"on":${isBluetoothOn()}}""")

    /** On app open: if Bluetooth is off, show the system prompt to turn it on. Android 12+ needs the "nearby devices" permission for it. */
    private fun ensureBluetooth() {
        if (btAdapter == null || isBluetoothOn()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) connectPermission.launch(Manifest.permission.BLUETOOTH_CONNECT)
        else askToEnableBluetooth()
    }
    private fun askToEnableBluetooth() { runCatching { enableBluetooth.launch(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)) } }

    /** True only when the phone has an internet connection that has been validated. */
    private fun isOnline(): Boolean {
        val caps = connectivity.getNetworkCapabilities(connectivity.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) && caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
    private fun showOffline() { offline.visibility = View.VISIBLE; ready = true }
    private fun goOnline() {
        offline.visibility = View.GONE
        if (web.url == null) web.loadUrl(BuildConfig.STUDENT_URL) else web.reload()
    }
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
            "btStatus" -> pushBluetoothState()
            "btEnable" -> ensureBluetooth()
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
