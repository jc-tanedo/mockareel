package dev.mockareel.mockareel

import org.junit.Assert.*
import org.junit.Test

class MediaEditSpecTest {
    @Test fun pincushionBendsOppositeToFisheyeAndTimedMediaHasNoBlur() {
        val data = mapOf<String, Any>("fisheye" to true, "lens" to "pincushion",
            "strength" to .7, "spots" to listOf(mapOf("x" to .2, "y" to .3)))
        val photo = MediaEditSpec.from(data)
        assertEquals(-.7f, photo.strength, .00001f)
        assertEquals(1, photo.spots.size)
        val video = MediaEditSpec.from(data, video = true)
        assertEquals(photo.strength, video.strength, 0f)
        assertTrue(video.spots.isEmpty())
    }
    @Test fun olderProjectsHaveNoLensDistortionOrBlur() {
        val spec = MediaEditSpec.from(emptyMap())
        assertEquals(0f, spec.strength, 0f)
        assertTrue(spec.spots.isEmpty())
    }
    @Test fun sourceCoordinatesAreIndependentOfTemplateCropAndAreBounded() {
        val spec = MediaEditSpec.from(mapOf("fisheye" to true, "strength" to .65,
            "spots" to listOf(mapOf("x" to -1, "y" to 2, "radius" to 1))))
        assertEquals(.65f, spec.strength, .00001f)
        assertEquals(SpotSpec(0f, 1f, .3f), spec.spots.single())
    }
    @Test fun invalidCoordinatesCannotReachShaderUniforms() {
        assertThrows(IllegalArgumentException::class.java) {
            MediaEditSpec.from(mapOf("spots" to listOf(mapOf("x" to Double.NaN))))
        }
        assertThrows(IllegalArgumentException::class.java) {
            MediaEditSpec.from(mapOf("spots" to List(9) { emptyMap<String, Any>() }))
        }
    }
}
