package dev.mockareel.mockareel

import org.junit.Assert.*
import org.junit.Test

class StreetviewMotionTest {
    @Test fun arrowsAndTexturesShareProjectionAndLastFrameHold() {
        val config = mapOf<String, Any>("zoom" to .1, "pan" to .04, "turn" to 12.0)
        for (row in listOf(doubleArrayOf(0.0, 52.5287801354672, 518.2630981924528),
            doubleArrayOf(1.5, 46.826553827680854, 514.6571419475807),
            doubleArrayOf(4.0, 24.492614555768, 539.4973086337196))) {
            val m = StreetviewMotion.matrix(row[0], 4.0, config)
            val x = (63.0 - 180) / 180
            val y = (320.0 - 498) / 320
            val w = m[6] * x + m[7] * y + m[8]
            assertEquals(row[1], 180 + 180 * (m[0]*x + m[1]*y + m[2]) / w, .0001)
            assertEquals(row[2], 320 - 320 * (m[3]*x + m[4]*y + m[5]) / w, .0001)
        }
        val revConfig = mapOf<String, Any>("zoom" to .1, "pan" to .04, "turn" to 12.0, "turnReverse" to true)
        val mRev = StreetviewMotion.matrix(0.0, 4.0, revConfig)
        val rx = (63.0 - 180) / 180
        val ry = (320.0 - 498) / 320
        val rw = mRev[6] * rx + mRev[7] * ry + mRev[8]
        assertEquals(60.92513748077257, 180 + 180 * (mRev[0]*rx + mRev[1]*ry + mRev[2]) / rw, .0001)
        assertEquals(505.203775291328, 320 - 320 * (mRev[3]*rx + mRev[4]*ry + mRev[5]) / rw, .0001)
        assertArrayEquals(StreetviewMotion.matrix(4.0, 4.0, config),
            StreetviewMotion.matrix(40.0, 4.0, config), 0f)
    }
    @Test fun absentSettingsKeepExistingTemplatesStationary() {
        assertArrayEquals(floatArrayOf(1f,0f,0f,0f,1f,0f,0f,0f,1f),
            StreetviewMotion.matrix(2.0, 4.0, emptyMap()), 0f)
    }
}
