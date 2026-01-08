import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'ui/home_page.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';
import 'package:onlinestatus2/providers/friends_provider.dart';
import 'package:onlinestatus2/services/notification_service.dart';
import 'package:onlinestatus2/desktop/tray_service.dart';
import 'package:window_manager/window_manager.dart';
// Global navigator key for overlay toasts
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Global TrayService instance
final TrayService trayService = TrayService();
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize window manager on desktop platforms (Windows and Linux)
  if (Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    // Set window options - compact size for status app
    const windowOptions = WindowOptions(
      size: Size(350, 500),
      minimumSize: Size(280, 350),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'OnlineStatus',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
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
  // Initialize TrayService (Windows and Linux)
  try {
    await trayService.init(
      onQuit: () async {
        await trayService.dispose();
        exit(0);
      },
    );
  } catch (e) {
    // ignore: avoid_print
    print('TrayService error: $e');
  }
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}
class _MyAppState extends State<MyApp> with WindowListener {
  bool get _isDesktop => Platform.isWindows || Platform.isLinux;
  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
    }
  }
  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
  @override
  void onWindowClose() async {
    // On desktop, minimize to tray instead of closing
    if (_isDesktop && trayService.isAvailable) {
      await trayService.minimizeToTray();
    } else {
      // Fallback: just exit
      exit(0);
    }
  }
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
