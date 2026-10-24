package com.elmahdi.waraqatak

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "stableIdHash") {
                    result.success(stableIdHash())
                } else {
                    result.notImplemented()
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

    private companion object {
        const val DEVICE_CHANNEL = "com.elmahdi.waraqatak/device"
        const val BROKEN_ANDROID_ID = "9774d56d682e549c"
    }
}
