package dev.mockareel.mockareel

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.max

class ScrollMotionTest {
    @Test fun incomingCardUsesM3DefaultSpatialAndSnapsToGalleryLeft() {
        // Reference contract: two half-width cards, 1080p export, 8 logical-pixel gap.
        assertEquals(516f, ScrollMotion.entryOffset(492f, 24f, 0.0, .35), .001f)
        assertEquals(-7.2019f, ScrollMotion.entryOffset(492f, 24f, .175, .35), .001f)
        assertEquals(0f, ScrollMotion.entryOffset(492f, 24f, .35, .35), .001f)
        assertEquals(0f, ScrollMotion.entryOffset(492f, 24f, 1.56, .35), .001f)
    }

    @Test fun openingSheetMatchesFlutterSlowSpatialAtStartMidpointAndEnd() {
        assertEquals(130f, SheetMotion.offset(0.0, 1.0), .001f)
        assertEquals(-1.4072f, SheetMotion.offset(.5, 1.0), .001f)
        assertEquals(0f, SheetMotion.offset(1.0, 1.0), .001f)
        assertEquals(0f, SheetMotion.offset(0.0, 0.0), .001f)
        // On the second scene, use global time so the opening never replays.
        assertEquals(0f, SheetMotion.offset(3.5, 1.0), .001f)
    }

    @Test fun introTextureAndPngUseSame60FpsFrameDespiteMicrosecondRounding() {
        assertEquals(1.0 / 60, SheetMotion.sampleTime(.016667, .65, 39), .000001)
        assertEquals(38.0 / 60, SheetMotion.sampleTime(.649999, .65, 39), .000001)
        assertEquals(14.0 / 60, SheetMotion.sampleTime(.249999, .65, 15), .000001)
        assertEquals(1.2, SheetMotion.sampleTime(1.2, .65, 39), .000001)
    }

    @Test fun trimmedOrConcatenatedInputTimestampsDoNotSkipTheEntryAnimation() {
        val clock = ClipClock()
        assertEquals(0.0, clock.elapsed(9_000_000), .000001)
        clock.begin(9_000_000)
        clock.begin(9_100_000)
        assertEquals(.1, clock.elapsed(9_100_000), .000001)
        assertEquals(0.0, clock.elapsed(8_000_000), .000001)
    }

    @Test fun feedSwipeSearchEnterAndUiShare60FpsFramesAndSettle() {
        assertEquals(640f, FeedMotion.entry(0.0, .4), .001f)
        assertEquals(-8.9326f, FeedMotion.entry(.2, .4), .001f)
        assertEquals(0f, FeedMotion.entry(.4, .4), .001f)
        assertEquals(0f, FeedMotion.entry(0.0, 0.0), .001f)
        assertEquals(FeedMotion.entry(28.0 / 60, .48), FeedMotion.entry(.479, .48), .001f)
        assertEquals(0.94f, FeedMotion.searchEnterScale(0.0, .28), .001f)
        assertEquals(1.0f, FeedMotion.searchEnterScale(.28, .28), .001f)
        assertEquals(1, FeedMotion.frame(.016667, 24))
        assertEquals(23, FeedMotion.frame(.399999, 24))
        assertEquals(-1, FeedMotion.frame(0.0, 0))
        assertEquals(FeedMotion.entry(1.0 / 60, .4), FeedMotion.entry(.016667, .4), .001f)
    }

    @Test fun feedWindowTransformMatchesM3LaunchAndCloseRects() {
        val openCfg = mapOf<String, Any>(
            "opening" to true,
            "hold" to 0.5,
            "iconLeft" to 20.0,
            "iconTop" to 100.0,
            "iconSize" to 56.0,
        )
        val openStart = FeedMotion.windowTransform(0.0, 1.05, openCfg)
        assertEquals(56f / 360f, openStart[0], .0001f)
        assertEquals(2f * (20f + 28f) / 360f - 1f, openStart[1], .0001f)
        assertEquals(1f - 2f * (100f + 28f) / 640f, openStart[2], .0001f)

        val openMid = FeedMotion.windowTransform(0.75, 1.05, openCfg)
        val qMid = M3Motion.quantize(0.75, 1.05)
        val pMid = M3Motion.slowSpatial.eval(((qMid - 0.5) / 0.55).coerceIn(0.0, 1.0))
        val midW = 56.0 + (360.0 - 56.0) * pMid
        val midH = 56.0 + (640.0 - 56.0) * pMid
        assertEquals(max(midW / 360.0, midH / 640.0).toFloat(), openMid[0], .0001f)

        val openEnd = FeedMotion.windowTransform(1.05, 1.05, openCfg)
        assertArrayEquals(floatArrayOf(1f, 0f, 0f), openEnd, .0001f)

        val closeCfg = mapOf<String, Any>(
            "opening" to false,
            "hold" to 0.5,
            "iconLeft" to 20.0,
            "iconTop" to 100.0,
            "iconSize" to 56.0,
        )
        assertArrayEquals(floatArrayOf(1f, 0f, 0f), FeedMotion.windowTransform(0.0, 0.95, closeCfg), .0001f)
        assertArrayEquals(openStart, FeedMotion.windowTransform(0.45, 0.95, closeCfg), .0001f)
    }
}
