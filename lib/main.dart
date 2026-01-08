import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';

import 'ui/home_page.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';
import 'package:onlinestatus2/providers/friends_provider.dart';
import 'package:onlinestatus2/services/notification_service.dart';
import 'package:onlinestatus2/desktop/tray_service.dart';

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
    NotificationService.setNavigatorKey(navigatorKey);

    // TrayService (currently disabled)
    try {
      final tray = TrayService();
      await tray.init(
        onShow: () {},
        onQuit: () async {
          await tray.dispose();
          exit(0);
        },
      );
      await _logToFile('TrayService initialized');
    } catch (e) {
      await _logToFile('TrayService error: $e');
    }

    await _logToFile('Running app...');

    // Sync log before runApp
    final logFile = File('${Directory.systemTemp.path}/onlinestatus_log.txt');
    logFile.writeAsStringSync('[${DateTime.now().toIso8601String()}] About to call runApp\n', mode: FileMode.append);

    runApp(UncontrolledProviderScope(container: container, child: const MyApp()));

    logFile.writeAsStringSync('[${DateTime.now().toIso8601String()}] runApp returned (app running)\n', mode: FileMode.append);
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
