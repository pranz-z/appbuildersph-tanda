import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// In-app log for debugging without logcat. Kept in memory and appended to a
/// file, so the previous session survives a crash (shown on the log screen).
class AppLog extends ChangeNotifier {
  static const _maxLines = 3000;

  final _lines = <String>[];
  File? _file;
  String previousSession = '';

  Future<void> init() async {
    try {
      final dir = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'logs'),
      );
      await dir.create(recursive: true);
      final cur = File(p.join(dir.path, 'log.txt'));
      final prev = File(p.join(dir.path, 'log_prev.txt'));
      if (cur.existsSync()) {
        previousSession = cur.readAsStringSync();
        cur.renameSync(prev.path);
      }
      _file = cur;
      cur.writeAsStringSync(_lines.map((l) => '$l\n').join());
    } catch (e) {
      _add('E', 'log file unavailable: $e');
    }
  }

  void i(String msg) => _add('I', msg);

  void e(String msg, [Object? error, StackTrace? stack]) {
    final b = StringBuffer(msg);
    if (error != null) b.write('\n  error: $error');
    if (stack != null) b.write('\n  stack:\n$stack');
    _add('E', b.toString());
  }

  void _add(String level, String msg) {
    final line =
        '${DateTime.now().toIso8601String().substring(11, 23)} '
        '$level $msg';
    _lines.add(line);
    if (_lines.length > _maxLines) _lines.removeAt(0);
    debugPrint(line);
    try {
      _file?.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
    notifyListeners();
  }

  String get currentSession => _lines.join('\n');

  String dump() =>
      '=== this session ===\n$currentSession\n\n'
      '=== previous session ===\n'
      '${previousSession.isEmpty ? '(none)' : previousSession}';
}

final appLog = AppLog();
