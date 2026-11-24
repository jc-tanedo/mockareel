package dev.mockareel.mockareel

import android.content.Context
import android.location.Geocoder
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.Locale

/** Runs on a Flutter background task queue, including on older Android versions. */
internal class PlaceGeocoder(private val context: Context) : MethodChannel.MethodCallHandler {
    @Suppress("DEPRECATION")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "findPlace") {
            result.notImplemented()
            return
        }
        val query = call.arguments as? String
        if (query.isNullOrBlank() || !Geocoder.isPresent()) {
            result.success(emptyList<Any>())
            return
        }
        try {
            val addresses = Geocoder(context, Locale.ENGLISH).getFromLocationName(query, 5).orEmpty()
            result.success(addresses.filter { it.hasLatitude() && it.hasLongitude() }.map {
                mapOf(
                    "name" to it.featureName, "latitude" to it.latitude, "longitude" to it.longitude,
                    "localities" to listOfNotNull(it.locality, it.subLocality, it.postalCode, it.thoroughfare, it.subAdminArea),
                )
            })
        } catch (_: IOException) {
            result.success(emptyList<Any>())
        }
    }
}
