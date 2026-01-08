import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'ui/home_page.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';
import 'package:onlinestatus2/providers/friends_provider.dart';
import 'package:onlinestatus2/services/notification_service.dart';
import 'package:onlinestatus2/desktop/tray_service.dart';

// Global navigator key for overlay toasts
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a container to initialize persisted settings before the app UI runs.
  final container = ProviderContainer();

  // Load persisted settings
  await container.read(settingsProvider.notifier).loadFromPrefs();
  await container.read(baseUrlProvider.notifier).loadFromPrefs();

  // Initialize notification service
  try {
    await NotificationService.init();
  } catch (e) {
    // ignore: avoid_print
    print('NotificationService init error: $e');
  }
  NotificationService.setNavigatorKey(navigatorKey);

  // TrayService (currently disabled on Linux)
  try {
    final tray = TrayService();
    await tray.init(
      onShow: () {},
      onQuit: () async {
        await tray.dispose();
        exit(0);
      },
    );
  } catch (e) {
    // ignore: avoid_print
    print('TrayService error: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
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
