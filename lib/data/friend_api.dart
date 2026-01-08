import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/friend.dart';

/// API client for the Online Status backend.
///
/// All requests require a valid Bearer token for authentication.
/// Supports HTTPS with self-signed certificates.
class FriendApiClient {
  final Dio _dio;
  String? _token;

  FriendApiClient({Dio? dio}) : _dio = dio ?? _createDio();

  /// Create a Dio instance that accepts self-signed certificates.
  static Dio _createDio() {
    final dio = Dio();

    // Allow self-signed certificates for HTTPS
    // Only configure on Windows - Linux has issues with IOHttpClientAdapter
    if (Platform.isWindows) {
      try {
        (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
          final client = HttpClient();
          client.badCertificateCallback = (X509Certificate cert, String host, int port) {
            // Accept all certificates (for self-signed certs)
            return true;
          };
          return client;
        };
      } catch (e) {
        // ignore: avoid_print
        print('FriendApiClient: Could not configure self-signed cert support: $e');
      }
    }

    return dio;
  }

  /// Set the base url to your backend, e.g. https://example.com:8443
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  /// Set the authentication token for all requests.
  void setToken(String? token) {
    _token = token;
  }

  /// Get authorization headers with Bearer token.
  Map<String, String> _getAuthHeaders() {
    final headers = <String, String>{};
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Fetch the list of friends and their online status.
  ///
  /// Requires authentication token to be set via [setToken].
  /// Throws [DioException] if request fails (including 401 Unauthorized).
  Future<List<Friend>> fetchFriends() async {
    final resp = await _dio.get(
      '/online_status/',
      options: Options(headers: _getAuthHeaders()),
    );
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
  ///
  /// Requires authentication token to be set via [setToken].
  /// Returns true if heartbeat was sent successfully.
  Future<bool> sendHeartbeat({
    required String uuid,
    required String name,
    String activityState = 'online',
  }) async {
    try {
      final payload = {
        'uuid': uuid,
        'name': name,
        'activity_state': activityState,
      };

      final resp = await _dio.post(
        '/heartbeat/',
        data: payload,
        options: Options(headers: _getAuthHeaders()),
      );

      return resp.statusCode == 200;
    } catch (e) {
      // Log error but don't crash - heartbeat failure shouldn't break the app
      // ignore: avoid_print
      print('Heartbeat error: $e');
      return false;
    }
  }

  /// Check if the client has a valid token configured.
  bool get hasToken => _token != null && _token!.isNotEmpty;
}
