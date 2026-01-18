import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'fullscreen_service.dart';

/// Service to detect if the user is idle (AFK) or active at the computer.
///
/// Platform support:
/// - Windows: Uses GetLastInputInfo via FFI (accurate)
/// - Linux: Uses xprintidle command (requires: sudo apt install xprintidle)
/// - macOS: Not supported (returns 'unknown')
/// - Android/iOS: Mobile devices are considered always 'online' (no idle detection)
class IdleService {
  // Threshold in seconds after which user is considered AFK
  static const int afkThresholdSeconds = 300; // 5 minutes

  // Cache to avoid too many shell calls on Linux
  static int? _cachedIdleTime;
  static DateTime? _lastCheck;
  static const _cacheDuration = Duration(seconds: 2);

  // Check if running on a mobile platform
  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// Returns the number of seconds since the last user input (mouse/keyboard).
  /// Returns -1 if detection is not supported or fails.
  /// Returns 0 on mobile (always considered active).
  static Future<int> getIdleTimeSeconds() async {
    // Mobile devices: always considered active (return 0 = just used)
    if (_isMobile) {
      return 0;
    }

    if (Platform.isWindows) {
      return _getWindowsIdleTime();
    } else if (Platform.isLinux) {
      return await _getLinuxIdleTime();
    }
    // macOS: Not supported
    return -1;
  }

  /// Returns true if the user is considered AFK (idle for more than threshold).
  static Future<bool> isUserAfk({int? thresholdSeconds}) async {
    final threshold = thresholdSeconds ?? afkThresholdSeconds;
    final idleTime = await getIdleTimeSeconds();
    if (idleTime < 0) {
      return false;
    }
    return idleTime >= threshold;
  }

  /// Returns true if the user is actively using the computer.
  static Future<bool> isUserActive({int? thresholdSeconds}) async {
    return !(await isUserAfk(thresholdSeconds: thresholdSeconds));
  }

  /// Get a status string: "online", "idle", "busy", or "unknown"
  /// Priority: busy (fullscreen) > idle (AFK) > online (active)
  static Future<String> getUserActivityStatus({int? thresholdSeconds}) async {
    // Mobile devices are always considered online
    if (_isMobile) {
      return 'online';
    }

    // Check for fullscreen first (highest priority - user is "busy")
    final isFullscreen = await FullscreenService.isFullscreenAppRunning();
    if (isFullscreen) {
      final appName = FullscreenService.currentFullscreenApp;
      // ignore: avoid_print
      print('IdleService: User is in fullscreen app: $appName');
      return 'busy';
    }

    final idleTime = await getIdleTimeSeconds();
    if (idleTime < 0) {
      return 'unknown';
    }
    final threshold = thresholdSeconds ?? afkThresholdSeconds;
    return idleTime >= threshold ? 'idle' : 'online';
  }

  /// Check if user is currently in a fullscreen application
  static Future<bool> isUserInFullscreen() async {
    if (_isMobile) return false;
    return FullscreenService.isFullscreenAppRunning();
  }

  /// Get the name of the current fullscreen app (if any)
  static String? get currentFullscreenApp => FullscreenService.currentFullscreenApp;

  // --- Linux Implementation using xprintidle ---
  static Future<int> _getLinuxIdleTime() async {
    // Use cache to avoid too many shell calls
    final now = DateTime.now();
    if (_lastCheck != null && _cachedIdleTime != null &&
        now.difference(_lastCheck!) < _cacheDuration) {
      return _cachedIdleTime!;
    }

    try {
      // xprintidle returns idle time in milliseconds
      // Install with: sudo apt install xprintidle
      final result = await Process.run('xprintidle', []);

      if (result.exitCode == 0) {
        final idleMs = int.tryParse(result.stdout.toString().trim());
        if (idleMs != null) {
          final idleSeconds = idleMs ~/ 1000;
          _cachedIdleTime = idleSeconds;
          _lastCheck = now;
          return idleSeconds;
        }
      } else {
        // xprintidle not installed or failed
        // ignore: avoid_print
        print('IdleService: xprintidle failed (exit code ${result.exitCode}). Install with: sudo apt install xprintidle');
      }
      return -1;
    } catch (e) {
      // xprintidle probably not installed
      // ignore: avoid_print
      print('IdleService: Linux idle detection failed: $e');
      // ignore: avoid_print
      print('IdleService: Install xprintidle with: sudo apt install xprintidle');
      return -1;
    }
  }

  // --- Windows FFI Implementation ---
  static int _getWindowsIdleTime() {
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final kernel32 = DynamicLibrary.open('kernel32.dll');

      final getLastInputInfo = user32.lookupFunction<
          Int32 Function(Pointer<_LASTINPUTINFO>),
          int Function(Pointer<_LASTINPUTINFO>)>('GetLastInputInfo');

      final getTickCount = kernel32.lookupFunction<
          Uint32 Function(),
          int Function()>('GetTickCount');

      final lastInputInfo = calloc<_LASTINPUTINFO>();
      lastInputInfo.ref.cbSize = 8;

      final result = getLastInputInfo(lastInputInfo);

      if (result != 0) {
        final lastInputTime = lastInputInfo.ref.dwTime;
        final currentTime = getTickCount();
        final idleMs = currentTime - lastInputTime;
        final idleSeconds = idleMs ~/ 1000;

        calloc.free(lastInputInfo);
        return idleSeconds;
      }

      calloc.free(lastInputInfo);
      return -1;
    } catch (e) {
      // ignore: avoid_print
      print('IdleService: Windows FFI error: $e');
      return -1;
    }
  }
}

// Windows LASTINPUTINFO struct
final class _LASTINPUTINFO extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwTime;
}
