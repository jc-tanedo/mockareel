package dev.mockareel.mockareel

import kotlin.math.*

/** Counterpart of model/streetview_motion.dart. UI frames and textures sample
 * the same 60 fps clock, including eased camera motion and container expand. */
internal object StreetviewMotion {
    fun matrix(elapsed: Double, duration: Double, config: Map<String, Any>): FloatArray {
        fun number(key: String, low: Double, high: Double): Double {
            val value = (config[key] as? Number)?.toDouble() ?: 0.0
            return if (value.isFinite()) value.coerceIn(low, high) else 0.0
        }
        val frame = M3Motion.quantize(elapsed, duration)
        val t = M3Motion.cameraEase((frame / max(.001, duration)).coerceIn(0.0, 1.0))
        val turn = number("turn", -15.0, 15.0)
        val turnReverse = config["turnReverse"] == true
        val factor = if (turnReverse) (1.0 - 2.0 * t) else (2.0 * t - 1.0)
        val yaw = if (turn != 0.0) turn * PI / 180 * factor else 0.0
        val offset = -number("pan", -.08, .08) * 360 * t
        val k = .0014 * 180 * sin(yaw)
        val cover = (1 + abs(k)) / abs(cos(yaw))
        val scale = (1 + number("zoom", 0.0, .2) * t) * cover * (1 + 2 * abs(offset) / 360)
        val tx = 2 * offset / 360
        return floatArrayOf(
            (scale * cos(yaw) - tx * k).toFloat(), 0f, tx.toFloat(),
            0f, scale.toFloat(), 0f, -k.toFloat(), 0f, 1f
        )
    }

    /** Returns [coverScale, tx, ty] in normalized GL coordinates for M3 Container Transform expand. */
    fun expandTransform(elapsed: Double, duration: Double, config: Map<String, Any>): FloatArray {
        if (duration <= 0.0 || elapsed >= duration) return floatArrayOf(1f, 0f, 0f)
        fun num(key: String, default: Double): Double {
            val v = (config[key] as? Number)?.toDouble() ?: default
            return if (v.isFinite()) v else default
        }
        val q = M3Motion.quantize(elapsed, duration)
        val p = M3Motion.slowSpatial.at(q, duration)
        val left = M3Motion.lerp(num("left", 12.0), 0.0, p)
        val top = M3Motion.lerp(num("top", 484.0), 0.0, p)
        val width = max(1.0, M3Motion.lerp(num("width", 82.0), 360.0, p))
        val height = max(1.0, M3Motion.lerp(num("height", 54.0), 640.0, p))
        val coverScale = max(width / 360.0, height / 640.0).toFloat()
        val tx = (2.0 * (left + width / 2.0) / 360.0 - 1.0).toFloat()
        val ty = (1.0 - 2.0 * (top + height / 2.0) / 640.0).toFloat()
        return floatArrayOf(coverScale, tx, ty)
    }
}
