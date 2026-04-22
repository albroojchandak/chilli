import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:chilli/services/alert_dispatcher.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  debugPrint("PushReceiver: BACKGROUND HANDLER CALLED");
  debugPrint("PushReceiver: message id: ${message.messageId}");
  debugPrint("PushReceiver: data: ${message.data}");
  debugPrint("PushReceiver: title: ${message.notification?.title}");

  try {
    debugPrint("PushReceiver: initializing Firebase in background");

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
      debugPrint("PushReceiver: Firebase initialized");
    } else {
      debugPrint("PushReceiver: Firebase already initialized");
    }

    debugPrint("PushReceiver: bootstrapping AlertDispatcher");
    await AlertDispatcher.bootstrap();
    debugPrint("PushReceiver: AlertDispatcher ready");

    final String messageType = message.data['type'] ?? '';
    debugPrint("PushReceiver: type = $messageType");

    if (messageType == 'incoming_call' ||
        messageType == 'incoming_audio_call') {
      final callerName = message.data['callerName'] ?? 'Someone';
      final callerAvatar = message.data['callerAvatar'] ?? '';
      final callerToken = message.data['callerToken'] ?? '';
      final callerId = message.data['callerId'] ?? '';
      final roomId = message.data['roomId'] ?? '';
      final isVideo =
          message.data['isVideoCall'] == 'true' ||
          message.data['isVideoCall'] == true ||
          message.data['isVideo'] == 'true' ||
          message.data['isVideo'] == true;
      final targetId = message.data['targetId'] ?? '';

      debugPrint(
        "PushReceiver: incoming call from $callerName to $targetId (room: $roomId)",
      );

      await AlertDispatcher.presentCallAlert(
        roomId: roomId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callerToken: callerToken,
        callerId: callerId,
        targetId: targetId,
        isVideoCall: isVideo,
      );

      debugPrint("PushReceiver: background alert shown");
    } else {
      debugPrint("PushReceiver: unhandled type: $messageType");
    }
  } catch (e, stackTrace) {
    debugPrint("PushReceiver: background handler error: $e");
    debugPrint("PushReceiver: stack: $stackTrace");
  }
}

class PushReceiver {
  bool isInCall = false;

  Function(Map<String, dynamic> data)? onCallDeclined;
  Function(String roomId)? onCallEnded;
  Function(Map<String, dynamic> data)? onIncomingCall;

  Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('PushReceiver: FCM permission granted');
    }

    await AlertDispatcher.bootstrap();

    String? token = await messaging.getToken();
    debugPrint('PushReceiver: FCM token = $token');

    if (token != null) {
      await persistToken(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(persistToken);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('PushReceiver: FOREGROUND MESSAGE');
      debugPrint('PushReceiver: id: ${message.messageId}');
      debugPrint('PushReceiver: data: ${message.data}');
      debugPrint('PushReceiver: title: ${message.notification?.title}');

      final String messageType = message.data['type'] ?? '';
      debugPrint('PushReceiver: type: $messageType');

      _dispatch(message.data);

      debugPrint('PushReceiver: foreground dispatched');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('PushReceiver: opened from notification: ${message.data}');
      _dispatch(message.data);
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint('PushReceiver: initial message: ${initialMessage.data}');
      _dispatch(initialMessage.data);
    }
  }

  void _dispatch(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = data['type'];
    final roomId = data['roomId'];

    if (type == 'call_declined') {
      onCallDeclined?.call(data);
    } else if (type == 'call_ended') {
      onCallEnded?.call(roomId);
    } else if (type == 'incoming_call') {
      onIncomingCall?.call(data);
    }
  }

  Future<String?> readToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  Future<void> persistToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });

        await FirebaseDatabase.instance.ref()
            .child('usersProfile')
            .child(user.uid)
            .update({
              'ft': token,
            });

        debugPrint('PushReceiver: token persisted across Firestore and RTDB');
      } else {
        debugPrint('PushReceiver: no user, token not persisted');
      }
    } catch (e) {
      debugPrint('PushReceiver: token persist error: $e');
    }
  }
}
