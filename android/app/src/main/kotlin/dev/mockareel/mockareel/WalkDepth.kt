package dev.mockareel.mockareel

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import org.tensorflow.lite.Interpreter

/**
 * Executed on a serial background channel. The only network request is for the model. Source
 * pixels, inferred depth and filled layers stay on-device.
 */
class WalkDepth(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "layers") {
            result.notImplemented()
            return
        }
        try {
            val w = call.argument<Int>("width")!!
            val h = call.argument<Int>("height")!!
            require(w in 1..1440 && h in 1..1440)
            val bytes = call.argument<ByteArray>("rgba")!!
            require(bytes.size == w * h * 4)
            val pixels =
                IntArray(w * h) { i ->
                    val k = i * 4
                    Color.argb(
                        bytes[k + 3].toInt() and 255,
                        bytes[k].toInt() and 255,
                        bytes[k + 1].toInt() and 255,
                        bytes[k + 2].toInt() and 255,
                    )
                }
            val depth = infer(modelFile(), pixels, w, h)
            val sorted = depth.sortedArray()
            val near = sorted[sorted.size * 2 / 3]
            val middle = sorted[sorted.size / 3]
            val classes =
                IntArray(pixels.size) { i ->
                    val x = i % w * 255.0 / (w - 1).coerceAtLeast(1)
                    val y = i / w * 255.0 / (h - 1).coerceAtLeast(1)
                    val ix = x.toInt()
                    val iy = y.toInt()
                    val nx = (ix + 1).coerceAtMost(255)
                    val ny = (iy + 1).coerceAtMost(255)
                    val dx = x - ix
                    val dy = y - iy
                    val d =
                        (depth[iy * 256 + ix] * (1 - dx) + depth[iy * 256 + nx] * dx) * (1 - dy) +
                            (depth[ny * 256 + ix] * (1 - dx) + depth[ny * 256 + nx] * dx) * dy
                    when {
                        d > near -> 2
                        d > middle -> 1
                        else -> 0
                    }
                }
            // Keep continuous depth within each visibility layer so a wall or floor
            // changes perspective as the camera passes it.
            val grid =
                ByteArray(32 * 32) { index ->
                    val d = depth[(index / 32 * 255 / 31) * 256 + (index % 32 * 255 / 31)]
                    val band = if (d > near) 2 else if (d > middle) 1 else 0
                    val low =
                        when (band) {
                            0 -> sorted[sorted.size / 100]
                            1 -> middle
                            else -> near
                        }
                    val high =
                        when (band) {
                            0 -> middle
                            1 -> near
                            else -> sorted[sorted.size * 99 / 100]
                        }
                    val fraction = ((d - low) / (high - low).coerceAtLeast(0.001f)).coerceIn(0f, 1f)
                    ((band + fraction) * 85).toInt().toByte()
                }
            result.success(
                mapOf(
                    "layers" to (0..2).map { layer -> layerPng(pixels, classes, w, h, layer) },
                    "depth" to grid,
                )
            )
        } catch (e: Exception) {
            result.error("photo_depth", e.localizedMessage ?: "Photo preparation failed", null)
        }
    }

    private fun modelFile(): File {
        val file = File(context.noBackupFilesDir, "midas-v2_1-small.tflite")
        if (file.isFile && file.length() == 66338288L) return file
        val tmp = File.createTempFile("depth-", ".part", context.noBackupFilesDir)
        try {
            val digest = MessageDigest.getInstance("SHA-256")
            val conn =
                URL("https://github.com/isl-org/MiDaS/releases/download/v2_1/model_opt.tflite")
                    .openConnection()
            conn.connectTimeout = 15000
            conn.readTimeout = 45000
            conn.getInputStream().use { input ->
                tmp.outputStream().use { out ->
                    val buffer = ByteArray(65536)
                    var total = 0L
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        total += n
                        require(total <= 66338288)
                        digest.update(buffer, 0, n)
                        out.write(buffer, 0, n)
                    }
                }
            }
            val hash = digest.digest().joinToString("") { "%02x".format(it) }
            check(hash == "93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd") {
                "Depth model download was incomplete. Try again."
            }
            check(tmp.renameTo(file))
            return file
        } finally {
            tmp.delete()
        }
    }

    private fun infer(file: File, pixels: IntArray, w: Int, h: Int): FloatArray {
        val input = ByteBuffer.allocateDirect(256 * 256 * 12).order(ByteOrder.nativeOrder())
        for (y in 0..255) for (x in 0..255) {
            val p = pixels[(y * h / 256) * w + x * w / 256]
            input.putFloat((Color.red(p) - 115f) / 58f)
            input.putFloat((Color.green(p) - 115f) / 58f)
            input.putFloat((Color.blue(p) - 115f) / 58f)
        }
        input.rewind()
        val out = ByteBuffer.allocateDirect(256 * 256 * 4).order(ByteOrder.nativeOrder())
        Interpreter(file, Interpreter.Options().setNumThreads(2)).use { it.run(input, out) }
        out.rewind()
        return FloatArray(256 * 256).also { out.asFloatBuffer().get(it) }
    }

    // Fill disoccluded pixels from the nearest available surface of this depth
    // layer. Midground stays transparent over far surfaces; foreground is unfilled.
    private fun layerPng(src: IntArray, classes: IntArray, w: Int, h: Int, level: Int): ByteArray {
        val dst = IntArray(src.size)
        val queue = IntArray(src.size)
        val visited = BooleanArray(src.size)
        var read = 0
        var write = 0
        for (i in src.indices) if (classes[i] == level) {
            dst[i] = src[i]
            visited[i] = true
            queue[write++] = i
        }
        fun fill(i: Int, from: Int) {
            if (!visited[i] && classes[i] > level) {
                visited[i] = true
                dst[i] = dst[from]
                queue[write++] = i
            }
        }
        while (level < 2 && read < write) {
            val i = queue[read++]
            if (i % w != 0) fill(i - 1, i)
            if (i % w != w - 1) fill(i + 1, i)
            if (i >= w) fill(i - w, i)
            if (i + w < src.size) fill(i + w, i)
        }
        val image = Bitmap.createBitmap(dst, w, h, Bitmap.Config.ARGB_8888)
        return try {
            ByteArrayOutputStream().use {
                check(image.compress(Bitmap.CompressFormat.PNG, 100, it))
                it.toByteArray()
            }
        } finally {
            image.recycle()
        }
    }
}
