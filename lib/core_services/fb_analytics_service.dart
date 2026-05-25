import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Facebook App Events tracking
class FbAnalyticsService {
  static final FbAnalyticsService _instance =
      FbAnalyticsService._internal();
  factory FbAnalyticsService() => _instance;
  FbAnalyticsService._internal();

  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  /// Initialize Facebook App Events
  Future<void> initialize() async {
    try {
      // Set auto-logging to true (tracks app installs and sessions automatically)
      await _facebookAppEvents.setAutoLogAppEventsEnabled(true);

      // Set advertiser tracking enabled (for iOS 14+)
      await _facebookAppEvents.setAdvertiserTracking(enabled: true);

      debugPrint('✅ Facebook App Events initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Facebook App Events: $e');
    }
  }

  /// Track user registration/signup event
  /// This is a standard Facebook event for new user signups
  Future<void> trackSignup({
    required String method, // e.g., 'google', 'facebook', 'email'
    String? userId,
  }) async {
    try {
      await _facebookAppEvents.logCompletedRegistration(
        registrationMethod: method,
      );

      debugPrint(
        '📊 Facebook Event: Signup tracked (method: $method, userId: $userId)',
      );
    } catch (e) {
      debugPrint('❌ Error tracking signup: $e');
    }
  }

  /// Track user login event
  /// Custom event for existing user logins
  Future<void> trackLogin({
    required String method, // e.g., 'google', 'facebook', 'email'
    String? userId,
  }) async {
    try {
      // Facebook doesn't have a standard login event, so we use a custom event
      await _facebookAppEvents.logEvent(
        name: 'Login',
        parameters: {
          'method': method,
          'user_id': userId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint(
        '📊 Facebook Event: Login tracked (method: $method, userId: $userId)',
      );
    } catch (e) {
      debugPrint('❌ Error tracking login: $e');
    }
  }

  /// Track custom events
  Future<void> trackCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _facebookAppEvents.logEvent(
        name: eventName,
        parameters: parameters,
      );
      debugPrint('📊 Facebook Event: $eventName tracked');
    } catch (e) {
      debugPrint('❌ Error tracking custom event $eventName: $e');
    }
  }

  /// Track purchase events (for in-app purchases)
  Future<void> trackPurchase({
    required double amount,
    required String currency,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _facebookAppEvents.logPurchase(
        amount: amount,
        currency: currency,
        parameters: parameters,
      );
      debugPrint('📊 Facebook Event: Purchase tracked (₹$amount)');
    } catch (e) {
      debugPrint('❌ Error tracking purchase: $e');
    }
  }

  /// Track app install (automatically handled by SDK, but can be called manually)
  Future<void> trackAppInstall() async {
    try {
      await _facebookAppEvents.logEvent(name: 'AppInstall');
      debugPrint('📊 Facebook Event: App Install tracked');
    } catch (e) {
      debugPrint('❌ Error tracking app install: $e');
    }
  }

  /// Set user properties for better audience segmentation
  Future<void> setUserProperties({
    String? gender,
    String? language,
    String? location,
  }) async {
    try {
      // Log user properties as custom events for tracking
      if (gender != null) {
        await _facebookAppEvents.logEvent(
          name: 'UserProperty_Gender',
          parameters: {'gender': gender},
        );
      }
      if (language != null) {
        await _facebookAppEvents.logEvent(
          name: 'UserProperty_Language',
          parameters: {'language': language},
        );
      }
      if (location != null) {
        await _facebookAppEvents.logEvent(
          name: 'UserProperty_Location',
          parameters: {'location': location},
        );
      }

      debugPrint('📊 Facebook: User properties logged as events');
    } catch (e) {
      debugPrint('❌ Error setting user properties: $e');
    }
  }
}
