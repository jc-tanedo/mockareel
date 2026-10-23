package dev.mockareel.mockareel

import android.content.ContentValues
import android.content.Context
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.StaticOverlaySettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

@UnstableApi
class ReelRenderer(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var events: EventChannel.EventSink? = null
    private var transformer: Transformer? = null
    private var pending: MethodChannel.Result? = null
    private var output: File? = null
    private val progress = object : Runnable {
        override fun run() {
            val active = transformer ?: return
            val holder = ProgressHolder()
            if (active.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                events?.success(holder.progress / 100.0)
            }
            handler.postDelayed(this, 250)
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { events = sink }
    override fun onCancel(arguments: Any?) { events = null }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "inspect" -> worker.execute {
                try {
                    val info = inspect(requireNotNull(call.argument<String>("path")))
                    handler.post { result.success(info) }
                } catch (e: Exception) { handler.post { result.error("MEDIA", "Cannot open this media file: ${e.message}", null) } }
            }
            "export" -> try { start(call, result) } catch (e: Exception) {
                if (pending === result) finishError("EXPORT", "Could not start export: ${e.message}")
                else result.error("EXPORT", e.message, null)
            }
            "cancel" -> { cancel(); result.success(null) }
            "saveToGallery" -> worker.execute {
                try {
                    val uri = saveToGallery(requireNotNull(call.argument<String>("path")))
                    handler.post { result.success(uri) }
                } catch (e: Exception) { handler.post { result.error("GALLERY", "Could not save to gallery: ${e.message}", null) } }
            }
            else -> result.notImplemented()
        }
    }

    private fun inspect(path: String): Map<String, Any> {
        require(File(path).isFile) { "File is missing" }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            return mapOf(
                "duration" to ((retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toDoubleOrNull() ?: 0.0) / 1000.0),
                "width" to if (rotation % 180 == 0) width else height,
                "height" to if (rotation % 180 == 0) height else width,
                "hasAudio" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes"),
                "size" to File(path).length()
            )
        } finally { retriever.release() }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        check(transformer == null && pending == null) { "An export is already running" }
        val clips = requireNotNull(call.argument<List<Map<String, Any>>>("clips"))
        val overlays = requireNotNull(call.argument<List<String>>("overlays"))
        require(clips.isNotEmpty() && clips.size == overlays.size) { "Add media before exporting" }
        // Validate all inputs before creating the output, so failures never look like completed videos.
        clips.forEach { require(File(it["path"] as String).isFile) { "A source media file is missing" } }
        pending = result
        val items = clips.mapIndexed { index, clip ->
            val durationMs = ((clip["duration"] as Number).toDouble() * 1000).toLong()
            require(durationMs in 1..30000) { "Invalid clip duration" }
            val isVideo = clip["isVideo"] == true
            val media = MediaItem.Builder().setUri(Uri.fromFile(File(clip["path"] as String)))
            if (isVideo) {
                val startMs = ((clip["trimStart"] as Number).toDouble() * 1000).toLong()
                media.setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(startMs).setEndPositionMs(startMs + durationMs).build())
            } else { media.setImageDurationMs(durationMs) }
            val overlayFile = File(overlays[index])
            require(overlayFile.isFile) { "Could not read the place overlay" }
            val effects = mutableListOf<androidx.media3.common.Effect>(
                Presentation.createForWidthAndHeight(720, 604, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)
            )
            if (!isVideo) effects.add(MatrixTransformation { timeUs ->
                val scale = 1f + .04f * (timeUs.toFloat() / (durationMs * 1000f)).coerceIn(0f, 1f)
                Matrix().apply { postScale(scale, scale) }
            })
            // Fit into the 360×302 media window of the shared 360×640 template,
            // then move its center from y=640 to y=486 in the 720×1280 output.
            effects.add(Presentation.createForWidthAndHeight(720, 1280, Presentation.LAYOUT_SCALE_TO_FIT))
            effects.add(MatrixTransformation { Matrix().apply { postTranslate(0f, .240625f) } })
            effects.add(OverlayEffect(listOf(BitmapOverlay.createStaticBitmapOverlay(context, Uri.fromFile(overlayFile), StaticOverlaySettings.Builder().build()))))
            EditedMediaItem.Builder(media.build()).setFrameRate(30).setRemoveAudio(true)
                .setEffects(Effects(emptyList(), effects)).build()
        }
        val composition = Composition.Builder(EditedMediaItemSequence.Builder(items).build())
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL).build()
        val directory = File(context.filesDir, "exports").apply { mkdirs() }
        output = File(directory, "Mockareel-${System.currentTimeMillis()}.mp4")
        transformer = Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    val path = output?.absolutePath
                    events?.success(1.0)
                    val callback = pending
                    clear(deleteOutput = false)
                    callback?.success(path)
                }
                override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                    finishError("EXPORT", "Export failed (${exception.errorCodeName}): ${exception.cause?.message ?: exception.message}")
                }
            }).build()
        transformer!!.start(composition, output!!.absolutePath)
        handler.post(progress)
    }

    private fun finishError(code: String, message: String) {
        val callback = pending
        transformer?.cancel()
        clear(deleteOutput = true)
        callback?.error(code, message, null)
    }
    private fun clear(deleteOutput: Boolean) {
        handler.removeCallbacks(progress)
        transformer = null
        pending = null
        if (deleteOutput) output?.delete()
        output = null
    }
    fun cancel() { if (pending != null) finishError("CANCELLED", "Export cancelled") }
    fun close() { cancel(); worker.shutdown() }

    private fun saveToGallery(path: String): String {
        // Android 10+ scoped storage needs no broad storage permission.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw UnsupportedOperationException("Use Share video to save to Files on Android 7–9")
        }
        val source = File(path)
        require(source.isFile && source.length() > 0) { "Exported video is missing" }
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, source.name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Mockareel")
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = requireNotNull(resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values))
        try {
            requireNotNull(resolver.openOutputStream(uri)).use { sink -> source.inputStream().use { it.copyTo(sink) } }
            values.clear(); values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        } catch (e: Exception) { resolver.delete(uri, null, null); throw e }
    }
}
