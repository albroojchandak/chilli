import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

class NotificationTransmitter {
  static const String _projectId = 'knect-84f31';

  final List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  Future<String?> _acquireAccessToken() async {
    try {
      final serviceAccountJson = await rootBundle.loadString(
        'assets/service-account.json',
      );
      final serviceAccountMap =
          json.decode(serviceAccountJson) as Map<String, dynamic>;

      debugPrint('NotificationTransmitter: service account loaded');

      final accountCredentials = ServiceAccountCredentials.fromJson(
        serviceAccountMap,
      );

      debugPrint('NotificationTransmitter: acquiring token');
      final client = await clientViaServiceAccount(
        accountCredentials,
        _scopes,
      ).timeout(const Duration(seconds: 10));

      final accessToken = client.credentials.accessToken.data;
      client.close();

      debugPrint('NotificationTransmitter: token acquired');
      return accessToken;
    } catch (e, stackTrace) {
      debugPrint('NotificationTransmitter: token error: $e');
      debugPrint('NotificationTransmitter: stack: $stackTrace');
      return null;
    }
  }

  Future<void> _transmit({
    required String targetToken,
    required Map<String, String> data,
    Map<String, String>? notification,
  }) async {
    final token = await _acquireAccessToken();
    if (token == null) return;

    final url =
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

    final body = {
      'message': {
        'token': targetToken,
        'data': data,
        if (notification != null) 'notification': notification,
        'android': {
          'priority': 'high',
          'ttl': '0s',
        },
      },
    };

    try {
      debugPrint('NotificationTransmitter: sending FCM message');
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('NotificationTransmitter: response ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('NotificationTransmitter: error body: ${response.body}');
      } else {
        debugPrint('NotificationTransmitter: message sent');
      }
    } catch (e) {
      debugPrint('NotificationTransmitter: send error: $e');
    }
  }

  Future<void> dispatchCallInvite({
    required String targetToken,
    required Map<String, dynamic> callerData,
    required String roomId,
    required bool isVideoCall,
    required String targetId,
  }) async {
    debugPrint(
      'NotificationTransmitter: dispatching call invite to $targetToken (target: $targetId)',
    );

    final callerName = callerData['username']?.toString() ?? 'User';

    await _transmit(
      targetToken: targetToken,
      data: {
        'type': 'incoming_call',
        'roomId': roomId,
        'callerName': callerName,
        'callerAvatar': callerData['avatarUrl']?.toString() ?? '',
        'callerToken': callerData['fcmToken']?.toString() ?? targetToken,
        'callerId': callerData['uid']?.toString() ?? '',
        'targetId': targetId,
        'isVideoCall': isVideoCall.toString(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    );
  }

  Future<void> dispatchCallEnd({
    required String targetToken,
    required String roomId,
  }) async {
    debugPrint('NotificationTransmitter: dispatching call end to $targetToken');
    await _transmit(
      targetToken: targetToken,
      data: {'type': 'call_ended', 'roomId': roomId},
    );
  }

  Future<void> dispatchCallDeclined({
    required String targetToken,
    required String roomId,
    required String declinedBy,
  }) async {
    debugPrint('NotificationTransmitter: dispatching declined to $targetToken');
    await _transmit(
      targetToken: targetToken,
      data: {
        'type': 'call_declined',
        'roomId': roomId,
        'declinedBy': declinedBy,
      },
    );
  }

  Future<void> dispatchChatInvite({
    required String targetToken,
    required String senderName,
    required String senderAvatar,
    required String roomId,
  }) async {
    debugPrint('NotificationTransmitter: dispatching chat invite to $targetToken');
    await _transmit(
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
