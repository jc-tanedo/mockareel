package dev.mockareel.mockareel

import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/** Copy the visible hybrid-composited WebView, including GPU map tiles. */
class MapSnapshot(private val activity: FlutterActivity) : MethodChannel.MethodCallHandler {
    private val encoder = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var closed = false
    private var pending = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "capture") { result.notImplemented(); return }
        if (closed || pending || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unavailable", "Map capture requires Android 8 or newer and an idle capture session.", null)
            return
        }
        val values = listOf("left", "top", "width", "height").map { call.argument<Number>(it)?.toDouble() }
        if (values.any { it == null || !it.isFinite() }) {
            result.error("bounds", "Invalid map viewport.", null); return
        }
        val (left, top, width, height) = values.map { it!!.roundToInt() }
        val flutterView = activity.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)
        val offset = IntArray(2)
        flutterView.getLocationInWindow(offset)
        val rect = Rect(left + offset[0], top + offset[1], left + offset[0] + width, top + offset[1] + height)
        val decor = activity.window.decorView
        if (width < 1 || height < 1 || width.toLong() * height > 4_000_000 || rect.left < 0 || rect.top < 0 || rect.right > decor.width || rect.bottom > decor.height) {
            result.error("bounds", "Map viewport must be fully visible. Scroll it into view and retry.", null); return
        }
        pending = true
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            PixelCopy.request(activity.window, rect, bitmap, { status ->
                if (status != PixelCopy.SUCCESS || closed) {
                    bitmap.recycle(); pending = false
                    result.error("capture", "Map capture was interrupted. Retry when the map is visible.", null)
                } else {
                    encoder.execute {
                        try {
                            val stream = ByteArrayOutputStream()
                            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream))
                            val bytes = stream.toByteArray()
                            main.post { pending = false; result.success(bytes) }
                        } catch (_: Exception) {
                            main.post { pending = false; result.error("encode", "Could not save map image.", null) }
                        } finally { bitmap.recycle() }
                    }
                }
            }, main)
        } catch (_: Exception) {
            bitmap.recycle(); pending = false
            result.error("capture", "Could not copy map viewport.", null)
        }
    }
    fun close() { closed = true; encoder.shutdown() }
}
