import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Service to detect if the user is idle (AFK) or active at the computer.
///
/// Uses native APIs:
/// - Windows: GetLastInputInfo via FFI (no external packages needed)
/// - Linux: X11 XScreenSaver Extension via FFI (no external packages needed)
class IdleService {
  // Threshold in seconds after which user is considered AFK
  static const int afkThresholdSeconds = 300; // 5 minutes

  /// Returns the number of seconds since the last user input (mouse/keyboard).
  /// Returns -1 if detection is not supported or fails.
  static Future<int> getIdleTimeSeconds() async {
    if (Platform.isWindows) {
      return _getWindowsIdleTime();
    } else if (Platform.isLinux) {
      return _getLinuxIdleTime();
    }
    return -1; // Not supported on this platform
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

  // --- Linux Implementation (X11 XScreenSaver Extension) ---
  static DynamicLibrary? _x11Lib;
  static DynamicLibrary? _xssLib;
  static bool _linuxLibsChecked = false;
  static bool _linuxLibsAvailable = false;

  static int _getLinuxIdleTime() {
    // Check if we already know the libs are unavailable
    if (_linuxLibsChecked && !_linuxLibsAvailable) {
      return -1;
    }

    try {
      // Try to load X11 and Xss libraries
      if (!_linuxLibsChecked) {
        _linuxLibsChecked = true;
        try {
          _x11Lib = DynamicLibrary.open('libX11.so.6');
          _xssLib = DynamicLibrary.open('libXss.so.1');
          _linuxLibsAvailable = true;
        } catch (e) {
          // ignore: avoid_print
          print('IdleService: X11/Xss libraries not available (maybe running under Wayland or libs not installed): $e');
          _linuxLibsAvailable = false;
          return -1;
        }
      }

      if (_x11Lib == null || _xssLib == null) {
        return -1;
      }

      // XOpenDisplay
      final xOpenDisplay = _x11Lib!.lookupFunction<
          Pointer Function(Pointer<Utf8>),
          Pointer Function(Pointer<Utf8>)>('XOpenDisplay');

      // XCloseDisplay
      final xCloseDisplay = _x11Lib!.lookupFunction<
          Int32 Function(Pointer),
          int Function(Pointer)>('XCloseDisplay');

      // XScreenSaverQueryInfo
      final xScreenSaverQueryInfo = _xssLib!.lookupFunction<
          Int32 Function(Pointer, Uint64, Pointer<_XScreenSaverInfo>),
          int Function(Pointer, int, Pointer<_XScreenSaverInfo>)>('XScreenSaverQueryInfo');

      // XScreenSaverAllocInfo
      final xScreenSaverAllocInfo = _xssLib!.lookupFunction<
          Pointer<_XScreenSaverInfo> Function(),
          Pointer<_XScreenSaverInfo> Function()>('XScreenSaverAllocInfo');

      // XDefaultRootWindow
      final xDefaultRootWindow = _x11Lib!.lookupFunction<
          Uint64 Function(Pointer),
          int Function(Pointer)>('XDefaultRootWindow');

      // Open display (NULL = default display from DISPLAY env var)
      final display = xOpenDisplay(nullptr);
      if (display == nullptr) {
        // ignore: avoid_print
        print('IdleService: Could not open X display');
        return -1;
      }

      // Get root window
      final rootWindow = xDefaultRootWindow(display);

      // Allocate XScreenSaverInfo struct
      final info = xScreenSaverAllocInfo();
      if (info == nullptr) {
        xCloseDisplay(display);
        return -1;
      }

      // Query screen saver info
      final status = xScreenSaverQueryInfo(display, rootWindow, info);

      int idleSeconds = -1;
      if (status != 0) {
        // idle is in milliseconds
        final idleMs = info.ref.idle;
        idleSeconds = idleMs ~/ 1000;
      }

      // Free resources
      calloc.free(info);
      xCloseDisplay(display);

      return idleSeconds;
    } catch (e) {
      // ignore: avoid_print
      print('IdleService: Linux X11 idle detection error: $e');
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

// --- Linux FFI Structs (XScreenSaverInfo) ---
// typedef struct {
//     Window  window;       /* screen saver window - may not exist */
//     int     state;        /* ScreenSaverOff, ScreenSaverOn, ScreenSaverDisabled*/
//     int     kind;         /* ScreenSaverBlanked, ...Internal, ...External */
//     unsigned long til_or_since;   /*
//     unsigned long idle;   /* idle time in milliseconds */
//     unsigned long event_mask; /* events */
// } XScreenSaverInfo;
final class _XScreenSaverInfo extends Struct {
  @Uint64()
  external int window;

  @Int32()
  external int state;

  @Int32()
  external int kind;

  @Uint64()
  external int tilOrSince;

  @Uint64()
  external int idle;

  @Uint64()
  external int eventMask;
}

