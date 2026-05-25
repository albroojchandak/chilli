import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Analytics tracking for Google Ads
/// This tracks conversions that can be imported into Google Ads
class AnalyticsTrackingService {
  static final AnalyticsTrackingService _instance =
      AnalyticsTrackingService._internal();
  factory AnalyticsTrackingService() => _instance;
  AnalyticsTrackingService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver getAnalyticsObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  /// Track user login event
  /// This is a predefined Firebase event that Google Ads can import
  Future<void> trackLogin({
    required String method, // 'google', 'phone', 'email', etc.
    String? userId,
  }) async {
    try {
      await _analytics.logLogin(loginMethod: method);

      // Set user ID for better tracking across sessions
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }

      debugPrint('📊 Firebase Analytics: Login tracked (method: $method)');
    } catch (e) {
      debugPrint('❌ Error tracking login to Firebase Analytics: $e');
    }
  }

  /// Track user signup/registration event
  /// This is a predefined Firebase event that Google Ads can import
  Future<void> trackSignup({
    required String method, // 'google', 'phone', 'email', etc.
    String? userId,
  }) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);

      // Set user ID for better tracking
      if (userId != null) {
        await _analytics.setUserId(id: userId);
      }

      debugPrint('📊 Firebase Analytics: Signup tracked (method: $method)');
    } catch (e) {
      debugPrint('❌ Error tracking signup to Firebase Analytics: $e');
    }
  }

  /// Track purchase/recharge event
  /// This is THE MOST IMPORTANT event for Google Ads conversion tracking
  Future<void> trackPurchase({
    required double value, // Amount in rupees
    required String currency, // 'INR', 'USD', etc.
    required String transactionId, // Unique transaction ID
    String? itemId, // Package ID (e.g., 'coins_100')
    String? itemName, // Package name (e.g., '100 Coins')
    String? paymentMethod, // 'upi', 'card', 'razorpay', etc.
    int? quantity,
  }) async {
    try {
      // Log the purchase event
      await _analytics.logPurchase(
        currency: currency,
        value: value,
        transactionId: transactionId,
        affiliation: 'chilli App',
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

      // Also log as in_app_purchase for additional tracking
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

      debugPrint(
        '📊 Firebase Analytics: Purchase tracked (₹$value, txn: $transactionId)',
      );
    } catch (e) {
      debugPrint('❌ Error tracking purchase to Firebase Analytics: $e');
    }
  }

  /// Track add to cart (when user selects a package but hasn't paid yet)
  Future<void> trackAddToCart({
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

      debugPrint('📊 Firebase Analytics: Add to cart tracked ($itemName)');
    } catch (e) {
      debugPrint('❌ Error tracking add to cart: $e');
    }
  }

  /// Track when user initiates checkout
  Future<void> trackBeginCheckout({
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

      debugPrint('📊 Firebase Analytics: Begin checkout tracked (₹$value)');
    } catch (e) {
      debugPrint('❌ Error tracking begin checkout: $e');
    }
  }

  /// Track custom events (for app-specific tracking)
  Future<void> trackCustomEvent({
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: eventName, parameters: parameters);

      debugPrint('📊 Firebase Analytics: Custom event tracked ($eventName)');
    } catch (e) {
      debugPrint('❌ Error tracking custom event: $e');
    }
  }

  /// Set user properties for audience segmentation in Google Ads
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);

      debugPrint('📊 Firebase Analytics: User property set ($name: $value)');
    } catch (e) {
      debugPrint('❌ Error setting user property: $e');
    }
  }

  /// Set multiple user properties at once
  Future<void> setUserProperties({
    String? gender,
    String? language,
    String? accountType, // 'free', 'paid', 'premium'
    String? userSegment, // 'new', 'active', 'churned'
  }) async {
    try {
      if (gender != null) {
        await setUserProperty(name: 'gender', value: gender);
      }
      if (language != null) {
        await setUserProperty(name: 'language', value: language);
      }
      if (accountType != null) {
        await setUserProperty(name: 'account_type', value: accountType);
      }
      if (userSegment != null) {
        await setUserProperty(name: 'user_segment', value: userSegment);
      }

      debugPrint('📊 Firebase Analytics: Multiple user properties set');
    } catch (e) {
      debugPrint('❌ Error setting user properties: $e');
    }
  }

  /// Track app open event
  Future<void> trackAppOpen() async {
    try {
      await _analytics.logAppOpen();
      debugPrint('📊 Firebase Analytics: App open tracked');
    } catch (e) {
      debugPrint('❌ Error tracking app open: $e');
    }
  }

  /// Track screen views
  Future<void> trackScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );

      debugPrint('📊 Firebase Analytics: Screen view tracked ($screenName)');
    } catch (e) {
      debugPrint('❌ Error tracking screen view: $e');
    }
  }

  /// Clear user data (on logout)
  Future<void> clearUserData() async {
    try {
      await _analytics.setUserId(id: null);
      debugPrint('📊 Firebase Analytics: User data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing user data: $e');
    }
  }

  /// Enable/disable analytics collection
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      debugPrint(
        '📊 Firebase Analytics: Collection ${enabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('❌ Error setting analytics collection: $e');
    }
  }
}
