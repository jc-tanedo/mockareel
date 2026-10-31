package dev.mockareel.mockareel

import android.content.ContentValues
import android.content.Context
import android.graphics.Matrix
import android.graphics.Bitmap
import androidx.media3.effect.Crop
import java.security.MessageDigest
import kotlin.math.*
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.media3.common.audio.GainProcessor
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
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
    private val mediaEdits = MediaEditsProcessor(context)
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var events: EventChannel.EventSink? = null
    private var transformer: Transformer? = null
    private var pending: MethodChannel.Result? = null
    private var output: File? = null
    private var posterCache: PosterCache? = null
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
            "processMedia" -> mediaEdits.process(call, result)
            "cancelMediaEdits" -> { mediaEdits.cancel(); result.success(null) }
            "thumbnail" -> worker.execute {
                try {
                    val path = thumbnail(requireNotNull(call.argument<String>("path")), call.argument<Number>("seconds")?.toDouble() ?: 0.0)
                    handler.post { result.success(path) }
                } catch (e: Exception) { handler.post { result.error("MEDIA", "Could not create a video thumbnail: ${e.message}", null) } }
            }
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

    private fun thumbnail(path: String, seconds: Double): String {
        val source = File(path)
        require(source.isFile && seconds.isFinite()) { "Video file is missing or its position is invalid" }
        val stamp = "$path:${source.lastModified()}:${(max(0.0, seconds) * 1000).roundToLong()}"
        val id = MessageDigest.getInstance("SHA-256").digest(stamp.toByteArray()).joinToString("") { "%02x".format(it) }
        val directory = File(context.cacheDir, "posters").apply { mkdirs() }
        val target = File(directory, "$id.jpg")
        if (target.isFile) return target.path
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val bitmap = requireNotNull(retriever.getFrameAtTime((max(0.0, seconds) * 1_000_000).toLong(), MediaMetadataRetriever.OPTION_CLOSEST)) { "No frame was decoded" }
            try {
                val factor = min(1f, 1080f / max(bitmap.width, bitmap.height))
                val scaled = if (factor < 1) Bitmap.createScaledBitmap(bitmap, max(1, (bitmap.width * factor).roundToInt()), max(1, (bitmap.height * factor).roundToInt()), true) else bitmap
                try { target.outputStream().use { check(scaled.compress(Bitmap.CompressFormat.JPEG, 92, it)) } }
                finally { if (scaled !== bitmap) scaled.recycle() }
            } finally { bitmap.recycle() }
            return target.path
        } catch (e: Exception) { target.delete(); throw e }
        finally { retriever.release() }
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

    private fun buildFeedItems(
        clips: List<Map<String, Any>>, overlays: List<String>, posters: List<String>, cache: PosterCache,
        frames: List<List<String>>, transitions: List<Number>,
    ): List<EditedMediaItem> {
        require(frames.size == clips.size && transitions.size == clips.size) { "Missing feed scene plan" }
        frames.flatten().forEach { require(File(it).isFile) { "A feed UI frame is missing" } }
        return clips.flatMapIndexed { index, clip ->
            val total = (clip["duration"] as Number).toDouble()
            require(total.isFinite() && total > 0 && total <= 30) { "Invalid scene duration" }
            require(File(overlays[index]).isFile) { "A feed overlay is missing" }
            val video = clip["isVideo"] == true
            val loop = clip["loopSource"] == true && video
            val trim = (clip["trimStart"] as? Number)?.toDouble() ?: 0.0
            val available = if (loop) min((clip["loopDuration"] as Number).toDouble(), (clip["sourceDuration"] as Number).toDouble() - trim) else total
            require(available > 0) { "Invalid source duration" }
            val (sw, sh) = cache.dimensions(posters[index])
            val aspect = sw.toFloat() / sh
            val cardAspect = 1080f / 1920f
            val zoom = ((clip["zoom"] as? Number)?.toFloat() ?: 1f).coerceIn(1f, 3f)
            val pan = ((clip["panX"] as? Number)?.toFloat() ?: 0f).coerceIn(-1f, 1f)
            val fx = min(1f, cardAspect / aspect) / zoom
            val fy = min(1f, aspect / cardAspect) / zoom
            val cx = pan * (1 - fx)
            val items = mutableListOf<EditedMediaItem>()
            var offset = 0.0
            while (offset < total - .0001) {
                val segment = min(available, total - offset)
                val sceneOffset = offset
                val media = MediaItem.Builder().setUri(Uri.fromFile(File(clip["path"] as String)))
                if (video) media.setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs((trim * 1000).roundToLong())
                    .setEndPositionMs(((trim + segment) * 1000).roundToLong()).build())
                else media.setImageDurationMs((segment * 1000).roundToLong())
                val clock = ClipClock()
                val transition = transitions[index].toDouble()
                val effects = listOf<androidx.media3.common.Effect>(
                    Crop(cx - fx, cx + fx, -fy, fy),
                    Presentation.createForWidthAndHeight(1080, 1920, Presentation.LAYOUT_SCALE_TO_FIT),
                    MatrixTransformation { timeUs ->
                        clock.begin(timeUs)
                        val entry = FeedMotion.entry(sceneOffset + clock.elapsed(timeUs), transition)
                        Matrix().apply {
                            val camera = clip["cameraMotion"] as? Map<String, Any>
                            if (camera != null) {
                                setValues(StreetviewMotion.matrix(sceneOffset + clock.elapsed(timeUs), total, camera))
                            } else if (clip["slowPanZoom"] == true) {
                                val t = ((sceneOffset + clock.elapsed(timeUs)) / total).coerceIn(0.0, 1.0).toFloat()
                                postScale(1 + t * .06f, 1 + t * .06f)
                                postTranslate(-2 * t * 8 / 360f, 0f)
                            }
                            postTranslate(0f, -2 * entry / 640f)
                        }
                    },
                    OverlayEffect(listOf(FeedFrameOverlay(overlays[index], frames[index], clock, sceneOffset, if (transition > 0) transition else total)))
                )
                items.add(EditedMediaItem.Builder(media.build()).setFrameRate(30).setRemoveAudio(true)
                    .setEffects(Effects(emptyList(), effects)).build())
                offset += segment
            }
            items
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        check(transformer == null && pending == null) { "An export is already running" }
        val clips = requireNotNull(call.argument<List<Map<String, Any>>>("clips"))
        val overlays = requireNotNull(call.argument<List<String>>("overlays"))
        require(clips.isNotEmpty() && clips.size == overlays.size) { "Add media before exporting" }
        // Validate all inputs before creating the output, so failures never look like completed videos.
        clips.forEach { require(File(it["path"] as String).isFile) { "A source media file is missing" } }
        val starts = requireNotNull(call.argument<List<String>>("posters"))
        val ends = requireNotNull(call.argument<List<String>>("endPosters"))
        require(starts.size == clips.size && ends.size == clips.size) { "Missing scene thumbnails" }
        val layout = SheetLayout.from(requireNotNull(call.argument<Map<String, Number>>("layout")))
        val slideSeconds = call.argument<Number>("slideSeconds")?.toDouble() ?: .42
        val introFrames = call.argument<List<String>>("introFrames") ?: emptyList()
        val introSeconds = call.argument<Number>("sheetIntroSeconds")?.toDouble() ?: 0.0
        require(introSeconds.isFinite() && introSeconds in 0.0..2.0) { "Invalid reveal duration" }
        introFrames.forEach { require(File(it).isFile) { "An intro frame is missing" } }
        val backgroundColor = call.argument<Number>("backgroundColor")?.toInt() ?: android.graphics.Color.WHITE
        val progressColor = call.argument<Number>("progressColor")?.toInt() ?: android.graphics.Color.rgb(26, 115, 232)
        var globalStart = 0.0
        val cards = clips.mapIndexed { i, c -> CardSpec(
            layout.gallery.width() * ((c["cardWidth"] as? Number)?.toFloat() ?: .78f).coerceIn(.45f, 1f),
            layout.gallery.height() * ((c["cardHeight"] as? Number)?.toFloat() ?: 1f).coerceIn(.55f, 1f),
            ((c["zoom"] as? Number)?.toFloat() ?: 1f).coerceIn(1f, 3f),
            ((c["panX"] as? Number)?.toFloat() ?: 0f).coerceIn(-1f, 1f), starts[i], ends[i]) }
        pending = result
        val cache = PosterCache(); posterCache = cache
        val items = if (call.argument<String>("template") == "tiktok-feed") {
            buildFeedItems(clips, overlays, starts, cache,
                call.argument<List<List<String>>>("sceneFrames") ?: emptyList(),
                call.argument<List<Number>>("transitions") ?: emptyList())
        } else clips.mapIndexed { index, clip ->
            val sceneStart = globalStart
            globalStart += (clip["duration"] as Number).toDouble()
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
            val card = cards[index]
            val (sourceWidth, sourceHeight) = cache.dimensions(starts[index])
            val aspect = sourceWidth.toFloat() / sourceHeight
            val cardAspect = card.width / card.height
            val fractionX = min(1f, cardAspect / aspect) / card.zoom
            val fractionY = min(1f, aspect / cardAspect) / card.zoom
            val centerX = card.panX * (1 - fractionX)
            val transition = if (index == 0) 0.0 else min(slideSeconds, durationMs / 1000.0 * .45)
            val clock = ClipClock()
            val cardWidth = max(2, (card.width / 2).roundToInt() * 2)
            val cardHeight = max(2, (card.height / 2).roundToInt() * 2)
            val effects = mutableListOf<androidx.media3.common.Effect>(
                Crop(centerX - fractionX, centerX + fractionX, -fractionY, fractionY),
                Presentation.createForWidthAndHeight(cardWidth, cardHeight, Presentation.LAYOUT_SCALE_TO_FIT),
                Presentation.createForWidthAndHeight(layout.width, layout.height, Presentation.LAYOUT_SCALE_TO_FIT),
                MatrixTransformation { timeUs ->
                    clock.begin(timeUs)
                    val entry = if (index == 0) 0f else ScrollMotion.entryOffset(cards[index - 1].width, layout.gap, clock.elapsed(timeUs), transition)
                    val scale = card.width / layout.width
                    val x = 2 * (layout.gallery.left + entry + card.width / 2) / layout.width - 1
                    val shift = SheetMotion.offset(SheetMotion.sampleTime(sceneStart + clock.elapsed(timeUs), introSeconds, introFrames.size), introSeconds) * layout.scale
                    val y = 1 - 2 * (layout.gallery.centerY() + shift) / layout.height
                    Matrix().apply { postScale(scale, scale); postTranslate(x, y) }
                },
                OverlayEffect(listOf(ScrollOverlay(layout, cards, index, transition, overlayFile.path, cache, clock, sceneStart, durationMs / 1000.0, introSeconds, introFrames, backgroundColor, progressColor)))
            )
            EditedMediaItem.Builder(media.build()).setFrameRate(30).setRemoveAudio(true)
                .setEffects(Effects(emptyList(), effects)).build()
        }
        val sequences = mutableListOf(EditedMediaItemSequence.Builder(items).build())
        val music = call.argument<Map<String, Any>>("music")
        if (music != null) {
            val path = music["path"] as String
            require(File(path).isFile) { "The music file is missing. Replace or remove it in Audio." }
            val info = inspect(path)
            require(info["hasAudio"] == true) { "The selected file has no audio track" }
            val sourceMs = ((info["duration"] as Double) * 1000).toLong()
            val startMs = (((music["trimStart"] as? Number)?.toDouble() ?: 0.0) * 1000).toLong().coerceIn(0, max(0, sourceMs - 100))
            val reelMs = clips.sumOf { ((it["duration"] as Number).toDouble() * 1000).toLong() }
            val volume = ((music["volume"] as? Number)?.toFloat() ?: .7f).coerceIn(0f, 1f)
            val gain = GainProcessor(object : GainProcessor.GainProvider {
                override fun getGainFactorAtSamplePosition(samplePosition: Long, sampleRate: Int) = volume
                override fun isUnityUntil(samplePosition: Long, sampleRate: Int): Long = if (volume == 1f) androidx.media3.common.C.TIME_END_OF_SOURCE else androidx.media3.common.C.TIME_UNSET
            })
            val audio = MediaItem.Builder().setUri(Uri.fromFile(File(path)))
                .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder().setStartPositionMs(startMs)
                    .setEndPositionMs(min(sourceMs, startMs + reelMs)).build()).build()
            val audioItem = EditedMediaItem.Builder(audio).setRemoveVideo(true)
                .setEffects(Effects(listOf(gain), emptyList())).build()
            sequences.add(EditedMediaItemSequence.Builder(audioItem).setIsLooping(music["loop"] != false).build())
        }
        val composition = Composition.Builder(sequences)
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL).build()
        val directory = File(context.filesDir, "exports").apply { mkdirs() }
        output = File(directory, "Mockareel-${System.currentTimeMillis()}.mp4")
        transformer = Transformer.Builder(context).setVideoMimeType(MimeTypes.VIDEO_H264).setAudioMimeType(MimeTypes.AUDIO_AAC)
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
        posterCache?.close(); posterCache = null
        if (deleteOutput) output?.delete()
        output = null
    }
    fun cancel() { mediaEdits.cancel(); if (pending != null) finishError("CANCELLED", "Export cancelled") }
    fun close() { cancel(); mediaEdits.close(); worker.shutdown() }

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
