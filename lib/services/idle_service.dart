import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Service to detect if the user is idle (AFK) or active at the computer.
///
/// Uses native APIs:
/// - Windows: GetLastInputInfo via FFI (no external packages needed)
/// - Linux: Disabled due to stability issues with X11/FFI
class IdleService {
  // Threshold in seconds after which user is considered AFK
  static const int afkThresholdSeconds = 300; // 5 minutes

  /// Returns the number of seconds since the last user input (mouse/keyboard).
  /// Returns -1 if detection is not supported or fails.
  static Future<int> getIdleTimeSeconds() async {
    if (Platform.isWindows) {
      return _getWindowsIdleTime();
    }
    // Linux and other platforms: not supported
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

  // --- Windows Implementation ---
  static int _getWindowsIdleTime() {
    try {
      final user32 = DynamicLibrary.open('user32.dll');

      final getLastInputInfo = user32.lookupFunction<
          Int32 Function(Pointer<_LASTINPUTINFO>),
          int Function(Pointer<_LASTINPUTINFO>)>('GetLastInputInfo');

      final kernel32 = DynamicLibrary.open('kernel32.dll');
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
      print('IdleService: Windows idle detection error: $e');
      return -1;
    }
  }
}

// --- Windows FFI Structs ---
final class _LASTINPUTINFO extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwTime;
}


