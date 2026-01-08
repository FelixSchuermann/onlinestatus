import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Windows-specific idle detection using GetLastInputInfo.
/// This file should only be imported on Windows.
class WindowsIdleDetector {
  static int? _cachedIdleTime;
  static DateTime? _lastCheck;

  /// Get idle time in seconds on Windows.
  /// Returns -1 if detection fails.
  static int getIdleTimeSeconds() {
    // Cache for 1 second to avoid excessive FFI calls
    final now = DateTime.now();
    if (_lastCheck != null &&
        _cachedIdleTime != null &&
        now.difference(_lastCheck!).inMilliseconds < 1000) {
      return _cachedIdleTime!;
    }

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
      lastInputInfo.ref.cbSize = 8; // sizeof(LASTINPUTINFO)

      final result = getLastInputInfo(lastInputInfo);

      if (result != 0) {
        final lastInputTime = lastInputInfo.ref.dwTime;
        final currentTime = getTickCount();
        final idleMs = currentTime - lastInputTime;
        final idleSeconds = idleMs ~/ 1000;

        calloc.free(lastInputInfo);

        _cachedIdleTime = idleSeconds;
        _lastCheck = now;
        return idleSeconds;
      }

      calloc.free(lastInputInfo);
      return -1;
    } catch (e) {
      // ignore: avoid_print
      print('WindowsIdleDetector: Error: $e');
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

