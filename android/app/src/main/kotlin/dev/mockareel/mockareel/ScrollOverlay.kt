package dev.mockareel.mockareel

import android.graphics.*
import android.util.LruCache
import androidx.exifinterface.media.ExifInterface
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import java.io.File
import kotlin.math.*

internal object ScrollMotion {
    fun entryOffset(previousWidth: Float, gap: Float, elapsed: Double, duration: Double): Float {
        if (duration <= 0 || elapsed >= duration) return 0f
        val t = M3Motion.defaultSpatial.at(elapsed, duration)
        return ((previousWidth + gap) * (1.0 - t)).toFloat()
    }
}

internal object SheetMotion {
    // UI intro frames are captured at 60 fps. Match texture/mask geometry to the
    // same frame, including microsecond timestamps just below 1/60 second.
    fun sampleTime(time: Double, duration: Double, frames: Int): Double {
        if (frames <= 0 || time >= duration) return time
        return min((time * M3Motion.EXPORT_FPS).roundToInt(), frames - 1) / M3Motion.EXPORT_FPS.toDouble()
    }

    fun offset(time: Double, duration: Double): Float {
        if (duration <= 0 || time >= duration) return 0f
        return (130.0 * (1.0 - M3Motion.slowSpatial.at(time, duration))).toFloat()
    }
}

internal class ClipClock {
    private var firstTimeUs: Long? = null
    fun begin(timeUs: Long) { if (firstTimeUs == null) firstTimeUs = timeUs }
    fun elapsed(timeUs: Long): Double = firstTimeUs?.let { max(0.0, (timeUs - it) / 1_000_000.0) } ?: 0.0
}

internal data class SheetLayout(val scale: Float, val width: Int, val height: Int, val gallery: RectF, val gap: Float, val radius: Float) {
    companion object {
        fun from(map: Map<String, Number>): SheetLayout {
            fun n(key: String) = requireNotNull(map[key]).toFloat()
            val scale = n("exportScale")
            val left = n("galleryLeft") * scale; val top = n("galleryTop") * scale
            return SheetLayout(
                scale, (n("width") * scale).roundToInt(), (n("height") * scale).roundToInt(),
                RectF(left, top, left + n("galleryWidth") * scale, top + n("galleryHeight") * scale),
                n("gap") * scale, n("radius") * scale
            )
        }
    }
}

internal data class CardSpec(val width: Float, val height: Float, val zoom: Float, val panX: Float, val poster: String, val endPoster: String)

internal class PosterCache {
    private val cache = object : LruCache<String, Bitmap>(24 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.allocationByteCount
    }
    fun bitmap(path: String): Bitmap = cache.get(path) ?: decode(path).also { cache.put(path, it) }
    fun dimensions(path: String): Pair<Int, Int> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Cannot decode a media thumbnail" }
        val orientation = orientation(path)
        return if (orientation in listOf(ExifInterface.ORIENTATION_ROTATE_90, ExifInterface.ORIENTATION_ROTATE_270, ExifInterface.ORIENTATION_TRANSPOSE, ExifInterface.ORIENTATION_TRANSVERSE)) bounds.outHeight to bounds.outWidth else bounds.outWidth to bounds.outHeight
    }
    private fun orientation(path: String) = try { ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) } catch (_: Exception) { ExifInterface.ORIENTATION_NORMAL }
    private fun decode(path: String): Bitmap {
        require(File(path).isFile) { "A thumbnail file is missing" }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > 1800) sample *= 2
        val raw = requireNotNull(BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample }))
        val matrix = Matrix()
        when (orientation(path)) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(-90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
        }
        return if (matrix.isIdentity) raw else Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, matrix, true).also { if (it !== raw) raw.recycle() }
    }
    fun close() { cache.evictAll() }
}

/** One active video texture; neighboring videos use decoded stills during the
 * slide. Card backgrounds, rounded masks, and the M3 wavy progress indicator
 * are composited over the shared Flutter UI PNG. */
@UnstableApi
internal class ScrollOverlay(
    private val layout: SheetLayout,
    private val cards: List<CardSpec>,
    private val index: Int,
    private val duration: Double,
    private val uiPath: String,
    private val posters: PosterCache,
    private val clock: ClipClock,
    private val globalStart: Double,
    private val clipDuration: Double,
    private val introSeconds: Double,
    private val introFrames: List<String>,
    private val backgroundColor: Int,
    private val progressColor: Int,
    private val slideFrames: List<String> = emptyList(),
) : BitmapOverlay() {
    private var frame: Bitmap? = null
    private var ui: Bitmap? = null
    private var loadedUiPath: String? = null
    private var lastTimeUs: Long? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val clear = Paint(Paint.ANTI_ALIAS_FLAG).apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR) }
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeWidth = 2.8f * layout.scale
        val a = ((progressColor ushr 24) and 0xFF) * 0.24f
        color = (progressColor and 0x00FFFFFF) or (a.roundToInt() shl 24)
    }
    private val wavePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        strokeWidth = 2.8f * layout.scale
        color = progressColor
    }
    private val wavePath = Path()
    private val starts = FloatArray(cards.size).apply { var x = 0f; cards.forEachIndexed { i, c -> this[i] = x; x += c.width + layout.gap } }

    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        if (lastTimeUs == presentationTimeUs && frame != null) return frame!!
        clock.begin(presentationTimeUs)
        lastTimeUs = presentationTimeUs
        val bitmap = frame ?: Bitmap.createBitmap(layout.width, layout.height, Bitmap.Config.ARGB_8888).also { frame = it }
        val elapsed = clock.elapsed(presentationTimeUs)
        val globalTime = SheetMotion.sampleTime(globalStart + elapsed, introSeconds, introFrames.size)
        val shift = SheetMotion.offset(globalTime, introSeconds) * layout.scale
        val gallery = RectF(layout.gallery).apply { offset(0f, shift) }
        val introIndex = (globalTime * M3Motion.EXPORT_FPS).roundToInt()
        val slideIndex = (elapsed * M3Motion.EXPORT_FPS).roundToInt()
        val path = if (globalTime < introSeconds && introIndex < introFrames.size) {
            introFrames[introIndex]
        } else if (slideFrames.isNotEmpty() && elapsed < duration) {
            slideFrames[slideIndex.coerceIn(0, slideFrames.size - 1)]
        } else {
            uiPath
        }
        if (loadedUiPath != path) { ui?.recycle(); ui = requireNotNull(BitmapFactory.decodeFile(path)); loadedUiPath = path }
        val overlay = requireNotNull(ui)
        bitmap.eraseColor(Color.TRANSPARENT)
        val canvas = Canvas(bitmap)
        val entry = if (index == 0) 0f else ScrollMotion.entryOffset(cards[index - 1].width, layout.gap, clock.elapsed(presentationTimeUs), duration)
        val offset = starts[index] - entry
        canvas.save()
        canvas.clipRect(gallery)
        canvas.drawColor(backgroundColor)
        for (i in max(0, index - 1) until cards.size) {
            val card = cards[i]
            val left = gallery.left + starts[i] - offset
            if (left >= gallery.right) break
            if (left + card.width <= gallery.left) continue
            val rect = RectF(left, gallery.centerY() - card.height / 2, left + card.width, gallery.centerY() + card.height / 2)
            if (i == index) {
                canvas.drawRoundRect(rect, layout.radius, layout.radius, clear)
            } else {
                val image = posters.bitmap(if (i < index) card.endPoster else card.poster)
                canvas.save()
                canvas.clipPath(Path().apply { addRoundRect(rect, layout.radius, layout.radius, Path.Direction.CW) })
                val scale = max(rect.width() / image.width, rect.height() / image.height) * card.zoom
                val w = image.width * scale; val h = image.height * scale
                val x = rect.left - (w - rect.width()) * (card.panX + 1) / 2
                val y = rect.centerY() - h / 2
                canvas.drawBitmap(image, null, RectF(x, y, x + w, y + h), paint)
                canvas.restore()
            }
        }
        canvas.restore()
        canvas.drawBitmap(overlay, null, Rect(0, 0, layout.width, layout.height), paint)

        // Material 3 Expressive wavy progress indicator aligned with Flutter M3WavyProgressPainter.
        canvas.save(); canvas.clipRect(gallery)
        val active = cards[index]
        val cardLeft = gallery.left + starts[index] - offset
        val inset = 1.4f * layout.scale
        val barLeft = cardLeft + inset
        val barRight = max(barLeft, cardLeft + active.width - inset)
        val centerY = gallery.bottom - 4f * layout.scale
        val progress = (elapsed / clipDuration).coerceIn(0.0, 1.0).toFloat()
        val activeEnd = barLeft + (barRight - barLeft) * progress
        if (activeEnd < barRight) {
            canvas.drawLine(max(barLeft, activeEnd), centerY, barRight, centerY, trackPaint)
        }
        val activeSpan = activeEnd - barLeft
        if (activeSpan > 0.5f * layout.scale) {
            if (activeSpan < 6f * layout.scale) {
                canvas.drawLine(barLeft, centerY, activeEnd, centerY, wavePaint)
            } else {
                wavePath.reset()
                wavePath.moveTo(barLeft, centerY)
                val step = 2f * layout.scale
                val waveLen = 14f * layout.scale
                val amp = 1.2f * layout.scale
                val phase = (elapsed * 3.2 * PI).toFloat()
                val taper = 8f * layout.scale
                val steps = ceil(activeSpan / step).toInt()
                for (s in 1..steps) {
                    val x = min(activeEnd, barLeft + s * step)
                    val dist = min(x - barLeft, activeEnd - x)
                    var env = (dist / taper).coerceIn(0f, 1f)
                    env = env * env * (3f - 2f * env)
                    val angle = (x - barLeft) * (2f * PI.toFloat()) / waveLen - phase
                    val y = centerY + sin(angle) * amp * env
                    wavePath.lineTo(x, y)
                }
                canvas.drawPath(wavePath, wavePaint)
            }
        }
        canvas.restore()
        return bitmap
    }

    override fun release() {
        super.release()
        frame?.recycle(); frame = null
        ui?.recycle(); ui = null
    }
}

internal object FeedMotion {
    fun sample(time: Double): Double = max(0, (time * M3Motion.EXPORT_FPS).roundToInt()) / M3Motion.EXPORT_FPS.toDouble()
    fun entry(elapsed: Double, duration: Double): Float {
        if (duration <= 0 || elapsed >= duration) return 0f
        val q = M3Motion.quantize(elapsed, duration)
        return (640.0 * (1.0 - M3Motion.defaultSpatial.at(q, duration))).toFloat()
    }
    fun searchEnterScale(elapsed: Double, duration: Double): Float {
        if (duration <= 0.0 || elapsed >= duration) return 1f
        val q = M3Motion.quantize(elapsed, duration)
        return M3Motion.lerp(0.94, 1.0, M3Motion.defaultSpatial.at(q, duration)).toFloat()
    }
    fun frame(elapsed: Double, count: Int): Int =
        if (count <= 0) -1 else (elapsed * M3Motion.EXPORT_FPS).roundToInt().coerceIn(0, count - 1)
}

/** Only UI and the outgoing post are rasterized. The active video stays a native
 * texture, preserving motion and avoiding a full-reel frame image sequence. */
@UnstableApi
internal class FeedFrameOverlay(
    private val path: String, private val frames: List<String>,
    private val clock: ClipClock, private val offset: Double, private val animatedDuration: Double,
) : BitmapOverlay() {
    private var loadedPath: String? = null
    private var bitmap: Bitmap? = null
    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        clock.begin(presentationTimeUs)
        val elapsed = offset + clock.elapsed(presentationTimeUs)
        val index = FeedMotion.frame(elapsed, frames.size)
        val current = if (index >= 0 && elapsed < animatedDuration) frames[index] else path
        if (loadedPath != current) {
            bitmap?.recycle()
            bitmap = requireNotNull(BitmapFactory.decodeFile(current)) { "Cannot decode a feed UI frame" }
            loadedPath = current
        }
        return requireNotNull(bitmap)
    }
    override fun release() { super.release(); bitmap?.recycle(); bitmap = null }
}
