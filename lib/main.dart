import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: unused_import
import 'dart:convert';
// ignore: unused_import
import 'dart:async';

import 'ui/home_page.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';
import 'package:onlinestatus2/providers/friends_provider.dart';
import 'package:onlinestatus2/services/notification_service.dart';
import 'package:onlinestatus2/desktop/tray_service.dart';
import 'package:window_manager/window_manager.dart';
// ignore: unused_import
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:io';

// Feature flag for multi-window toast (disabled for now)
const bool _enableMultiWindowToast = false;

// Global navigator key so NotificationService can insert overlay toasts on desktop
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if this is a sub-window (toast notification window) - only if feature enabled
  if (_enableMultiWindowToast && args.isNotEmpty) {
    // This is a toast sub-window - parse args and show toast UI
    _runToastWindow(args);
    return;
  }

  // --- Main Window Logic ---
  // Create a container to initialize persisted settings before the app UI runs.
  final container = ProviderContainer();
  // load persisted settings and base url
  await container.read(settingsProvider.notifier).loadFromPrefs();
  await container.read(baseUrlProvider.notifier).loadFromPrefs();

  // Initialize notification service
  await NotificationService.init();
  // pass navigator key so overlay toasts may be shown
  NotificationService.setNavigatorKey(navigatorKey);

  // Initialize window manager early so UI can call windowManager.hide()
  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(400, 500),
      minimumSize: Size(300, 400),
      center: true,
      title: 'Online Status',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(MyWindowListener());
  }

  final tray = TrayService();
  await tray.init(onShow: () async {
    if (Platform.isWindows || Platform.isLinux) {
      await windowManager.show();
      await windowManager.focus();
    }
  }, onQuit: () async {
    await tray.dispose();
    // ignore: avoid_slow_async_io
    exit(0);
  });

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

/// Run the toast notification sub-window
void _runToastWindow(List<String> args) {
  String title = 'Notification';
  String body = '';
  int durationMs = 3000;

  // Parse JSON args from WindowConfiguration.arguments
  if (args.isNotEmpty) {
    try {
      final decoded = jsonDecode(args[0]) as Map<String, dynamic>;
      title = decoded['title'] as String? ?? 'Notification';
      body = decoded['body'] as String? ?? '';
      durationMs = decoded['durationMs'] as int? ?? 3000;
    } catch (e) {
      // Fallback
      title = args[0];
      body = args.length > 1 ? args[1] : '';
    }
  }

  runApp(_ToastApp(title: title, body: body, durationMs: durationMs));
}

/// Toast notification app (sub-window)
class _ToastApp extends StatefulWidget {
  final String title;
  final String body;
  final int durationMs;

  const _ToastApp({required this.title, required this.body, required this.durationMs});

  @override
  State<_ToastApp> createState() => _ToastAppState();
}

class _ToastAppState extends State<_ToastApp> {
  @override
  void initState() {
    super.initState();
    _setupWindow();
  }

  Future<void> _setupWindow() async {
    try {
      // Get screen info and position window in bottom-right corner
      final controller = await WindowController.fromCurrentEngine();

      // Set small window size and show
      // We can't easily set size via WindowController, so we rely on the content size
      await controller.show();

      // Auto-close the window after duration
      Timer(Duration(milliseconds: widget.durationMs), () async {
        try {
          await controller.hide();
          exit(0);
        } catch (e) {
          // ignore: avoid_print
          print('Toast close error: $e');
          exit(0);
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('Toast setup error: $e');
      // Still try to close after duration
      Timer(Duration(milliseconds: widget.durationMs), () => exit(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Green online indicator
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 12),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Status',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class MyWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // hide instead of close
    await windowManager.hide();
  }
}
