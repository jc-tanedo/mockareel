package dev.mockareel.mockareel

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.*

/** Independent from reel export: a bounded, cached media segment without UI. */
@UnstableApi
internal class MediaEditsProcessor(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var transformer: Transformer? = null
    private var intermediate: File? = null
    private var output: File? = null

    fun process(call: MethodCall, result: MethodChannel.Result) {
        try {
            check(pending == null) { "Media preparation is already running" }
            val path = requireNotNull(call.argument<String>("path"))
            require(File(path).isFile) { "Source media is missing" }
            val video = call.argument<Boolean>("isVideo") == true
            val duration = call.argument<Number>("duration")!!.toDouble()
            val trim = call.argument<Number>("trimStart")!!.toDouble()
            require(duration.isFinite() && duration > 0 && duration <= 30 && trim.isFinite() && trim >= 0)
            val spec = MediaEditSpec.from(requireNotNull(call.argument<Map<String, Any>>("edits")), video)
            val target = File(requireNotNull(call.argument<String>("output")))
            require(!target.exists())
            val scratch = File("${target.path}.processing.mp4")
            pending = result; output = target; intermediate = scratch
            worker.execute {
                try {
                    val size = dimensions(path, video)
                    val factor = min(1.0, 1920.0 / max(size.first, size.second))
                    fun even(n: Int) = max(64, (n * factor / 2).roundToInt() * 2)
                    val width = even(size.first); val height = even(size.second)
                    handler.post {
                        if (pending === result) try {
                            val source = MediaItem.Builder().setUri(Uri.fromFile(File(path)))
                            if (video) source.setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                                .setStartPositionMs((trim * 1000).roundToLong())
                                .setEndPositionMs(((trim + duration) * 1000).roundToLong()).build())
                            else source.setImageDurationMs(100)
                            val item = EditedMediaItem.Builder(source.build()).setRemoveAudio(true).setFrameRate(30)
                                .setEffects(Effects(emptyList(), listOf(
                                    Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT),
                                    MediaEditsEffect(spec),
                                ))).build()
                            val composition = Composition.Builder(EditedMediaItemSequence.Builder(item).build())
                                .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL).build()
                            transformer = Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264)
                                .addListener(object : Transformer.Listener {
                                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                                        if (pending !== result) return
                                        transformer = null
                                        if (video) {
                                            if (!scratch.renameTo(target)) { fail("Could not retain edited media"); return }
                                            finish(result)
                                        } else worker.execute {
                                            try {
                                                val reader = MediaMetadataRetriever()
                                                try {
                                                    reader.setDataSource(scratch.path)
                                                    val bitmap = requireNotNull(reader.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST))
                                                    try { target.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) } }
                                                    finally { bitmap.recycle() }
                                                } finally { reader.release(); scratch.delete() }
                                                handler.post { if (pending === result) finish(result) else target.delete() }
                                            } catch (_: Exception) {
                                                handler.post { if (pending === result) fail("Could not prepare edited photo") else target.delete() }
                                            }
                                        }
                                    }
                                    override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                                        if (pending === result) fail("Media effects failed (${exception.errorCodeName}). Retry or adjust the media.")
                                    }
                                }).build()
                            transformer!!.start(composition, scratch.path)
                        } catch (_: Exception) { fail("Could not start media processing") }
                    }
                } catch (_: Exception) { handler.post { if (pending === result) fail("Could not read source media") } }
            }
        } catch (e: Exception) {
            if (pending === result) fail("Could not prepare media: ${e.message}")
            else result.error("MEDIA_EDITS", e.message, null)
        }
    }
    private fun dimensions(path: String, video: Boolean): Pair<Int, Int> {
        if (!video) return PosterCache().dimensions(path)
        val reader = MediaMetadataRetriever()
        try {
            reader.setDataSource(path)
            val w = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
            val h = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
            val rotation = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            return if (rotation % 180 == 0) w to h else h to w
        } finally { reader.release() }
    }
    private fun finish(result: MethodChannel.Result) {
        val path = output!!.path
        intermediate?.delete(); intermediate = null; output = null; pending = null
        result.success(path)
    }
    private fun fail(message: String, code: String = "MEDIA_EDITS") {
        val result = pending; pending = null
        transformer?.cancel(); transformer = null
        intermediate?.delete(); intermediate = null
        output?.delete(); output = null
        result?.error(code, message, null)
    }
    fun cancel() { if (pending != null) fail("Media processing cancelled", "CANCELLED") }
    fun close() { cancel(); worker.shutdown() }
}
