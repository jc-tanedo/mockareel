package dev.mockareel.mockareel

import kotlin.math.*

/** Counterpart of model/streetview_motion.dart. UI frames and textures sample
 * the same 30 fps clock, including holds at the final encoded frame. */
internal object StreetviewMotion {
    fun matrix(elapsed: Double, duration: Double, config: Map<String, Any>): FloatArray {
        fun number(key: String, low: Double, high: Double): Double {
            val value = (config[key] as? Number)?.toDouble() ?: 0.0
            return if (value.isFinite()) value.coerceIn(low, high) else 0.0
        }
        val frame = min(max(0, (elapsed * 30).roundToInt()), max(0, ceil(duration * 30).toInt() - 1)) / 30.0
        val t = (frame / max(.001, duration)).coerceIn(0.0, 1.0)
        val yaw = number("turn", -15.0, 15.0) * PI / 180 * t
        val offset = -number("pan", -.08, .08) * 360 * t
        val k = .0014 * 180 * sin(yaw)
        val cover = (1 + abs(k)) / abs(cos(yaw))
        val scale = (1 + number("zoom", 0.0, .2) * t) * cover * (1 + 2 * abs(offset) / 360)
        val tx = 2 * offset / 360
        return floatArrayOf((scale * cos(yaw) - tx * k).toFloat(), 0f, tx.toFloat(),
            0f, scale.toFloat(), 0f, -k.toFloat(), 0f, 1f)
    }
}
