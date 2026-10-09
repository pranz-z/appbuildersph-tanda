import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline, unavailable }

NetworkStatus networkStatusFor(List<ConnectivityResult> results) {
  if (results.isEmpty) return NetworkStatus.unavailable;
  return results.any((result) => result != ConnectivityResult.none)
      ? NetworkStatus.online
      : NetworkStatus.offline;
}

final networkStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  final connectivity = Connectivity();
  yield networkStatusFor(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(networkStatusFor);
});

abstract interface class SessionTrafficCounter {
  Future<int?> readSessionTxBytes();
}

class AndroidUidTrafficCounter implements SessionTrafficCounter {
  static const _channel = MethodChannel('ph.tanda.app/locality');

  @override
  Future<int?> readSessionTxBytes() async {
    try {
      final bytes = await _channel.invokeMethod<int>('sessionTxBytes');
      return bytes != null && bytes >= 0 ? bytes : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

final sessionTrafficCounterProvider = Provider<SessionTrafficCounter>(
  (ref) => AndroidUidTrafficCounter(),
);

final sessionTrafficBytesProvider = StreamProvider<int?>((ref) async* {
  final counter = ref.watch(sessionTrafficCounterProvider);
  while (true) {
    yield await counter.readSessionTxBytes();
    await Future<void>.delayed(const Duration(seconds: 2));
  }
});
