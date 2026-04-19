import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

class FbInsightsReporter {
  static final FbInsightsReporter _instance = FbInsightsReporter._internal();
  factory FbInsightsReporter() => _instance;
  FbInsightsReporter._internal();

  final FacebookAppEvents _fbAppEvents = FacebookAppEvents();

  Future<void> setup() async {
    try {
      await _fbAppEvents.setAutoLogAppEventsEnabled(true);
      await _fbAppEvents.setAdvertiserTracking(enabled: true);
      debugPrint('FbInsightsReporter: setup complete');
    } catch (e) {
      debugPrint('FbInsightsReporter: setup error: $e');
    }
  }

  Future<void> logSignup({
    required String method,
    String? userId,
  }) async {
    try {
      await _fbAppEvents.logCompletedRegistration(
        registrationMethod: method,
      );
      debugPrint('FbInsightsReporter: signup logged ($method, $userId)');
    } catch (e) {
      debugPrint('FbInsightsReporter: signup log error: $e');
    }
  }

  Future<void> logLogin({
    required String method,
    String? userId,
  }) async {
    try {
      await _fbAppEvents.logEvent(
        name: 'Login',
        parameters: {
          'method': method,
          'user_id': userId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('FbInsightsReporter: login logged ($method, $userId)');
    } catch (e) {
      debugPrint('FbInsightsReporter: login log error: $e');
    }
  }

  Future<void> logEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _fbAppEvents.logEvent(
        name: eventName,
        parameters: parameters,
      );
      debugPrint('FbInsightsReporter: event logged ($eventName)');
    } catch (e) {
      debugPrint('FbInsightsReporter: event log error ($eventName): $e');
    }
  }

  Future<void> logPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _fbAppEvents.logPurchase(
        amount: amount,
        currency: currency,
        parameters: parameters,
      );
      debugPrint('FbInsightsReporter: purchase logged (₹$amount)');
    } catch (e) {
      debugPrint('FbInsightsReporter: purchase log error: $e');
    }
  }

  Future<void> logInstall() async {
    try {
      await _fbAppEvents.logEvent(name: 'AppInstall');
      debugPrint('FbInsightsReporter: install logged');
    } catch (e) {
      debugPrint('FbInsightsReporter: install log error: $e');
    }
  }

  Future<void> setAttributes({
    String? gender,
    String? language,
    String? location,
  }) async {
    try {
      if (gender != null) {
        await _fbAppEvents.logEvent(
          name: 'UserProperty_Gender',
          parameters: {'gender': gender},
        );
      }
      if (language != null) {
        await _fbAppEvents.logEvent(
          name: 'UserProperty_Language',
          parameters: {'language': language},
        );
      }
      if (location != null) {
        await _fbAppEvents.logEvent(
          name: 'UserProperty_Location',
          parameters: {'location': location},
        );
      }
      debugPrint('FbInsightsReporter: attributes set');
    } catch (e) {
      debugPrint('FbInsightsReporter: setAttributes error: $e');
    }
  }
}
