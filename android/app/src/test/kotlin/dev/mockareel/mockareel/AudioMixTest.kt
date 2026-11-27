package dev.mockareel.mockareel

import org.junit.Assert.*
import org.junit.Test

class AudioMixTest {
    @Test fun fadeOutUsesCosineCurveAtBoundaryMidpointAndEnd() {
        assertEquals(.8f, AudioMix.fadeOutGain(2000.0, 10000.0, .8f, 2000.0), .0001f)
        assertEquals(.4f, AudioMix.fadeOutGain(9000.0, 10000.0, .8f, 2000.0), .0001f)
        assertEquals(0f, AudioMix.fadeOutGain(10000.0, 10000.0, .8f, 2000.0), .0001f)
        assertEquals(.5f, AudioMix.fadeOutGain(1000.0, 2000.0, 1.0f, 5000.0), .0001f)
        assertTrue(AudioMix.isUnity(1.0f, 0.0))
        assertFalse(AudioMix.isUnity(1.0f, 1500.0))
        assertFalse(AudioMix.isUnity(.7f, 0.0))
    }

    @Test fun planMusicSegmentsUnrollsLoopedAndSingleTrackRuns() {
        val looped = AudioMix.planMusicSegments(5000L, 1000L, 10000L, true)
        assertEquals(
            listOf(
                MusicSegment(1000L, 5000L, 0L),
                MusicSegment(1000L, 5000L, 4000L),
                MusicSegment(1000L, 3000L, 8000L),
            ),
            looped,
        )
        val unlooped = AudioMix.planMusicSegments(5000L, 1000L, 10000L, false)
        assertEquals(listOf(MusicSegment(1000L, 5000L, 0L)), unlooped)
        assertTrue(AudioMix.planMusicSegments(0L, 0L, 5000L, true).isEmpty())
    }
}
