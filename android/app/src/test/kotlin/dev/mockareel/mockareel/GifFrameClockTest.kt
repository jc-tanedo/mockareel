package dev.mockareel.mockareel

import org.junit.Assert.assertEquals
import org.junit.Test

class GifFrameClockTest {
    @Test fun trimmedGifFramesChangeOnTheSameThirtyFpsClockAsPreview() {
        val times = listOf(0L, 66_667L, 166_667L)
        assertEquals(0, GifFrameClock.index(times, 0))
        assertEquals(0, GifFrameClock.index(times, 33_333))
        assertEquals(1, GifFrameClock.index(times, 66_666))
        assertEquals(1, GifFrameClock.index(times, 133_333))
        assertEquals(2, GifFrameClock.index(times, 166_666))
        assertEquals(2, GifFrameClock.index(times, 999_999))
    }
}
