package ph.tanda.app

import android.os.StatFs
import android.net.TrafficStats
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SessionTraffic.beginIfNeeded()
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ph.tanda.app/locality")
            .setMethodCallHandler { call, result ->
                if (call.method == "sessionTxBytes") {
                    result.success(SessionTraffic.bytesSentThisSession())
                } else {
                    result.notImplemented()
                }
            }
    }
}

private object SessionTraffic {
    private var baselineTxBytes: Long? = null

    fun beginIfNeeded() {
        if (baselineTxBytes == null) {
            baselineTxBytes = TrafficStats.getUidTxBytes(Process.myUid())
        }
    }

    fun bytesSentThisSession(): Long? {
        val baseline = baselineTxBytes ?: return null
        val current = TrafficStats.getUidTxBytes(Process.myUid())
        return if (baseline < 0 || current < baseline) null else current - baseline
    }
}
