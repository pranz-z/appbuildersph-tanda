import 'dart:io';

/// Resident memory of this process, for the debug log. Reads VmRSS/VmHWM from
/// /proc/self/status (Linux/Android); falls back to ProcessInfo.currentRss.
String residentMemorySummary() {
  String mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  try {
    final status = File('/proc/self/status').readAsLinesSync();
    String? field(String name) => status
        .where((l) => l.startsWith('$name:'))
        .map((l) => l.substring(name.length + 1).trim())
        .firstOrNull;
    final rss = field('VmRSS');
    final hwm = field('VmHWM');
    if (rss != null) return 'VmRSS=$rss, VmHWM(peak)=${hwm ?? '?'}';
  } catch (_) {}
  try {
    return 'currentRss=${mb(ProcessInfo.currentRss)}, maxRss=${mb(ProcessInfo.maxRss)}';
  } catch (e) {
    return 'unavailable ($e)';
  }
}
