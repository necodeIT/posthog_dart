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

  /// Whether the application is in debug mode.
  final bool debug;

  /// The version of the application.
  final String version;

  final http.Client _httpClient;

  static PostHog? _instance;

  /// Logger for the PostHog client.
  @internal
  static Logger logger = Logger('PostHog');

  String? _distinctId;
  Map<String, dynamic> _userProperties = {};

  bool _enabled = true;
  bool _identifyCalled = false;

  String? _screen;

  /// The distinct ID for the current user.
  ///
  /// If [identify] has not been called, this will be a random UUID.
  String get distinctId => _distinctId ??= const Uuid().v4();

  /// Returns the singleton instance of the PostHog client.
  ///
  /// Make sure to call [PostHog.init] before using this method.
  factory PostHog() {
    if (_instance == null) {
      throw Exception(
          'PostHog is not initialized. Please call PostHog.init() first.');
    }

    return _instance!;
  }

  PostHog._({
    required this.apiKey,
    required this.host,
    required this.debug,
    required this.version,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Initializes the PostHog client.
  ///
  /// Must be called before using the client.
  static Future<void> init({
    required String apiKey,
    required String host,
    bool debug = false,
    String version = '1.0.0',
    http.Client? httpClient,
  }) async {
    _instance = PostHog._(
      apiKey: apiKey,
      host: host,
      httpClient: httpClient,
      debug: debug,
      version: version,
    );

    _instance!.capture(eventName: '\$identify');
  }

  /// Capture an event. This is the bread and butter of PostHog.
  ///
  /// https://posthog.com/docs/product-analytics/capture-events
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
      // if distinct_id is not provided in properties, use the one from the client
      if (properties?.containsKey('distinct_id') == false)
        'distinct_id': distinctId,
      'distinct_id': distinctId,
      'properties': {
        ...?properties,
        ..._userProperties,
        'version': version,
        if (debug) 'debug': debug,
        if (_screen != null) '\$pathname': _screen,
        if (_screen != null) '\$screen_name': _screen,
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

    final previousDistinctId = _distinctId;

    _distinctId = distinctId;
    _userProperties = properties ?? {};

    logger.fine('User identified: $distinctId');

    await capture(eventName: '\$identify', properties: properties);

    await capture(
      eventName: '\$set',
      properties: properties,
    );

    await capture(
      eventName: '\$pageview',
      properties: properties,
    );

    if (!_identifyCalled) {
      _identifyCalled = true;
      await capture(
        eventName: '\$create_alias',
        properties: {
          'alias': previousDistinctId,
          'distinct_id': distinctId,
        },
      );
    }
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

  /// Call this when a navigation event occurs.
  Future<void> screen(String screen) async {
    if (!_enabled) {
      logger.fine('Analytics disabled, skipping screen');
      return;
    }

    await capture(
      eventName: '\$screen',
      properties: {
        '\$pathname': screen,
        '\$screen_name': screen,
      },
    );

    _screen = screen;
  }

  /// Disposes of the client. This will close the underlying HTTP client.
  void dispose() {
    _httpClient.close();
    _instance = null;
  }
}
