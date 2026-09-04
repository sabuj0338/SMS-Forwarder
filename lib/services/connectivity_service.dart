import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'forward_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Optimistic default: allow flush attempts until first check says offline.
  final ValueNotifier<bool> isOnline = ValueNotifier(true);

  Future<void> init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _update(results);
    } catch (_) {
      isOnline.value = true;
    }

    _sub?.cancel();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !isOnline.value;
      _update(results);
      if (wasOffline && isOnline.value) {
        unawaited(ForwardService().recoverAndFlush());
      }
    });
  }

  /// Lightweight refresh usable from background / FG isolates.
  Future<bool> refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _update(results);
    } catch (_) {
      // Keep previous value; flush will probe via HTTP.
      isOnline.value = true;
    }
    return isOnline.value;
  }

  void _update(List<ConnectivityResult> results) {
    final online = results.isEmpty
        ? true
        : results.any(
            (r) =>
                r == ConnectivityResult.mobile ||
                r == ConnectivityResult.wifi ||
                r == ConnectivityResult.ethernet ||
                r == ConnectivityResult.vpn ||
                r == ConnectivityResult.other,
          );
    // Treat "none" only when it's the sole result.
    if (results.length == 1 && results.first == ConnectivityResult.none) {
      isOnline.value = false;
      return;
    }
    isOnline.value = online;
  }

  void dispose() {
    _sub?.cancel();
  }
}
