package com.elmahdi.waraqatak

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "stableIdHash" -> result.success(stableIdHash())
                    "getDeviceModel" -> result.success(getDeviceModel())
                    "getDeviceInfo" -> result.success(getDeviceInfo())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * SHA-256 of the app-scoped Android ID, salted with the package name.
     * The raw Android ID never leaves the device. Returns null when the ID is
     * unavailable or the known-broken emulator value.
     */
    private fun stableIdHash(): String? {
        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        if (androidId.isNullOrBlank() || androidId == BROKEN_ANDROID_ID) return null
        val trimmed = androidId.trim()
        if (trimmed.length < 8) return null
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$packageName:$trimmed".toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    /**
     * Informational hardware device name (e.g. "Samsung Galaxy A16").
     * Treated strictly as non-security display metadata.
     */
    private fun getDeviceModel(): String {
        val manufacturer = Build.MANUFACTURER?.trim()?.replaceFirstChar {
            if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
        } ?: ""
        val model = Build.MODEL?.trim() ?: ""

        return when {
            model.isEmpty() && manufacturer.isEmpty() -> "Android Device"
            model.isEmpty() -> manufacturer
            manufacturer.isEmpty() -> model
            model.startsWith(manufacturer, ignoreCase = true) -> {
                model.replaceFirstChar {
                    if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
                }
            }
            else -> "$manufacturer $model".trim()
        }
    }

    private fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "model" to (Build.MODEL ?: ""),
            "formattedName" to getDeviceModel()
        )
    }

    private companion object {
        const val DEVICE_CHANNEL = "com.elmahdi.waraqatak/device"
        const val BROKEN_ANDROID_ID = "9774d56d682e549c"
    }
}
