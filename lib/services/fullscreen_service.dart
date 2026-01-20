import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Service to detect if a fullscreen application is running.
///
/// This is useful to detect gaming, movies, or other focused activities.
///
/// Platform support:
/// - Windows: Uses Win32 API to check foreground window state
/// - Linux: Uses wmctrl or xdotool (requires installation)
/// - macOS: Not supported
/// - Android/iOS: Not applicable (mobile handles this differently)
class FullscreenService {
  // Cache to avoid too many checks
  static bool? _cachedFullscreen;
  static String? _cachedAppName;
  static DateTime? _lastCheck;
  static const _cacheDuration = Duration(seconds: 2);

  // Check if running on a mobile platform
  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// Returns true if a fullscreen application is currently in the foreground.
  /// Returns false on mobile or if detection fails.
  static Future<bool> isFullscreenAppRunning() async {
    if (_isMobile) {
      return false;
    }

    // Check cache
    final now = DateTime.now();
    if (_lastCheck != null &&
        _cachedFullscreen != null &&
        now.difference(_lastCheck!) < _cacheDuration) {
      return _cachedFullscreen!;
    }

    bool result = false;
    String? appName;

    if (Platform.isWindows) {
      final detection = _detectWindowsFullscreen();
      result = detection.$1;
      appName = detection.$2;
    } else if (Platform.isLinux) {
      final detection = await _detectLinuxFullscreen();
      result = detection.$1;
      appName = detection.$2;
    }

    _cachedFullscreen = result;
    _cachedAppName = appName;
    _lastCheck = now;
    return result;
  }

  /// Returns the name of the current fullscreen application, if detected.
  static String? get currentFullscreenApp => _cachedAppName;

  // --- Windows Implementation using Win32 API ---
  static (bool, String?) _detectWindowsFullscreen() {
    try {
      final user32 = DynamicLibrary.open('user32.dll');

      // Get foreground window
      final getForegroundWindow = user32.lookupFunction<
          IntPtr Function(),
          int Function()>('GetForegroundWindow');

      // Get window rect
      final getWindowRect = user32.lookupFunction<
          Int32 Function(IntPtr hWnd, Pointer<RECT> lpRect),
          int Function(int hWnd, Pointer<RECT> lpRect)>('GetWindowRect');

      // Get window text length
      final getWindowTextLength = user32.lookupFunction<
          Int32 Function(IntPtr hWnd),
          int Function(int hWnd)>('GetWindowTextLengthW');

      // Get window text
      final getWindowText = user32.lookupFunction<
          Int32 Function(IntPtr hWnd, Pointer<Utf16> lpString, Int32 nMaxCount),
          int Function(int hWnd, Pointer<Utf16> lpString, int nMaxCount)>('GetWindowTextW');

      // Get monitor info
      final monitorFromWindow = user32.lookupFunction<
          IntPtr Function(IntPtr hWnd, Uint32 dwFlags),
          int Function(int hWnd, int dwFlags)>('MonitorFromWindow');

      final getMonitorInfo = user32.lookupFunction<
          Int32 Function(IntPtr hMonitor, Pointer<MONITORINFO> lpmi),
          int Function(int hMonitor, Pointer<MONITORINFO> lpmi)>('GetMonitorInfoW');

      final hwnd = getForegroundWindow();
      if (hwnd == 0) {
        return (false, null);
      }

      // Get window title
      String? windowTitle;
      final textLength = getWindowTextLength(hwnd);
      if (textLength > 0) {
        final buffer = calloc<Uint16>(textLength + 1);
        getWindowText(hwnd, buffer.cast<Utf16>(), textLength + 1);
        windowTitle = buffer.cast<Utf16>().toDartString();
        calloc.free(buffer);
      }

      // Get window rect
      final windowRect = calloc<RECT>();
      final gotRect = getWindowRect(hwnd, windowRect);
      if (gotRect == 0) {
        calloc.free(windowRect);
        return (false, windowTitle);
      }

      // Get monitor info for the monitor containing the window
      const MONITOR_DEFAULTTONEAREST = 2;
      final hMonitor = monitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      if (hMonitor == 0) {
        calloc.free(windowRect);
        return (false, windowTitle);
      }

      final monitorInfo = calloc<MONITORINFO>();
      monitorInfo.ref.cbSize = sizeOf<MONITORINFO>();
      final gotMonitorInfo = getMonitorInfo(hMonitor, monitorInfo);
      if (gotMonitorInfo == 0) {
        calloc.free(windowRect);
        calloc.free(monitorInfo);
        return (false, windowTitle);
      }

      // Compare window rect with monitor rect
      final isFullscreen =
          windowRect.ref.left <= monitorInfo.ref.rcMonitor.left &&
          windowRect.ref.top <= monitorInfo.ref.rcMonitor.top &&
          windowRect.ref.right >= monitorInfo.ref.rcMonitor.right &&
          windowRect.ref.bottom >= monitorInfo.ref.rcMonitor.bottom;

      calloc.free(windowRect);
      calloc.free(monitorInfo);

      // Filter out desktop/shell windows
      if (windowTitle != null) {
        final lowerTitle = windowTitle.toLowerCase();
        if (lowerTitle.isEmpty ||
            lowerTitle == 'program manager' ||
            lowerTitle == 'windows input experience' ||
            lowerTitle.contains('taskbar')) {
          return (false, null);
        }
      }

      return (isFullscreen, windowTitle);
    } catch (e) {
      // ignore: avoid_print
      print('FullscreenService: Windows detection error: $e');
      return (false, null);
    }
  }

  // --- Linux Implementation using wmctrl/xdotool ---
  static Future<(bool, String?)> _detectLinuxFullscreen() async {
    try {
      // Try using xdotool and xprop
      final result = await Process.run('bash', [
        '-c',
        '''
        # Get active window ID
        ACTIVE_WIN=\$(xdotool getactivewindow 2>/dev/null)
        if [ -z "\$ACTIVE_WIN" ]; then
          echo "ERROR:no_window"
          exit 1
        fi
        
        # Get window name (properly quoted to handle special characters)
        WIN_NAME=\$(xdotool getwindowname "\$ACTIVE_WIN" 2>/dev/null || echo "")
        
        # Check if window is fullscreen using xprop
        # Use grep -q for boolean check instead of grep -c
        if xprop -id "\$ACTIVE_WIN" _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_FULLSCREEN"; then
          # Use a delimiter that's unlikely to appear in window names
          echo "FULLSCREEN|\$WIN_NAME"
        else
          echo "WINDOWED|\$WIN_NAME"
        fi
        '''
      ]);

      final output = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      
      // Check for errors (exit code or ERROR prefix)
      if (result.exitCode != 0 || output.startsWith('ERROR:')) {
        // No active window or detection failed
        return (false, null);
      }
      
      // Parse the output with the new delimiter
      if (output.startsWith('FULLSCREEN|')) {
        final appName = output.substring(11); // Remove "FULLSCREEN|" prefix
        return (true, appName.isEmpty ? null : appName);
      } else if (output.startsWith('WINDOWED|')) {
        final appName = output.substring(9); // Remove "WINDOWED|" prefix
        return (false, appName.isEmpty ? null : appName);
      }
      
      // Unexpected output format
      if (stderr.isNotEmpty) {
        // ignore: avoid_print
        print('FullscreenService: Linux detection stderr: $stderr');
      }
      return (false, null);
    } catch (e) {
      // Tools not installed
      // ignore: avoid_print
      print('FullscreenService: Linux detection failed: $e');
      print('FullscreenService: Install with: sudo apt install xdotool x11-utils');
      return (false, null);
    }
  }
}

// --- Windows FFI Structures ---

final class RECT extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class MONITORINFO extends Struct {
  @Uint32()
  external int cbSize;
  external RECT rcMonitor;
  external RECT rcWork;
  @Uint32()
  external int dwFlags;
}

