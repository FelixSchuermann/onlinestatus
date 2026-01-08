import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../models/friend.dart';

/// API client for the Online Status backend.
///
/// All requests require a valid Bearer token for authentication.
/// Supports HTTPS with self-signed certificates on all platforms.
class FriendApiClient {
  final Dio _dio;
  String? _token;

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  FriendApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _configureDio();
  }

  /// Configure Dio with timeouts and SSL settings.
  void _configureDio() {
    // Set timeouts
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.sendTimeout = const Duration(seconds: 10);

    _configureSsl();
  }

  /// Configure Dio to accept self-signed certificates.
  void _configureSsl() {
    try {
      final adapter = IOHttpClientAdapter();
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          // Accept all certificates (for self-signed certs)
          return true;
        };
        return client;
      };
      _dio.httpClientAdapter = adapter;
    } catch (e) {
      // ignore: avoid_print
      print('FriendApiClient: Could not configure SSL: $e');
    }
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
  /// Throws [DioException] if request fails after retries.
  Future<List<Friend>> fetchFriends() async {
    // Show masked token for debugging
    final maskedToken = _token != null && _token!.length > 8
        ? '${_token!.substring(0, 4)}...${_token!.substring(_token!.length - 4)}'
        : '(empty)';

    final headers = _getAuthHeaders();

    // ignore: avoid_print
    print('FriendApiClient.fetchFriends:');
    // ignore: avoid_print
    print('  Platform: ${Platform.operatingSystem}');
    // ignore: avoid_print
    print('  baseUrl: ${_dio.options.baseUrl}');
    // ignore: avoid_print
    print('  token: $maskedToken (length: ${_token?.length ?? 0})');
    // ignore: avoid_print
    print('  headers: $headers');

    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final resp = await _dio.get(
          '/online_status/',
          options: Options(headers: _getAuthHeaders()),
        );
        // ignore: avoid_print
        print('FriendApiClient.fetchFriends: response status=${resp.statusCode}');
        final data = resp.data as Map<String, dynamic>;
        final friends = (data['friends'] as List<dynamic>)
            .map((m) => Friend.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList();
        // ignore: avoid_print
        print('FriendApiClient.fetchFriends: got ${friends.length} friends');
        return friends;
      } catch (e, st) {
        lastError = e as Exception;
        // ignore: avoid_print
        print('FriendApiClient.fetchFriends ERROR (attempt $attempt/$_maxRetries): $e');

        // Don't retry on auth errors
        if (e is DioException && e.response?.statusCode == 401) {
          // ignore: avoid_print
          print('FriendApiClient: Auth error, not retrying');
          rethrow;
        }

        // Wait before retrying (except on last attempt)
        if (attempt < _maxRetries) {
          // ignore: avoid_print
          print('FriendApiClient: Retrying in ${_retryDelay.inSeconds}s...');
          await Future.delayed(_retryDelay);
        }
      }
    }

    // All retries failed
    // ignore: avoid_print
    print('FriendApiClient.fetchFriends: All retries failed');
    throw lastError ?? Exception('Failed to fetch friends');
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
