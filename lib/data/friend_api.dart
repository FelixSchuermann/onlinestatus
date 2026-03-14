import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  /// Works on desktop platforms and Android/iOS.
  void _configureSsl() {
    // Skip SSL configuration on web
    if (kIsWeb) return;

    try {
      final adapter = IOHttpClientAdapter();
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          // Accept all certificates (for self-signed certs)
          // In production, you should validate the certificate properly
          return true;
        };
        return client;
      };
      _dio.httpClientAdapter = adapter;
    } catch (e) {
      // SSL configuration failed, continuing without custom SSL settings
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

    Exception? lastError;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final resp = await _dio.get(
          '/online_status/',
          options: Options(headers: _getAuthHeaders()),
        );
        final data = resp.data as Map<String, dynamic>;
        final friends = (data['friends'] as List<dynamic>)
            .map((m) => Friend.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList();
        return friends;
      } catch (e) {
        lastError = e as Exception;

        // Don't retry on auth errors
        if (e is DioException && e.response?.statusCode == 401) {
          rethrow;
        }

        // Wait before retrying (except on last attempt)
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        }
      }
    }

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
      return false;
    }
  }

  /// Check if the client has a valid token configured.
  bool get hasToken => _token != null && _token!.isNotEmpty;
}
