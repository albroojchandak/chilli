import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:chilli/services/alert_dispatcher.dart';

// ✅ Top-level background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🔥🔥🔥 BACKGROUND HANDLER CALLED 🔥🔥🔥");
  debugPrint("📩 Message ID: ${message.messageId}");
  debugPrint("📩 Message data: ${message.data}");
  debugPrint("📩 Message notification: ${message.notification?.title}");

  try {
    debugPrint("🔧 Initializing Firebase in background...");

    // ✅ Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        // options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase initialized");
    } else {
      debugPrint("✅ Firebase already initialized");
    }

    // ✅ Initialize Notification Service in Background isolate
    debugPrint("🔧 Initializing AlertDispatcher...");
    await AlertDispatcher.initialize();
    debugPrint("✅ AlertDispatcher initialized");

    final String messageType = message.data['type'] ?? '';
    debugPrint("📩 Message type: $messageType");

    // ✅ ALWAYS show notification in background
    // This handler ONLY runs when app is backgrounded/terminated
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
        "📞 BACKGROUND: Incoming call from $callerName to target $targetId (Room: $roomId)",
      );
      debugPrint("🔔 Showing background notification...");

      await AlertDispatcher.showCallNotification(
        roomId: roomId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        callerToken: callerToken,
        callerId: callerId,
        targetId: targetId, // ✅ Pass targetId for RTDB write
        isVideoCall: isVideo,
      );

      debugPrint("✅ Background notification shown");
    } else {
      debugPrint("⚠️ Unknown message type: $messageType");
    }
  } catch (e, stackTrace) {
    debugPrint("❌❌❌ Error in background handler: $e");
    debugPrint("Stack trace: $stackTrace");
  }
}

class PushReceiver {
  bool isInCall = false;

  Function(Map<String, dynamic> data)? onCallDeclined;
  Function(Map<String, dynamic> data)? onChatDeclined;
  Function(String roomId)? onCallEnded;
  Function(Map<String, dynamic> data)? onIncomingCall;
  Function(Map<String, dynamic> data)? onIncomingChat;

  // Initialize FCM
  Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted FCM permission');
    }

    // ✅ Initialize Notification Service (for Foreground/Background consistency)
    await AlertDispatcher.initialize();

    // Get token
    String? token = await messaging.getToken();
    debugPrint('FCM Token: $token');

    // ✅ Sync Token with Firestore
    if (token != null) {
      await saveTokenToFirestore(token);
    }

    // ✅ Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(saveTokenToFirestore);

    // Register Background Handler (now in main.dart)
    // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔥🔥🔥 FOREGROUND MESSAGE RECEIVED 🔥🔥🔥');
      debugPrint('📩 Message ID: ${message.messageId}');
      debugPrint('📩 Message data: ${message.data}');
      debugPrint('📩 Message notification: ${message.notification?.title}');

      final String messageType = message.data['type'] ?? '';
      debugPrint('📩 Message type: $messageType');

      // ✅ Handle message via callbacks (no notification in foreground)
      // Notification is ONLY shown when app is backgrounded (by background handler)
      _handleMessage(message.data);

      debugPrint(
        '✅ FOREGROUND: Message handled via callbacks (no notification)',
      );
    });

    // Handle background/terminated messages tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM Message Opened App: ${message.data}');
      _handleMessage(message.data);
    });

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM Initial Message: ${initialMessage.data}');
      _handleMessage(initialMessage.data);
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    final type = data['type'];
    final roomId = data['roomId'];

    if (type == 'call_declined') {
      onCallDeclined?.call(data);
    } else if (type == 'chat_declined') {
      onChatDeclined?.call(data);
    } else if (type == 'call_ended') {
      onCallEnded?.call(roomId);
    } else if (type == 'incoming_call') {
      // Pass the map directly
      onIncomingCall?.call(data);
    } else if (type == 'incoming_chat') {
      onIncomingChat?.call(data);
    }
  }

  // Get current token
  Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  // ✅ Save Token to Firestore
  Future<void> saveTokenToFirestore(String token) async {
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
        debugPrint('✅ FCM Token saved to Firestore for ${user.uid}');
      } else {
        debugPrint('⚠️ Cannot save FCM Token: No user logged in');
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM Token to Firestore: $e');
    }
  }
}


