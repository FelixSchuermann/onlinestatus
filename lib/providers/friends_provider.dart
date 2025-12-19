import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/friend_api.dart';
import '../models/friend.dart';

// Default base URL (use localhost for desktop / iOS simulator; 10.0.2.2 for Android emulator)
const String defaultBackendBaseUrl = 'http://localhost:8000';

// persistence key
const _kBaseUrlKey = 'base_url';

/// Riverpod v3 Notifier that holds the backend base URL.
class BaseUrlNotifier extends Notifier<String> {
  @override
  String build() => defaultBackendBaseUrl;

  void set(String v) {
    if (v == state) return;
    state = v;
    saveToPrefs();
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kBaseUrlKey);
    if (v != null && v.isNotEmpty) {
      state = v;
    }
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrlKey, state);
  }
}

/// Provider exposing the base URL state and notifier via `.notifier`.
final baseUrlProvider = NotifierProvider<BaseUrlNotifier, String>(BaseUrlNotifier.new);

final friendApiProvider = Provider<FriendApiClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final client = FriendApiClient();
  client.setBaseUrl(baseUrl);
  return client;
});

final friendsProvider = StreamProvider.autoDispose<List<Friend>>((ref) {
  final api = ref.watch(friendApiProvider);
  final controller = StreamController<List<Friend>>();
  Timer? timer;

  Future<void> start() async {
    try {
      final list = await api.fetchFriends();
      controller.add(list);
    } catch (e, st) {
      controller.addError(e, st);
    }

    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final list = await api.fetchFriends();
        if (!controller.isClosed) controller.add(list);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    });
  }

  start();

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
