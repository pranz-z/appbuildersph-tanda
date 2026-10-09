package ph.tanda.app

import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Free space check before model downloads.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ph.tanda.app/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "freeBytes") {
                    val path = call.argument<String>("path") ?: filesDir.path
                    try {
                        result.success(StatFs(path).availableBytes)
                    } catch (e: IllegalArgumentException) {
                        result.error("statfs", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
