import 'package:dio/dio.dart';

import '../models/friend.dart';

class FriendApiClient {
  final Dio _dio;

  FriendApiClient({Dio? dio}) : _dio = dio ?? Dio();

  /// Set the base url to your backend, e.g. http://10.0.2.2:8000 for Android emulator,
  /// or http://localhost:8000 for web/desktop.
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  Future<List<Friend>> fetchFriends() async {
    final resp = await _dio.get('/online_status/');
    final data = resp.data as Map<String, dynamic>;
    final friends = (data['friends'] as List<dynamic>)
        .map((m) => Friend.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    return friends;
  }

  /// Send a heartbeat to the backend to indicate this user is online.
  ///
  /// [uuid] - Unique identifier for this client instance
  /// [name] - Display name of the user
  /// [activityState] - User's activity state: "online", "idle", or "unknown"
  /// [token] - Optional auth token (for future use)
  Future<bool> sendHeartbeat({
    required String uuid,
    required String name,
    String activityState = 'online',
    String? token,
  }) async {
    try {
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final payload = {
        'uuid': uuid,
        'name': name,
        'activity_state': activityState,
      };

      final resp = await _dio.post(
        '/heartbeat/',
        data: payload,
        options: Options(headers: headers),
      );

      return resp.statusCode == 200;
    } catch (e) {
      // Log error but don't crash - heartbeat failure shouldn't break the app
      // ignore: avoid_print
      print('Heartbeat error: $e');
      return false;
    }
  }

  /// Legacy method - kept for compatibility but use sendHeartbeat instead
  @Deprecated('Use sendHeartbeat instead')
  Future<void> sendPresence(String name, {String? token}) async {
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final payload = {
      'name': name,
      'state': 'online',
      'last_seen': '${DateTime.now().toIso8601String()}Z'
    };
    await _dio.post('/online_status/',
        data: {'friends': [payload]}, options: Options(headers: headers));
  }
}
