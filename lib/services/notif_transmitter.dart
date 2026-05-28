import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

class NotifTransmitter {
  static const String _projectId = 'chilli-84f31';

  final List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  /// Get Access Token for FCM V1 API
  Future<String?> _getAccessToken() async {
    try {
      // Load service account JSON from assets
      final serviceAccountJson = await rootBundle.loadString(
        'assets/service-account.json',
      );
      final serviceAccountMap =
          json.decode(serviceAccountJson) as Map<String, dynamic>;

      debugPrint('FCM: Service account loaded from assets');

      // Create credentials from the full JSON (includes all required fields)
      final accountCredentials = ServiceAccountCredentials.fromJson(
        serviceAccountMap,
      );

      debugPrint('FCM: Getting Access Token...');
      final client = await clientViaServiceAccount(
        accountCredentials,
        _scopes,
      ).timeout(const Duration(seconds: 10));

      final accessToken = client.credentials.accessToken.data;
      client.close();

      debugPrint('FCM: Access Token generated successfully.');
      return accessToken;
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating FCM Access Token: $e');
      debugPrint('StackTrace: $stackTrace');
      return null;
    }
  }

  /// Helper to send FCM V1 Message
  Future<void> _sendFcmMessage({
    required String targetToken,
    required Map<String, String> data,
    Map<String, String>? notification, // ✅ Added notification payload
  }) async {
    final token = await _getAccessToken();
    if (token == null) return;

    final url =
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

    final body = {
      'message': {
        'token': targetToken,
        'data': data,
        // ✅ CRITICAL: Add notification payload for background delivery
        if (notification != null) 'notification': notification,
        // ✅ Android Specific Configuration for High Priority
        'android': {
          'priority': 'high',
          'ttl': '0s', // Immediate delivery
        },
      },
    };

    try {
      debugPrint('FCM: Sending HTTP POST to V1 API...');
      debugPrint('FCM: Has notification payload: ${notification != null}');
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10)); // ✅ Timeout added

      debugPrint('FCM V1 Response: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('FCM V1 Error Body: ${response.body}');
      } else {
        debugPrint('✅ FCM message sent successfully');
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM V1 message: $e');
    }
  }

  Future<void> sendCallNotification({
    required String targetToken,
    required Map<String, dynamic> callerData,
    required String roomId,
    required bool isVideoCall,
    required String targetId, // ✅ Pass target user ID for background handling
  }) async {
    debugPrint(
      'FCM: Sending call notification to $targetToken (Target UID: $targetId)',
    );

    final callerName = callerData['username']?.toString() ?? 'User';

    await _sendFcmMessage(
      targetToken: targetToken,
      data: {
        'type': 'incoming_call',
        'roomId': roomId,
        'callerName': callerName,
        'callerAvatar': callerData['avatarUrl']?.toString() ?? '',
        'callerToken': callerData['fcmToken']?.toString() ?? targetToken,
        'callerId': callerData['uid']?.toString() ?? '',
        'targetId': targetId, // ✅ Vital for background RTDB logic
        'isVideoCall': isVideoCall.toString(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
      // ❌ NO notification payload - background handler creates custom notification with buttons
    );
  }

  Future<void> sendCallEndNotification({
    required String targetToken,
    required String roomId,
  }) async {
    debugPrint('FCM: Sending call end notification to $targetToken');
    await _sendFcmMessage(
      targetToken: targetToken,
      data: {'type': 'call_ended', 'roomId': roomId},
    );
  }

  Future<void> sendCallDeclinedNotification({
    required String targetToken,
    required String roomId,
    required String declinedBy,
  }) async {
    debugPrint('FCM: Sending call declined notification to $targetToken');
    await _sendFcmMessage(
      targetToken: targetToken,
      data: {
        'type': 'call_declined',
        'roomId': roomId,
        'declinedBy': declinedBy,
      },
    );
  }

  Future<void> sendChatNotification({
    required String targetToken,
    required String senderName,
    required String senderAvatar,
    required String roomId,
  }) async {
    debugPrint('FCM: Sending chat notification to $targetToken');
    // Note: For chats we might want a notification block, keeping it simple data-only for now
    // to match current structure, or you can add notification fields if desired.
    // The previous implementation sent a notification block.
    // V1 handles notification blocks differently (inside 'message').
    // For now, let's stick to consistent Data messages + Local Notifications if app is open,
    // or add 'notification' if we want system tray.

    // To enable system tray notifications automatically:
    /*
      'notification': {
          'title': 'New Chat Request',
          'body': '$senderName wants to chat with you',
      }
    */
    // For consistency with specific request logic, sending Data only.

    await _sendFcmMessage(
      targetToken: targetToken,
      data: {
        'type': 'incoming_chat',
        'roomId': roomId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    );
  }
}

