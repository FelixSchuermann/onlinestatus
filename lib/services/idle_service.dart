import 'dart:io';

// Conditional import for Windows FFI
import 'idle_service_windows.dart' if (dart.library.io) 'idle_service_windows.dart';

/// Service to detect if the user is idle (AFK) or active at the computer.
///
/// Platform support:
/// - Windows: Uses GetLastInputInfo via FFI (accurate)
/// - Linux: Not supported (returns 'unknown') due to X11/FFI stability issues
/// - macOS: Not supported (returns 'unknown')
class IdleService {
  // Threshold in seconds after which user is considered AFK
  static const int afkThresholdSeconds = 300; // 5 minutes

  /// Returns the number of seconds since the last user input (mouse/keyboard).
  /// Returns -1 if detection is not supported or fails.
  static Future<int> getIdleTimeSeconds() async {
    if (Platform.isWindows) {
      try {
        return WindowsIdleDetector.getIdleTimeSeconds();
      } catch (e) {
        // ignore: avoid_print
        print('IdleService: Windows idle detection failed: $e');
        return -1;
      }
    }

    // Linux/macOS: Not supported
    // Linux X11 FFI causes segfaults, so we disable it
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
