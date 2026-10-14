package com.mozack.electionvote

import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * One-shot scan for polling-node beacons. Returns up to [MAX_CLAIMS] distinct beacons, strongest signal first, so a
 * rogue advertiser cannot hide the real node: the server decides which one is authorised.
 */
class BleScanner(context: Context) {
    sealed class Outcome {
        data class Found(val claims: List<Pair<BeaconClaim, Int>>) : Outcome()
        data class Failed(val code: String, val message: String) : Outcome()
    }

    private val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    private val main = Handler(Looper.getMainLooper())
    private var callback: ScanCallback? = null
    private var timeout: Runnable? = null
    private var settle: Runnable? = null
    private var generation = 0   // bumps on every scan()/stop(); stale callbacks from an earlier scan are ignored

    @SuppressLint("MissingPermission") // permissions are checked by MainActivity before scan() is called
    fun scan(timeoutMs: Long, onDone: (Outcome) -> Unit) {
        stop()
        val scanner = adapter?.takeIf { it.isEnabled }?.bluetoothLeScanner
            ?: return onDone(Outcome.Failed("BLUETOOTH_OFF", "Turn on Bluetooth and try again."))

        val gen = generation
        val seen = LinkedHashMap<Long, Pair<BeaconClaim, Int>>()   // beaconId -> (freshest claim, best rssi)
        var finished = false
        fun finish() {
            if (finished || gen != generation) return
            finished = true
            stop()
            val list = seen.values.sortedByDescending { it.second }.take(MAX_CLAIMS)
            onDone(if (list.isEmpty()) Outcome.Failed("TIMEOUT", "No polling device found. Move closer to the polling device and try again.") else Outcome.Found(list))
        }

        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (gen != generation || finished) return
                val claim = BeaconParser.parse(result.scanRecord?.getManufacturerSpecificData(BeaconParser.COMPANY_ID)) ?: return
                val prev = seen[claim.beaconId]
                seen[claim.beaconId] = when {
                    prev == null -> claim to result.rssi
                    claim.counter >= prev.first.counter -> claim to maxOf(prev.second, result.rssi)   // keep the freshest beacon
                    else -> prev.first to maxOf(prev.second, result.rssi)
                }
                if (settle == null) settle = Runnable { finish() }.also { main.postDelayed(it, SETTLE_MS) }  // brief wait for other nodes in range
            }
            override fun onScanFailed(errorCode: Int) {
                if (gen != generation || finished) return
                finished = true; stop()
                onDone(Outcome.Failed("SCAN_FAILED", "Bluetooth scan failed (code $errorCode). Try again."))
            }
        }
        callback = cb
        val filter = ScanFilter.Builder().setManufacturerData(BeaconParser.COMPANY_ID, byteArrayOf(1), byteArrayOf(0xFF.toByte())).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        try { scanner.startScan(listOf(filter), settings, cb) }
        catch (e: SecurityException) { return onDone(Outcome.Failed("PERMISSION_DENIED", "Bluetooth permission is required to verify your location.")) }
        timeout = Runnable { finish() }.also { main.postDelayed(it, timeoutMs) }
    }

    private var probeCb: ScanCallback? = null
    private var probeTimeout: Runnable? = null

    /**
     * Short background look for ANY polling-node beacon, used only for the status badge. It does not relay anything to the
     * server: the badge means "a node signal is in range", and real verification still happens server-side when voting.
     */
    @SuppressLint("MissingPermission")
    fun probe(timeoutMs: Long, onDone: (found: Boolean) -> Unit) {
        probeStop()
        val scanner = adapter?.takeIf { it.isEnabled }?.bluetoothLeScanner ?: return onDone(false)
        var finished = false
        fun finish(found: Boolean) { if (finished) return; finished = true; probeStop(); onDone(found) }
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (BeaconParser.parse(result.scanRecord?.getManufacturerSpecificData(BeaconParser.COMPANY_ID)) != null) finish(true)
            }
            override fun onScanFailed(errorCode: Int) { finish(false) }
        }
        probeCb = cb
        val filter = ScanFilter.Builder().setManufacturerData(BeaconParser.COMPANY_ID, byteArrayOf(1), byteArrayOf(0xFF.toByte())).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
        try { scanner.startScan(listOf(filter), settings, cb) } catch (e: Exception) { probeCb = null; return onDone(false) }
        probeTimeout = Runnable { finish(false) }.also { main.postDelayed(it, timeoutMs) }
    }

    @SuppressLint("MissingPermission")
    fun probeStop() {
        probeTimeout?.let(main::removeCallbacks); probeTimeout = null
        probeCb?.let { try { adapter?.bluetoothLeScanner?.stopScan(it) } catch (_: Exception) {} }
        probeCb = null
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        generation++
        timeout?.let(main::removeCallbacks); timeout = null
        settle?.let(main::removeCallbacks); settle = null
        callback?.let { try { adapter?.bluetoothLeScanner?.stopScan(it) } catch (_: Exception) {} }
        callback = null
    }

    private companion object { const val SETTLE_MS = 1200L; const val MAX_CLAIMS = 3 }
}
