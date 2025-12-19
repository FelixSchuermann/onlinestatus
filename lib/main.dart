import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_page.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';
import 'package:onlinestatus2/providers/friends_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a container to initialize persisted settings before the app UI runs.
  final container = ProviderContainer();
  // load persisted settings and base url
  await container.read(settingsProvider.notifier).loadFromPrefs();
  await container.read(baseUrlProvider.notifier).loadFromPrefs();

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Online Status',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}
