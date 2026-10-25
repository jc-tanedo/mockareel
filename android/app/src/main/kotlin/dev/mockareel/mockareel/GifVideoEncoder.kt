package dev.mockareel.mockareel

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** One 30 fps image source, with timestamped GIF frames over a black matte.
 * Using one asset avoids per-frame image-loader startup and duration rounding. */
@UnstableApi
class GifVideoEncoder(private val context: Context) : MethodChannel.MethodCallHandler {
    private var transformer: Transformer? = null
    private var pending: MethodChannel.Result? = null
    private var output: File? = null
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") { close(); result.success(null); return }
        if (call.method != "encode") { result.notImplemented(); return }
        try {
            check(pending == null) { "GIF preparation is already running" }
            val duration = requireNotNull(call.argument<Number>("duration")).toDouble()
            require(duration.isFinite() && duration > 0 && duration <= 30)
            val width = requireNotNull(call.argument<Number>("width")).toInt()
            val height = requireNotNull(call.argument<Number>("height")).toInt()
            require(width in 64..1080 && height in 64..1080 && width % 2 == 0 && height % 2 == 0)
            val frames = requireNotNull(call.argument<List<Map<String, Any>>>("frames"))
            require(frames.isNotEmpty() && frames.size <= 900)
            val paths = frames.map { it["path"] as String }
            val times = frames.map { (it["timeUs"] as Number).toLong() }
            require(times.first() == 0L && times.zipWithNext().all { it.first < it.second })
            require(times.last() < (duration * 1_000_000).toLong())
            paths.forEach { require(File(it).isFile) }
            val base = File(requireNotNull(call.argument<String>("base")))
            require(base.isFile)
            val target = File(requireNotNull(call.argument<String>("output")))
            require(!target.exists())
            pending = result; output = target
            val source = MediaItem.Builder().setUri(Uri.fromFile(base)).setImageDurationMs((duration * 1000).toLong().coerceAtLeast(1)).build()
            val item = EditedMediaItem.Builder(source).setFrameRate(30).setRemoveAudio(true)
                .setEffects(Effects(emptyList(), listOf(
                    Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT),
                    OverlayEffect(listOf(GifOverlay(paths, times))),
                ))).build()
            val composition = Composition.Builder(EditedMediaItemSequence.Builder(item).build()).build()
            transformer = Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        val callback = pending; pending = null; transformer = null; output = null
                        callback?.success(null)
                    }
                    override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                        fail("GIF", "Could not prepare GIF video: ${exception.errorCodeName}")
                    }
                }).build()
            transformer!!.start(composition, target.path)
        } catch (_: Exception) {
            if (pending === result) fail("GIF", "Could not prepare this GIF. Try a shorter segment.")
            else result.error("GIF", "Could not prepare this GIF. Try a shorter segment.", null)
        }
    }
    private fun fail(code: String, message: String) {
        val callback = pending
        pending = null; transformer?.cancel(); transformer = null
        output?.delete(); output = null
        callback?.error(code, message, null)
    }
    fun close() { if (pending != null) fail("CANCELLED", "GIF preparation cancelled") }
}

internal object GifFrameClock {
    fun index(times: List<Long>, timeUs: Long): Int {
        var low = 0; var high = times.size
        while (low < high) {
            val mid = (low + high) / 2
            if (times[mid] <= timeUs + 1) low = mid + 1 else high = mid
        }
        return (low - 1).coerceAtLeast(0)
    }
}

@UnstableApi
private class GifOverlay(private val paths: List<String>, private val times: List<Long>) : BitmapOverlay() {
    private var bitmap: Bitmap? = null
    private var current = -1
    private val clock = ClipClock()
    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        clock.begin(presentationTimeUs)
        val index = GifFrameClock.index(times, (clock.elapsed(presentationTimeUs) * 1_000_000).toLong())
        if (index != current) {
            val next = requireNotNull(BitmapFactory.decodeFile(paths[index]))
            bitmap?.recycle(); bitmap = next; current = index
        }
        return requireNotNull(bitmap)
    }
    override fun release() { super.release(); bitmap?.recycle(); bitmap = null }
}
