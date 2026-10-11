package ru.afanasev.ms_app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: local_auth (fingerprint unlock) works only with a
// FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // «Личный сейф»: no screenshots and a blank recent-apps thumbnail
        // while it is open (lib/core/security/secure_screen.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ms/secure_screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "set") {
                    val on = call.arguments as? Boolean ?: false
                    runOnUiThread {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
