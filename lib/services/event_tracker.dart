import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class EventTracker {
  static final EventTracker _instance = EventTracker._internal();
  factory EventTracker() => _instance;
  EventTracker._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver buildObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  Future<void> recordLogin({
    required String method,
    String? userId,
  }) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
      debugPrint('EventTracker: login recorded ($method)');
    } catch (e) {
      debugPrint('EventTracker: login record failed: $e');
    }
  }

  Future<void> recordSignup({
    required String method,
    String? userId,
  }) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }
      debugPrint('EventTracker: signup recorded ($method)');
    } catch (e) {
      debugPrint('EventTracker: signup record failed: $e');
    }
  }

  Future<void> recordPurchase({
    required double value,
    required String currency,
    required String transactionId,
    String? itemId,
    String? itemName,
    String? paymentMethod,
    int? quantity,
  }) async {
    try {
      await _analytics.logPurchase(
        currency: currency,
        value: value,
        transactionId: transactionId,
        affiliation: 'Chilli App',
        items: itemId != null
            ? [
                AnalyticsEventItem(
                  itemId: itemId,
                  itemName: itemName ?? itemId,
                  price: value,
                  quantity: quantity ?? 1,
                  currency: currency,
                ),
              ]
            : null,
      );

      await _analytics.logEvent(
        name: 'in_app_purchase',
        parameters: {
          'value': value,
          'currency': currency,
          'transaction_id': transactionId,
          'payment_method': paymentMethod ?? 'unknown',
          'item_id': itemId ?? 'unknown',
          'item_name': itemName ?? 'unknown',
        },
      );

      debugPrint('EventTracker: purchase recorded (₹$value)');
    } catch (e) {
      debugPrint('EventTracker: purchase record failed: $e');
    }
  }

  Future<void> recordCartAdd({
    required String itemId,
    required String itemName,
    required double value,
    required String currency,
  }) async {
    try {
      await _analytics.logAddToCart(
        currency: currency,
        value: value,
        items: [
          AnalyticsEventItem(
            itemId: itemId,
            itemName: itemName,
            price: value,
            quantity: 1,
            currency: currency,
          ),
        ],
      );
      debugPrint('EventTracker: cart add recorded ($itemName)');
    } catch (e) {
      debugPrint('EventTracker: cart add failed: $e');
    }
  }

  Future<void> recordCheckoutStart({
    required double value,
    required String currency,
    required String itemId,
    required String itemName,
  }) async {
    try {
      await _analytics.logBeginCheckout(
        value: value,
        currency: currency,
        items: [
          AnalyticsEventItem(
            itemId: itemId,
            itemName: itemName,
            price: value,
            quantity: 1,
            currency: currency,
          ),
        ],
      );
      debugPrint('EventTracker: checkout start recorded (₹$value)');
    } catch (e) {
      debugPrint('EventTracker: checkout start failed: $e');
    }
  }

  Future<void> emitEvent({
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: eventName, parameters: parameters);
      debugPrint('EventTracker: event emitted ($eventName)');
    } catch (e) {
      debugPrint('EventTracker: event emit failed: $e');
    }
  }

  Future<void> setProfileAttribute({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      debugPrint('EventTracker: attribute set ($name: $value)');
    } catch (e) {
      debugPrint('EventTracker: attribute set failed: $e');
    }
  }

  Future<void> applyProfileAttributes({
    String? gender,
    String? language,
    String? accountType,
    String? userSegment,
  }) async {
    try {
      if (gender != null) {
        await setProfileAttribute(name: 'gender', value: gender);
      }
      if (language != null) {
        await setProfileAttribute(name: 'language', value: language);
      }
      if (accountType != null) {
        await setProfileAttribute(name: 'account_type', value: accountType);
      }
      if (userSegment != null) {
        await setProfileAttribute(name: 'user_segment', value: userSegment);
      }
      debugPrint('EventTracker: profile attributes applied');
    } catch (e) {
      debugPrint('EventTracker: profile attributes failed: $e');
    }
  }

  Future<void> recordAppOpen() async {
    try {
      await _analytics.logAppOpen();
      debugPrint('EventTracker: app open recorded');
    } catch (e) {
      debugPrint('EventTracker: app open failed: $e');
    }
  }

  Future<void> recordScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('EventTracker: screen view recorded ($screenName)');
    } catch (e) {
      debugPrint('EventTracker: screen view failed: $e');
    }
  }

  Future<void> eraseUserSession() async {
    try {
      await _analytics.setUserId(id: null);
      debugPrint('EventTracker: user session erased');
    } catch (e) {
      debugPrint('EventTracker: erase session failed: $e');
    }
  }

  Future<void> toggleDataCollection(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      debugPrint('EventTracker: collection ${enabled ? 'on' : 'off'}');
    } catch (e) {
      debugPrint('EventTracker: toggle collection failed: $e');
    }
  }
}
