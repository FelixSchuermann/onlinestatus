import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/friend_api.dart';
import '../providers/settings_provider.dart';
import '../providers/friends_provider.dart';
import 'idle_service.dart';

/// Service that sends periodic heartbeats to the backend.
///
/// Heartbeats are sent every 60 seconds to indicate the user is online.
/// The backend considers a user offline if no heartbeat is received for 5 minutes.
///
/// The heartbeat includes the user's activity state:
/// - "online": User is actively using the computer (mouse/keyboard activity within 5 min)
/// - "idle": User is AFK (no activity for 5+ minutes)
/// - "unknown": Could not determine activity state
class HeartbeatService {
  Timer? _timer;
  final FriendApiClient _api;
  final SettingsState _settings;

  // Last known activity state for logging/debugging
  String _lastActivityState = 'unknown';

  static const Duration _heartbeatInterval = Duration(seconds: 60);

  HeartbeatService({
    required FriendApiClient api,
    required SettingsState settings,
  })  : _api = api,
        _settings = settings;

  /// Start sending periodic heartbeats.
  ///
  /// Only sends heartbeats if a name is configured.
  void start() {
    // Send initial heartbeat immediately
    _sendHeartbeat();

    // Schedule periodic heartbeats
    _timer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  /// Stop sending heartbeats.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Send a single heartbeat now.
  Future<bool> _sendHeartbeat() async {
    if (_settings.name.isEmpty || _settings.uuid.isEmpty) {
      // ignore: avoid_print
      print('HeartbeatService: Skipping heartbeat - name or uuid not configured');
      return false;
    }

    // Get current activity state from IdleService
    final activityState = await IdleService.getUserActivityStatus();
    _lastActivityState = activityState;

    final success = await _api.sendHeartbeat(
      uuid: _settings.uuid,
      name: _settings.name,
      activityState: activityState,
      token: _settings.token.isNotEmpty ? _settings.token : null,
    );

    // ignore: avoid_print
    print('HeartbeatService: Heartbeat ${success ? "sent" : "failed"} for ${_settings.name} (state: $activityState)');
    return success;
  }

  /// Manually trigger a heartbeat (for testing).
  Future<bool> sendNow() => _sendHeartbeat();

  /// Get the last known activity state
  String get lastActivityState => _lastActivityState;
}

/// Provider for the HeartbeatService.
///
/// Automatically starts/stops heartbeats when settings change.
final heartbeatServiceProvider = Provider.autoDispose<HeartbeatService>((ref) {
  final api = ref.watch(friendApiProvider);
  final settings = ref.watch(settingsProvider);

  final service = HeartbeatService(api: api, settings: settings);
  service.start();

  ref.onDispose(() {
    service.stop();
  });

  return service;
});

