package dev.mockareel.mockareel

import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

@UnstableApi
class MainActivity : FlutterActivity() {
    private var renderer: ReelRenderer? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val instance = ReelRenderer(applicationContext)
        renderer = instance
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render").setMethodCallHandler(instance)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render-progress").setStreamHandler(instance)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        renderer?.close()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render").setMethodCallHandler(null)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.mockareel/render-progress").setStreamHandler(null)
        renderer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
