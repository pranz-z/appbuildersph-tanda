import 'package:flutter/services.dart';

const _channel = MethodChannel('ph.tanda.app/storage');

/// Free bytes on the filesystem holding [path] (Android StatFs), or null if
/// unknown. A write failure (ENOSPC) is still caught during download.
Future<int?> freeBytesAt(String path) async {
  try {
    return await _channel.invokeMethod<int>('freeBytes', {'path': path});
  } catch (_) {
    return null;
  }
}
