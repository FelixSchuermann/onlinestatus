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

  /// Send presence for [name]. If [token] is provided, send it as Authorization header.
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
