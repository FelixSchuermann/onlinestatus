import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _pluginAvailable = false;

  // Feature flag for multi-window toast popups (disabled for now - causes issues)
  static const bool _enableMultiWindowToast = false;

  // Optional navigator key to get an OverlayState for desktop toasts
  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) => _navigatorKey = key;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      // Initialize only Linux via the plugin API available in this project.
      final linux = LinuxInitializationSettings(defaultActionName: 'Open');
      final settings = InitializationSettings(linux: linux);
      await _plugin.initialize(settings);
      _pluginAvailable = true;
      // ignore: avoid_print
      print('NotificationService: plugin initialized, available=$_pluginAvailable');
    } catch (e, st) {
      _pluginAvailable = false;
      // ignore: avoid_print
      print('NotificationService.init error: $e');
      // ignore: avoid_print
      print(st);
    }
    _initialized = true;
  }


  static Future<void> showNotification(String title, String body) async {
    // Ensure plugin initialized (attempt once)
    if (!_initialized) await init();
    // Debug log
    // ignore: avoid_print
    print('NotificationService: showNotification: $title - $body (pluginAvailable=$_pluginAvailable)');

    bool shownSystem = false;

    // Try system notification on Linux first (notify-send)
    if (Platform.isLinux) {
      try {
        final result = await Process.run('notify-send', [title, body]);
        // ignore: avoid_print
        print('NotificationService: notify-send result: ${result.exitCode}, stdout=${result.stdout}, stderr=${result.stderr}');
        shownSystem = result.exitCode == 0;
      } catch (e, st) {
        // fallthrough to other attempts
        // ignore: avoid_print
        print('NotificationService: notify-send failed: $e');
        // ignore: avoid_print
        print(st);
      }
    }

    // Try desktop_multi_window toast on Windows/Linux (behind feature flag)
    if (!shownSystem && _enableMultiWindowToast && (Platform.isWindows || Platform.isLinux)) {
      try {
        final args = jsonEncode({'title': title, 'body': body, 'durationMs': 3000});
        // ignore: avoid_print
        print('NotificationService: creating toast window with args=$args');

        final config = WindowConfiguration(arguments: args, hiddenAtLaunch: true);
        final window = await WindowController.create(config);

        // Show the toast window - size is controlled by the sub-window app
        await window.show();

        shownSystem = true;
        // ignore: avoid_print
        print('NotificationService: toast window created successfully');
        return;
      } catch (e, st) {
        // ignore: avoid_print
        print('NotificationService: desktop_multi_window failed: $e');
        // ignore: avoid_print
        print(st);
      }
    }

    // Fallback to overlay toast (if main window visible)
    if (Platform.isWindows || Platform.isLinux) {
      try {
        bool isVisible = true;
        try {
          isVisible = await windowManager.isVisible();
        } catch (e) {
          // ignore: avoid_print
          print('NotificationService: windowManager.isVisible check failed: $e');
        }
        // debug
        // ignore: avoid_print
        print('NotificationService: main window visible = $isVisible');

        if (!isVisible) {
          // main window hidden -> overlay toast won't be visible. Log and return.
          // ignore: avoid_print
          print('NotificationService: main window is hidden (probably in tray). Overlay toast will not be shown.');
          return;
        }

        _showOverlayToast(title, body);
      } catch (e, st) {
        // ignore: avoid_print
        print('NotificationService: overlay toast failed: $e');
        // ignore: avoid_print
        print(st);
      }
    }
  }

  static void _showOverlayToast(String title, String body, {Duration duration = const Duration(seconds: 4)}) {
    final navKey = _navigatorKey;
    // ignore: avoid_print
    print('NotificationService: _showOverlayToast navKey=${navKey != null}');
    if (navKey == null) return;
    final overlayState = navKey.currentState?.overlay;
    // ignore: avoid_print
    print('NotificationService: _showOverlayToast overlayState=${overlayState != null}');
    if (overlayState == null) return;

    OverlayEntry? entryPlaceholder;

    final entry = OverlayEntry(
      builder: (context) {
        return _DesktopToast(entry: entryPlaceholder, title: title, body: body);
      },
    );

    entryPlaceholder = entry;

    overlayState.insert(entry);

    // remove after duration
    Timer(duration, () {
      try {
        entry.remove();
      } catch (_) {}
    });
  }
}

// Small widget shown as overlay in bottom-right corner, dismisses itself by parent timer.
class _DesktopToast extends StatelessWidget {
  final OverlayEntry? entry;
  final String title;
  final String body;

  const _DesktopToast({this.entry, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Use a fraction of width to ensure not too wide
    final width = mq.size.width * 0.28; // ~28% of screen
    return Positioned(
      right: 20,
      bottom: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.blueGrey[900],
        child: Container(
          width: width < 280 ? width : 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // small circle icon
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
