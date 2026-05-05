/// API service for communicating with the Python fatigue detection backend.
///
/// Implemented as a **singleton** so that every screen in the app shares
/// the same instance — and therefore the same [_baseUrl].  Updating the
/// URL via [updateBaseUrl] immediately affects all future API calls
/// regardless of which screen triggered the update.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/fatigue_data.dart';

class ApiService {
  // ── Singleton plumbing ────────────────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal()
      : _baseUrl = 'http://172.16.232.146:5000';

  // ── State ─────────────────────────────────────────────────────────────────

  /// Base URL of the Flask backend.
  /// Always kept trimmed; never falls back to a default after an update.
  String _baseUrl;

  /// Number of consecutive failed requests.
  int _consecutiveFailures = 0;

  /// Whether the backend is currently considered online.
  bool _isOnline = false;

  /// Timeout for regular data fetches.
  static const Duration _fetchTimeout = Duration(seconds: 5);

  /// Timeout for quick health checks.
  static const Duration _healthTimeout = Duration(seconds: 3);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Update the backend URL at runtime.
  ///
  /// The new URL is trimmed and replaces the old one immediately.
  /// Consecutive-failure counter is also reset so the next request
  /// gets a clean slate.
  void updateBaseUrl(String newUrl) {
    final trimmed = newUrl.trim();
    developer.log(
      '[ApiService] updateBaseUrl: "$_baseUrl" → "$trimmed"',
      name: 'ApiService',
    );
    _baseUrl = trimmed;
    _consecutiveFailures = 0;
  }

  String get baseUrl => _baseUrl;

  /// Whether the backend is considered online based on recent requests.
  bool get isOnline => _isOnline;

  /// Number of consecutive failures since last success.
  int get consecutiveFailures => _consecutiveFailures;

  /// Fetch the current fatigue status from the backend.
  ///
  /// Returns a [FatigueData] object on success, or `null` on failure.
  Future<FatigueData?> fetchStatus() async {
    final url = '$_baseUrl/status';
    developer.log('[ApiService] GET $url', name: 'ApiService');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(_fetchTimeout);

      developer.log(
        '[ApiService] Response ${response.statusCode} from $url',
        name: 'ApiService',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _consecutiveFailures = 0;
        _isOnline = true;
        return FatigueData.fromJson(json);
      } else {
        _consecutiveFailures++;
        _isOnline = false;
        return null;
      }
    } on TimeoutException {
      developer.log('[ApiService] TIMEOUT on $url', name: 'ApiService');
      _consecutiveFailures++;
      _isOnline = false;
      return null;
    } catch (e) {
      developer.log(
        '[ApiService] ERROR on $url: $e',
        name: 'ApiService',
      );
      _consecutiveFailures++;
      _isOnline = false;
      return null;
    }
  }

  /// Check if the backend is reachable.
  Future<bool> checkHealth() async {
    final url = '$_baseUrl/health';
    developer.log('[ApiService] GET $url', name: 'ApiService');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(_healthTimeout);

      developer.log(
        '[ApiService] Response ${response.statusCode} from $url',
        name: 'ApiService',
      );

      _isOnline = response.statusCode == 200;
      if (_isOnline) _consecutiveFailures = 0;
      return _isOnline;
    } catch (e) {
      developer.log(
        '[ApiService] ERROR on $url: $e',
        name: 'ApiService',
      );
      _isOnline = false;
      return false;
    }
  }

  /// Reset backend counters.
  Future<bool> resetCounters() async {
    final url = '$_baseUrl/reset';
    developer.log('[ApiService] POST $url', name: 'ApiService');

    try {
      final response = await http
          .post(Uri.parse(url))
          .timeout(_healthTimeout);

      developer.log(
        '[ApiService] Response ${response.statusCode} from $url',
        name: 'ApiService',
      );

      return response.statusCode == 200;
    } catch (e) {
      developer.log(
        '[ApiService] ERROR on $url: $e',
        name: 'ApiService',
      );
      return false;
    }
  }
}
