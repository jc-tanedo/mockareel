package dev.mockareel.mockareel

import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

@UnstableApi
class MainActivity : FlutterActivity() {
    private var gifEncoder: GifVideoEncoder? = null
    private var mapSnapshot: MapSnapshot? = null
    private var exportSession: ExportSessionHost? = null
    private var renderer: ReelRenderer? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        exportSession = ExportSessionHost(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/export-session").setMethodCallHandler(exportSession)
        gifEncoder = GifVideoEncoder(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/gif").setMethodCallHandler(gifEncoder)
        mapSnapshot = MapSnapshot(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/map-snapshot").setMethodCallHandler(mapSnapshot)
        val instance = ReelRenderer(applicationContext)
        renderer = instance
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render").setMethodCallHandler(instance)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render-progress").setStreamHandler(instance)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        exportSession?.onPermissionsResult(requestCode)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ExportService.end(applicationContext, false)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/export-session").setMethodCallHandler(null)
        exportSession = null
        gifEncoder?.close(); gifEncoder = null
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/gif").setMethodCallHandler(null)
        mapSnapshot?.close()
        mapSnapshot = null
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/map-snapshot").setMethodCallHandler(null)
        renderer?.close()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render").setMethodCallHandler(null)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render-progress").setStreamHandler(null)
        renderer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
