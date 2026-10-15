package com.mozack.electionvote

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * Checks the server for election changes while the app is closed and raises a phone notification for anything new.
 * Uses a limited, server-issued token that can only read the notification feed (it cannot vote or read ballots).
 * Android runs periodic background work at most every ~15 minutes; the first check after login only records the
 * current state so the student is not flooded with notifications for things they already saw.
 */
class NotifyWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val store = NotifyStore(applicationContext)
        val token = store.token ?: return Result.success()
        val base = store.apiBase ?: return Result.success()
        return try {
            val conn = (URL("$base/student/notify-feed").openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000; readTimeout = 15_000; setRequestProperty("Authorization", "Bearer $token")
            }
            when (conn.responseCode) {
                200 -> { process(store, conn.inputStream.bufferedReader().use { it.readText() }); Result.success() }
                401, 403 -> { store.clear(); Result.success() }        // session revoked or expired: stop quietly
                else -> Result.retry()
            }
        } catch (e: Exception) { Result.retry() }
    }

    private fun process(store: NotifyStore, body: String) {
        val items: JSONArray = JSONObject(body).optJSONArray("items") ?: return
        val seen = store.seen()
        val first = !store.seeded
        for (i in 0 until items.length()) {
            val it = items.getJSONObject(i)
            val id = it.getString("electionId"); val key = it.getString("key"); val state = it.getString("state")
            val title = it.optString("title"); val old = seen.optString(id, "")
            if (!first && old != key) {
                val sameState = old.substringBefore('|') == state
                val head = when {
                    sameState -> "Election schedule updated"
                    state == "SCHEDULED" -> "New election announced"
                    state == "ACTIVE" -> "Voting is open"
                    state == "PAUSED" -> "Voting paused"
                    state == "DEACTIVATED" -> "Election withdrawn"
                    state == "ENDED" -> "Voting has ended"
                    state == "PUBLISHED" -> "Results published"
                    else -> it.optString("headline")
                }
                Notifier.show(applicationContext, id.hashCode(), "$head: $title", it.optString("body"))
            }
            seen.put(id, key)
        }
        store.save(seen)
    }

    companion object {
        private const val NAME = "election-notify"
        fun start(ctx: Context) {
            val net = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val wm = WorkManager.getInstance(ctx)
            wm.enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.UPDATE, PeriodicWorkRequestBuilder<NotifyWorker>(15, TimeUnit.MINUTES).setConstraints(net).build())
            wm.enqueue(OneTimeWorkRequestBuilder<NotifyWorker>().setConstraints(net).build())      // record current state right away
        }
        fun stop(ctx: Context) { WorkManager.getInstance(ctx).cancelUniqueWork(NAME); NotifyStore(ctx).clear() }
    }
}

/** App-private storage (not readable by other apps; backups are disabled in the manifest). */
class NotifyStore(ctx: Context) {
    private val p = ctx.getSharedPreferences("notify", Context.MODE_PRIVATE)
    val token get() = p.getString("token", null)
    val apiBase get() = p.getString("base", null)
    val seeded get() = p.getBoolean("seeded", false)
    fun set(token: String, base: String) { p.edit().putString("token", token).putString("base", base).apply() }
    fun seen(): JSONObject = runCatching { JSONObject(p.getString("seen", "{}")!!) }.getOrDefault(JSONObject())
    fun save(m: JSONObject) { p.edit().putString("seen", m.toString()).putBoolean("seeded", true).apply() }
    fun clear() { p.edit().clear().apply() }
}
