library posthog_dart;

import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

/// PostHog client for Dart using the HTTP API.
class PostHog {
  /// The API key for the PostHog project.
  final String apiKey;

  /// The host for the PostHog project.
  final String host;

  final http.Client _httpClient;

  static PostHog? _instance;

  /// Logger for the PostHog client.
  @internal
  static Logger logger = Logger('PostHog');

  String? _distinctId;
  Map<String, dynamic> _userProperties = {};

  bool _enabled = true;

  /// The distinct ID for the current user.
  ///
  /// If [identify] has not been called, this will be a random UUID.
  String get distinctId => _distinctId ??= const Uuid().v4();

  /// Returns the singleton instance of the PostHog client.
  ///
  /// Make sure to call [PostHog.init] before using this method.
  factory PostHog() {
    if (_instance == null) {
      throw Exception('PostHog is not initialized. Please call PostHog.init() first.');
    }

    return _instance!;
  }

  PostHog._({
    required this.apiKey,
    required this.host,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Initializes the PostHog client.
  ///
  /// Must be called before using the client.
  static void init({
    required String apiKey,
    required String host,
    http.Client? httpClient,
  }) {
    _instance = PostHog._(
      apiKey: apiKey,
      host: host,
      httpClient: httpClient,
    );
  }

  /// Capture an event. This is the bread and butter of PostHog.
  ///
  /// hhttps://posthog.com/docs/product-analytics/capture-events
  Future<void> capture({
    required String eventName,
    Map<String, dynamic>? properties,
  }) async {
    if (!_enabled) {
      logger.fine('Analytics disabled, skipping capture');
      return;
    }

    final url = Uri.parse('$host/capture/');

    final payload = {
      'api_key': apiKey,
      'event': eventName,
      'distinct_id': distinctId,
      'properties': {
        ...?properties,
        ..._userProperties,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send event: ${response.body}');
      }

      logger.fine('Event sent: $eventName');
    } catch (e, s) {
      logger.warning('Failed to send event: $eventName', e, s);
    }
  }

  /// Identify a user by their distinct ID. This is used to associate events with a specific user.
  ///
  /// https://posthog.com/docs/product-analytics/identify
  Future<void> identify({
    required String distinctId,
    Map<String, dynamic>? properties,
  }) async {
    if (!_enabled) {
      logger.fine('Analytics disabled, skipping identify');
      return;
    }

    _distinctId = distinctId;
    _userProperties = properties ?? {};

    logger.fine('User identified: $distinctId');
  }

  /// Resets the client. This will clear the distinct ID.
  void reset() {
    _distinctId = null;
    _userProperties = {};
  }

  /// Enables analytics.
  void enable() {
    logger.fine('Analytics enabled');

    _enabled = true;
  }

  /// Disables analytics.
  void disable() {
    logger.fine('Analytics disabled');

    _enabled = false;
  }

  /// Disposes of the client. This will close the underlying HTTP client.
  void dispose() {
    _httpClient.close();
    _instance = null;
  }
}
