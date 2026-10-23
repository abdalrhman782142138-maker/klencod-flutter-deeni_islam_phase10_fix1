package com.deeniislam.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val locationRequestCode = 7001
    private var pendingLocation: MethodChannel.Result? = null

    private var compassManager: SensorManager? = null
    private var compassListener: SensorEventListener? = null
    private val rotMatrix = FloatArray(9)
    private var gravityValues: FloatArray? = null
    private var magneticValues: FloatArray? = null
    private var magAccuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
    private var lastEmit = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.deeniislam.app/share").setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
                val text = call.arguments as? String
                if (text.isNullOrEmpty()) {
                    result.error("bad_args", "empty text", null)
                } else {
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(send, null))
                    result.success(true)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(messenger, "com.deeniislam.app/compass").setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(compassAvailable())
                "declination" -> {
                    val lat = call.argument<Double>("lat")
                    val lon = call.argument<Double>("lon")
                    if (lat == null || lon == null) {
                        result.error("bad_args", "lat/lon required", null)
                    } else {
                        val field = GeomagneticField(lat.toFloat(), lon.toFloat(), 0f, System.currentTimeMillis())
                        result.success(field.declination.toDouble())
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "com.deeniislam.app/compass_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    startCompass(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopCompass()
                }
            }
        )

        MethodChannel(messenger, "com.deeniislam.app/location").setMethodCallHandler { call, result ->
            if (call.method == "getLocation") {
                handleGetLocation(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun hasCoarsePermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun handleGetLocation(result: MethodChannel.Result) {
        if (pendingLocation != null) {
            result.error("busy", "location request in progress", null)
            return
        }
        if (hasCoarsePermission()) {
            fetchLocation(result)
        } else {
            pendingLocation = result
            requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), locationRequestCode)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == locationRequestCode) {
            val r = pendingLocation
            pendingLocation = null
            if (r != null) {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    fetchLocation(r)
                } else {
                    r.error("permission_denied", "denied", null)
                }
            }
        }
    }

    private fun locationMap(l: Location): Map<String, Any> {
        return mapOf(
            "lat" to l.latitude,
            "lon" to l.longitude,
            "accuracy" to l.accuracy.toDouble()
        )
    }

    /** آخر موقع معروف (شبكة/سلبي) وإلا طلب تحديث واحد بمهلة. لا يُستخدم GPS لأن الإذن تقريبي فقط. */
    private fun fetchLocation(result: MethodChannel.Result) {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            var best: Location? = null
            for (provider in listOf(LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)) {
                val l = lm.getLastKnownLocation(provider)
                if (l != null && (best == null || l.time > best.time)) best = l
            }
            if (best != null) {
                result.success(locationMap(best))
                return
            }
            if (!lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                result.error("unavailable", "network location disabled", null)
                return
            }
            requestSingleFix(lm, result)
        } catch (e: SecurityException) {
            result.error("permission_denied", "denied", null)
        } catch (e: Exception) {
            result.error("other", e.message, null)
        }
    }

    private fun requestSingleFix(lm: LocationManager, result: MethodChannel.Result) {
        val handler = Handler(Looper.getMainLooper())
        var done = false
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (done) return
                done = true
                handler.removeCallbacksAndMessages(null)
                lm.removeUpdates(this)
                result.success(locationMap(location))
            }

            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

            override fun onProviderEnabled(provider: String) {}

            override fun onProviderDisabled(provider: String) {}
        }
        try {
            @Suppress("DEPRECATION")
            lm.requestSingleUpdate(LocationManager.NETWORK_PROVIDER, listener, Looper.getMainLooper())
        } catch (e: SecurityException) {
            result.error("permission_denied", "denied", null)
            return
        }
        handler.postDelayed({
            if (!done) {
                done = true
                lm.removeUpdates(listener)
                result.error("timeout", "no location fix", null)
            }
        }, 15000)
    }

    // ------------------------------------------------------------ البوصلة

    private fun compassAvailable(): Boolean {
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        return sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) != null ||
            (sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null &&
                sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null)
    }

    /** يرسل اتجاه الهاتف المغناطيسي (درجات) ودقة الحساس. لا يختلق قراءة عند غياب الحساس. */
    private fun startCompass(sink: EventChannel.EventSink) {
        stopCompass()
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val rv = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val acc = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val mag = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (rv == null && (acc == null || mag == null)) {
            sink.error("unavailable", "no orientation sensors", null)
            return
        }
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                var ok = false
                var accuracy = event.accuracy
                when (event.sensor.type) {
                    Sensor.TYPE_ROTATION_VECTOR -> {
                        SensorManager.getRotationMatrixFromVector(rotMatrix, event.values)
                        ok = true
                    }
                    Sensor.TYPE_ACCELEROMETER -> gravityValues = event.values.clone()
                    Sensor.TYPE_MAGNETIC_FIELD -> {
                        magneticValues = event.values.clone()
                        magAccuracy = event.accuracy
                    }
                }
                if (rv == null) {
                    val g = gravityValues
                    val m = magneticValues
                    if (g != null && m != null) {
                        ok = SensorManager.getRotationMatrix(rotMatrix, null, g, m)
                        accuracy = magAccuracy
                    }
                }
                if (!ok) return
                val now = System.currentTimeMillis()
                if (now - lastEmit < 50) return
                lastEmit = now

                // الهاتف شبه أفقي: اتجاه أعلى الهاتف (محور Y)؛ وإلا اتجاه الكاميرا الخلفية (-Z).
                val r = rotMatrix
                val rad = if (Math.abs(r[8]) >= 0.7f) {
                    Math.atan2(r[1].toDouble(), r[4].toDouble())
                } else {
                    Math.atan2(-r[2].toDouble(), -r[5].toDouble())
                }
                val deg = (Math.toDegrees(rad) + 360.0) % 360.0
                sink.success(mapOf("magnetic" to deg, "accuracy" to accuracy))
            }

            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
        }
        compassManager = sm
        compassListener = listener
        if (rv != null) {
            sm.registerListener(listener, rv, SensorManager.SENSOR_DELAY_UI)
        } else {
            sm.registerListener(listener, acc, SensorManager.SENSOR_DELAY_UI)
            sm.registerListener(listener, mag, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun stopCompass() {
        val l = compassListener
        if (l != null) compassManager?.unregisterListener(l)
        compassListener = null
        compassManager = null
        gravityValues = null
        magneticValues = null
    }

    override fun onDestroy() {
        stopCompass()
        super.onDestroy()
    }
}
