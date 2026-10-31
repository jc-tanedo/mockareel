package dev.mockareel.mockareel

import org.junit.Assert.*
import org.junit.Test

class StreetviewMotionTest {
    @Test fun arrowsAndTexturesShareProjectionAndLastFrameHold() {
        val config = mapOf<String, Any>("zoom" to .1, "pan" to .04, "turn" to 12.0)
        for (row in listOf(doubleArrayOf(0.0, 63.0, 498.0),
            doubleArrayOf(1.5, 48.716640205694105, 512.1070570159702),
            doubleArrayOf(4.0, 24.473041444226567, 539.6081369823565))) {
            val m = StreetviewMotion.matrix(row[0], 4.0, config)
            val x = (63.0 - 180) / 180
            val y = (320.0 - 498) / 320
            val w = m[6] * x + m[7] * y + m[8]
            assertEquals(row[1], 180 + 180 * (m[0]*x + m[1]*y + m[2]) / w, .0001)
            assertEquals(row[2], 320 - 320 * (m[3]*x + m[4]*y + m[5]) / w, .0001)
        }
        assertArrayEquals(StreetviewMotion.matrix(4.0, 4.0, config),
            StreetviewMotion.matrix(40.0, 4.0, config), 0f)
    }
    @Test fun absentSettingsKeepExistingTemplatesStationary() {
        assertArrayEquals(floatArrayOf(1f,0f,0f,0f,1f,0f,0f,0f,1f),
            StreetviewMotion.matrix(2.0, 4.0, emptyMap()), 0f)
    }
}
