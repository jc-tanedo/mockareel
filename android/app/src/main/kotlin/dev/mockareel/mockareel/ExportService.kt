package dev.mockareel.mockareel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/** Keeps the process and CPU active during Flutter capture and native encoding. */
class ExportService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var title = "Your reel"
    private var status = "Preparing media…"
    private var percent: Int? = null
    private val manager get() = getSystemService(NotificationManager::class.java)

    override fun onCreate() {
        super.onCreate()
        instance = this
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "Video Export", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Export preparation and encoding progress"; setShowBadge(false) })
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!active) { stopSelf(); return START_NOT_STICKY }
        title = intent?.getStringExtra("title") ?: title
        val notification = notification()
        if (Build.VERSION.SDK_INT >= 35) {
            startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING)
        } else if (Build.VERSION.SDK_INT >= 29) {
            startForeground(ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(ID, notification)
        }
        if (wakeLock == null) {
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Mockareel:Export").apply {
                    setReferenceCounted(false)
                    acquire(6 * 60 * 60 * 1000L)
                }
        }
        return START_NOT_STICKY
    }

    private fun notification(complete: Boolean = false): Notification {
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else @Suppress("DEPRECATION") Notification.Builder(this)
        builder.setSmallIcon(R.drawable.ic_export_notification)
            .setContentTitle(if (complete) "Export complete" else "Exporting $title")
            .setContentText(if (complete) "Your reel is ready" else status)
            .setOnlyAlertOnce(true)
            .setOngoing(!complete)
            .setAutoCancel(complete)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setProgress(if (complete) 0 else 100, percent ?: 0, !complete && percent == null)
        if (Build.VERSION.SDK_INT >= 31) builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            builder.setContentIntent(PendingIntent.getActivity(this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        return builder.build()
    }

    private fun update(status: String, progress: Double?) {
        this.status = status
        percent = progress?.takeIf { it.isFinite() }?.times(100)?.toInt()?.coerceIn(0, 100)
        try { manager.notify(ID, notification()) } catch (_: SecurityException) { /* Permission denied. */ }
    }

    private fun finish(complete: Boolean) {
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(if (complete) STOP_FOREGROUND_DETACH else STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(!complete)
        }
        if (complete) {
            try { manager.notify(ID, notification(complete = true)) } catch (_: SecurityException) {}
        } else manager.cancel(ID)
        stopSelf()
    }

    override fun onTimeout(startId: Int, fgsType: Int) { end(this, false) }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        if (instance === this) { instance = null; active = false }
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "mockareel_export"
        private const val ID = 1001
        private var instance: ExportService? = null
        private var active = false

        fun begin(context: Context, title: String) {
            active = true
            val intent = Intent(context, ExportService::class.java).putExtra("title", title)
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            } catch (e: Exception) { active = false; throw e }
        }
        fun progress(status: String, progress: Double?) { if (active) instance?.update(status, progress) }
        fun end(context: Context, complete: Boolean) {
            active = false
            instance?.finish(complete) ?: context.stopService(Intent(context, ExportService::class.java))
        }
    }
}
