package dev.mockareel.mockareel

import org.junit.Assert.*
import org.junit.Test

class ScrollMotionTest {
    @Test fun incomingCardStartsAfterPreviousCardAndSnapsToTheGalleryLeft() {
        // Reference contract: two half-width cards, 1080p export, 8 logical-pixel gap.
        assertEquals(516f, ScrollMotion.entryOffset(492f, 24f, 0.0, .35), .001f)
        assertEquals(64.5f, ScrollMotion.entryOffset(492f, 24f, .175, .35), .001f)
        assertEquals(0f, ScrollMotion.entryOffset(492f, 24f, .35, .35), .001f)
        assertEquals(0f, ScrollMotion.entryOffset(492f, 24f, 1.56, .35), .001f)
    }
    @Test fun trimmedOrConcatenatedInputTimestampsDoNotSkipTheEntryAnimation() {
        val clock = ClipClock()
        assertEquals(0.0, clock.elapsed(9_000_000), .000001)
        clock.begin(9_000_000)
        clock.begin(9_100_000)
        assertEquals(.1, clock.elapsed(9_100_000), .000001)
        assertEquals(0.0, clock.elapsed(8_000_000), .000001)
    }
}
