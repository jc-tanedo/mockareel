package dev.mockareel.mockareel

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ExportSessionHost(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pendingStart: (() -> Unit)? = null
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                if (pendingStart != null) { result.error("BUSY", "Notification permission is pending", null); return }
                val begin = {
                    try {
                        ExportService.begin(activity.applicationContext, call.argument<String>("title") ?: "reel")
                        val enabled = if (Build.VERSION.SDK_INT >= 24) {
                            activity.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
                        } else true
                        result.success(enabled)
                    } catch (e: Exception) { result.error("BACKGROUND_EXPORT", e.message, null) }
                }
                if (Build.VERSION.SDK_INT >= 33 &&
                    activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    pendingStart = begin
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST)
                } else begin()
            }
            "update" -> {
                ExportService.progress(call.argument<String>("status") ?: "Preparing media…", call.argument<Number>("progress")?.toDouble())
                result.success(null)
            }
            "finish" -> { ExportService.end(activity.applicationContext, call.argument<Boolean>("complete") == true); result.success(null) }
            else -> result.notImplemented()
        }
    }
    fun onPermissionsResult(requestCode: Int) {
        if (requestCode == REQUEST) { val begin = pendingStart; pendingStart = null; begin?.invoke() }
    }
    companion object { private const val REQUEST = 57190 }
}
