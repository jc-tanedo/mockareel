package dev.mockareel.mockareel

import kotlin.math.*

/**
 * Analytical Material 3 Expressive spring physics and 60 fps export clock.
 * Counterpart of Dart `lib/model/m3_motion.dart`.
 */
internal data class M3Spring(
    val damping: Double,
    val stiffness: Double,
    val naturalSeconds: Double,
) {
    fun eval(progress: Double): Double {
        if (!progress.isFinite() || progress <= 0.0) return 0.0
        if (progress >= 1.0) return 1.0
        val t = progress * naturalSeconds
        val w0 = sqrt(stiffness)
        if (damping >= 1.0) {
            fun crit(s: Double) = 1.0 - (1.0 + w0 * s) * exp(-w0 * s)
            return (crit(t) / crit(naturalSeconds)).coerceIn(0.0, 1.0)
        }
        val k = sqrt(1.0 - damping * damping)
        val wd = w0 * k
        val raw = 1.0 - exp(-damping * w0 * t) * (cos(wd * t) + (damping / k) * sin(wd * t))
        if (progress <= 0.90) return raw
        val s = (progress - 0.90) / 0.10
        val blend = s * s * (3.0 - 2.0 * s)
        return raw * (1.0 - blend) + blend
    }

    fun at(elapsed: Double, duration: Double): Double =
        if (duration <= 0.0) 1.0 else eval((elapsed / duration).coerceIn(0.0, 1.0))
}

internal object M3Motion {
    const val EXPORT_FPS = 60

    val fastSpatial = M3Spring(0.6, 800.0, 0.35)
    val defaultSpatial = M3Spring(0.8, 380.0, 0.50)
    val slowSpatial = M3Spring(0.8, 200.0, 0.65)

    val fastEffects = M3Spring(1.0, 3800.0, 0.15)
    val defaultEffects = M3Spring(1.0, 1600.0, 0.25)
    val slowEffects = M3Spring(1.0, 800.0, 0.35)

    fun cameraEase(t: Double): Double {
        val u = if (t.isFinite()) t.coerceIn(0.0, 1.0) else 0.0
        return u * u * (3.0 - 2.0 * u)
    }

    fun quantize(elapsed: Double, duration: Double): Double =
        min(
            max(0, (elapsed * EXPORT_FPS).roundToInt()),
            max(0, ceil(duration * EXPORT_FPS).toInt() - 1)
        ) / EXPORT_FPS.toDouble()

    fun lerp(a: Double, b: Double, t: Double): Double = a + (b - a) * t

    fun fadeThroughOut(u: Double): Double =
        (1.0 - fastEffects.eval((u / 0.35).coerceIn(0.0, 1.0))).coerceIn(0.0, 1.0)

    fun fadeThroughIn(u: Double): Double =
        defaultEffects.eval(((u - 0.35) / 0.65).coerceIn(0.0, 1.0)).coerceIn(0.0, 1.0)
}
