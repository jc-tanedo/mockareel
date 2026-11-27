package dev.mockareel.mockareel

import org.junit.Assert.*
import org.junit.Test

class M3MotionTest {
    @Test fun springsHitEndpointsAndMatchDartGoldens() {
        val all = listOf(
            M3Motion.fastSpatial,
            M3Motion.defaultSpatial,
            M3Motion.slowSpatial,
            M3Motion.fastEffects,
            M3Motion.defaultEffects,
            M3Motion.slowEffects
        )
        for (sp in all) {
            assertEquals(0.0, sp.eval(-1.0), 0.0)
            assertEquals(0.0, sp.eval(0.0), 0.0)
            assertEquals(1.0, sp.eval(1.0), 0.0)
            assertEquals(1.0, sp.eval(2.0), 0.0)
            assertEquals(0.0, sp.eval(Double.NaN), 0.0)
        }

        for (ef in listOf(M3Motion.fastEffects, M3Motion.defaultEffects, M3Motion.slowEffects)) {
            var prev = 0.0
            for (i in 0..200) {
                val v = ef.eval(i / 200.0)
                assertTrue(v in prev..1.0)
                prev = v
            }
        }

        assertEquals(1.0631625334491193, M3Motion.fastSpatial.eval(0.5), 1e-10)
        assertEquals(1.0139572459460215, M3Motion.defaultSpatial.eval(0.5), 1e-10)
        assertEquals(1.0108248967325388, M3Motion.slowSpatial.eval(0.5), 1e-10)
        assertEquals(0.6724891396950416, M3Motion.fastEffects.eval(0.25), 1e-10)
        assertEquals(0.7130586057331392, M3Motion.defaultEffects.eval(0.25), 1e-10)
        assertEquals(0.7078946343291297, M3Motion.slowEffects.eval(0.25), 1e-10)
    }

    @Test fun streetviewExpandTransformMatchesFlutterGeometry() {
        val cfg = mapOf<String, Any>(
            "duration" to 0.42,
            "left" to 12.0,
            "top" to 484.0,
            "width" to 82.0,
            "height" to 54.0
        )
        val start = StreetviewMotion.expandTransform(0.0, 0.42, cfg)
        assertEquals(0.22777778f, start[0], 1e-5f)
        assertEquals(-0.70555556f, start[1], 1e-5f)
        assertEquals(-0.596875f, start[2], 1e-5f)

        val mid = StreetviewMotion.expandTransform(0.2, 0.42, cfg)
        assertEquals(1.0058854f, mid[0], 1e-5f)
        assertEquals(0.004535155f, mid[1], 1e-5f)
        assertEquals(0.0038365806f, mid[2], 1e-5f)

        val end = StreetviewMotion.expandTransform(0.42, 0.42, cfg)
        assertArrayEquals(floatArrayOf(1f, 0f, 0f), end, 1e-6f)
    }
}
