package dev.mockareel.mockareel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MediaCoordinatesTest {
    @Test fun iso6709TagPreservesSignedLatitudeAndLongitude() {
        assertEquals(listOf(-33.85, 151.21), MediaCoordinates.parseVideo("-33.8500+151.2100+006.0/"))
        assertEquals(listOf(0.0, -74.1), MediaCoordinates.parseVideo("+00.0-074.1/"))
        assertNull(MediaCoordinates.parseVideo("+91.1+139.1/"))
        assertNull(MediaCoordinates.parseVideo("+35.6+181.2/"))
        assertNull(MediaCoordinates.parseVideo("invalid"))
        assertNull(MediaCoordinates.parseVideo(null))
    }
}
