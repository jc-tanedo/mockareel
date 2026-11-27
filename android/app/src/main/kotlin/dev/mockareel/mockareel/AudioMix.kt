package dev.mockareel.mockareel

import kotlin.math.*

internal data class MusicSegment(val startMs: Long, val endMs: Long, val timelineOffsetMs: Long)

/** Counterpart of model/audio_mix.dart for clip gain and music end fade-out. */
internal object AudioMix {
    fun fadeOutGain(timelineMs: Double, totalAudioMs: Double, volume: Float, fadeOutMs: Double): Float {
        val vol = if (volume.isFinite()) volume.coerceIn(0f, 1f) else 0f
        val fade = if (fadeOutMs.isFinite()) min(fadeOutMs.coerceIn(0.0, 5000.0), max(0.0, totalAudioMs)) else 0.0
        if (fade <= 0.0 || totalAudioMs <= 0.0 || timelineMs <= totalAudioMs - fade) return vol
        val remaining = ((totalAudioMs - timelineMs) / fade).coerceIn(0.0, 1.0)
        return (vol * 0.5 * (1.0 - cos(remaining * PI))).toFloat()
    }

    fun isUnity(volume: Float, fadeOutMs: Double): Boolean =
        (!fadeOutMs.isFinite() || fadeOutMs <= 0.0) && volume.isFinite() && volume >= 0.999f

    fun planMusicSegments(sourceMs: Long, trimStartMs: Long, reelMs: Long, loop: Boolean): List<MusicSegment> {
        if (sourceMs <= 0L || reelMs <= 0L) return emptyList()
        val start = trimStartMs.coerceIn(0L, max(0L, sourceMs - 100L))
        val available = sourceMs - start
        if (available <= 0L) return emptyList()
        if (!loop || available >= reelMs) {
            return listOf(MusicSegment(start, min(sourceMs, start + reelMs), 0L))
        }
        val segments = mutableListOf<MusicSegment>()
        var offset = 0L
        while (offset < reelMs) {
            val length = min(available, reelMs - offset)
            segments.add(MusicSegment(start, start + length, offset))
            offset += length
        }
        return segments
    }
}
