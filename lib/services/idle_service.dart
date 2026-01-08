
/// Service to detect if the user is idle (AFK) or active at the computer.
///
/// Note: Currently disabled on all platforms due to FFI stability issues.
/// Returns 'unknown' status which means the heartbeat will report 'online'.
class IdleService {
  // Threshold in seconds after which user is considered AFK
  static const int afkThresholdSeconds = 300; // 5 minutes

  /// Returns the number of seconds since the last user input (mouse/keyboard).
  /// Returns -1 if detection is not supported or fails.
  static Future<int> getIdleTimeSeconds() async {
    // Idle detection disabled due to FFI stability issues on Linux
    // TODO: Re-enable with a stable cross-platform solution
    return -1;
  }

  /// Returns true if the user is considered AFK (idle for more than threshold).
  static Future<bool> isUserAfk({int? thresholdSeconds}) async {
    final threshold = thresholdSeconds ?? afkThresholdSeconds;
    final idleTime = await getIdleTimeSeconds();
    if (idleTime < 0) {
      // Can't determine, assume active
      return false;
    }
    return idleTime >= threshold;
  }

  /// Returns true if the user is actively using the computer.
  static Future<bool> isUserActive({int? thresholdSeconds}) async {
    return !(await isUserAfk(thresholdSeconds: thresholdSeconds));
  }

  /// Get a status string: "online", "idle", or "unknown"
  static Future<String> getUserActivityStatus({int? thresholdSeconds}) async {
    final idleTime = await getIdleTimeSeconds();
    if (idleTime < 0) {
      return 'unknown';
    }
    final threshold = thresholdSeconds ?? afkThresholdSeconds;
    return idleTime >= threshold ? 'idle' : 'online';
  }
}


