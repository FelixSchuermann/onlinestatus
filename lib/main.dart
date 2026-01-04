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
import 'dart:io';

// Global navigator key so NotificationService can insert overlay toasts on desktop
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Log to file for debugging release builds
Future<void> _logToFile(String message) async {
  try {
    final logFile = File('${Directory.systemTemp.path}/onlinestatus_log.txt');
    final timestamp = DateTime.now().toIso8601String();
    await logFile.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
  } catch (_) {
    // Ignore logging errors
  }
}

Future<void> main(List<String> args) async {
  // Wrap everything in error handling for release debugging
  FlutterError.onError = (details) async {
    await _logToFile('FlutterError: ${details.exception}\n${details.stack}');
    FlutterError.presentError(details);
  };

  runZonedGuarded(() async {
    await _logToFile('App starting...');

    WidgetsFlutterBinding.ensureInitialized();
    await _logToFile('WidgetsBinding initialized');

    // --- Main Window Logic ---
    // Create a container to initialize persisted settings before the app UI runs.
    final container = ProviderContainer();
    await _logToFile('ProviderContainer created');

    // load persisted settings and base url
    await container.read(settingsProvider.notifier).loadFromPrefs();
    await _logToFile('Settings loaded');
    await container.read(baseUrlProvider.notifier).loadFromPrefs();
    await _logToFile('BaseURL loaded');

    // Initialize notification service
    try {
      await NotificationService.init();
      await _logToFile('NotificationService initialized');
    } catch (e) {
      await _logToFile('NotificationService init error: $e');
    }
    // pass navigator key so overlay toasts may be shown
    NotificationService.setNavigatorKey(navigatorKey);

    // Initialize window manager early so UI can call windowManager.hide()
    if (Platform.isWindows || Platform.isLinux) {
      try {
        await windowManager.ensureInitialized();
        await _logToFile('WindowManager initialized');
        WindowOptions windowOptions = const WindowOptions(
          size: Size(400, 500),
          minimumSize: Size(300, 400),
          center: true,
          title: 'Online Status',
        );
        windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
          await _logToFile('Window shown');
        });
        windowManager.addListener(MyWindowListener());
      } catch (e) {
        await _logToFile('WindowManager error: $e');
      }
    }

    try {
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
      await _logToFile('TrayService initialized');
    } catch (e) {
      await _logToFile('TrayService error: $e');
    }

    await _logToFile('Running app...');
    runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
  }, (error, stack) async {
    await _logToFile('Uncaught error: $error\n$stack');
  });
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
