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
    @Test fun openingSheetMatchesFlutterAtStartMidpointAndEnd() {
        assertEquals(130f, SheetMotion.offset(0.0, 1.0), .001f)
        assertEquals(16.25f, SheetMotion.offset(.5, 1.0), .001f)
        assertEquals(0f, SheetMotion.offset(1.0, 1.0), .001f)
        assertEquals(0f, SheetMotion.offset(0.0, 0.0), .001f)
        // On the second scene, use global time so the opening never replays.
        assertEquals(0f, SheetMotion.offset(3.5, 1.0), .001f)
    }
    @Test fun introTextureAndPngUseTheSameFrameDespiteMicrosecondRounding() {
        assertEquals(1.0 / 30, SheetMotion.sampleTime(.033333, .9, 27), .000001)
        assertEquals(26.0 / 30, SheetMotion.sampleTime(.899999, .9, 27), .000001)
        assertEquals(14.0 / 30, SheetMotion.sampleTime(.499999, .9, 15), .000001)
        assertEquals(1.2, SheetMotion.sampleTime(1.2, .9, 27), .000001)
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
