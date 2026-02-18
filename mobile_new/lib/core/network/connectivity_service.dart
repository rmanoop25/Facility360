import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity service for monitoring network status
/// Used for offline-first functionality
class ConnectivityService {
  ConnectivityService() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  /// Current online status
  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  void _init() {
    // Check initial status
    checkConnectivity();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (error) {
        debugPrint('Connectivity error: $error');
        _updateStatus(false);
      },
    );
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      debugPrint('Connectivity check results: $results');
      final connected = _isConnected(results);
      debugPrint('Is connected: $connected');
      _updateStatus(connected);
      return connected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return _isOnline;
    }
  }

  /// Handle connectivity change events
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    debugPrint('Connectivity changed event: $results');
    final connected = _isConnected(results);
    debugPrint('New connection status: $connected');
    _updateStatus(connected);
  }

  /// Check if any result indicates connectivity
  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Update status and notify listeners
  void _updateStatus(bool connected) {
    if (_isOnline != connected) {
      _isOnline = connected;
      _connectivityController.add(connected);
      debugPrint('Connectivity changed: ${connected ? "Online" : "Offline"}');
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}

/// Global connectivity service provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for connectivity status changes
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Current connectivity status provider
/// Returns true if online, false if offline
final isOnlineProvider = Provider<bool>((ref) {
  // Watch the stream to get updates
  final asyncValue = ref.watch(connectivityStreamProvider);

  // Return the current value, defaulting to checking service directly
  return asyncValue.when(
    data: (isOnline) => isOnline,
    loading: () => ref.read(connectivityServiceProvider).isOnline,
    error: (_, __) => ref.read(connectivityServiceProvider).isOnline,
  );
});
