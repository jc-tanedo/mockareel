package dev.mockareel.mockareel

import android.media.MediaMetadataRetriever
import androidx.exifinterface.media.ExifInterface

internal object MediaCoordinates {
    // Android exposes MP4/QuickTime location as signed ISO 6709 decimal degrees.
    private val iso6709 = Regex("""([+-]\d{2}(?:\.\d+)?)([+-]\d{3}(?:\.\d+)?)(?:[+-]\d+(?:\.\d+)?)?/?""")

    fun parseVideo(tag: String?): List<Double>? {
        val match = iso6709.matchEntire(tag?.trim() ?: return null) ?: return null
        return valid(match.groupValues[1].toDouble(), match.groupValues[2].toDouble())
    }

    private fun valid(lat: Double, lon: Double): List<Double>? =
        if (lat in -90.0..90.0 && lon in -180.0..180.0) listOf(lat, lon) else null

    fun read(path: String, video: Boolean): List<Double>? {
        if (!video) {
            val gps = ExifInterface(path).latLong ?: return null
            return valid(gps[0], gps[1])
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            parseVideo(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION))
        } finally {
            retriever.release()
        }
    }
}
