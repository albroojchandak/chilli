import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../services/notif_transmitter.dart';

class AlertDispatcher {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    // ✅ Create Android Notification Channel (Required for Android 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'call_channel_id', // Must match the ID in showCallNotification
      'Incoming Calls',
      description: 'Notifications for incoming video/audio calls',
      importance: Importance.max,
      playSound: true,
      // sound: RawResourceAndroidNotificationSound('ringtone'),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
    print('✅ Notification Service Initialized');
  }

  // Handle notification tap
  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) async {
    print('📱 Notification tapped: ${response.actionId}');

    if (response.payload == null) return;

    final data = jsonDecode(response.payload!);
    final actionId = response.actionId ?? '';

    if (actionId.startsWith('answer_')) {
      // User pressed Answer button
      await _handleAnswerCall(data);
    } else if (actionId.startsWith('decline_')) {
      // User pressed Decline button
      await _handleDeclineCall(data);
    } else {
      // User tapped notification body (treat as answer)
      await _handleAnswerCall(data);
    }
  }

  // Show call notification with Answer/Decline buttons
  static Future<void> showCallNotification({
    required String roomId,
    required String callerName,
    required String callerAvatar,
    required String callerToken,
    required String callerId,
    required String targetId, // ✅ New: target user ID
    required bool isVideoCall,
  }) async {
    final payload = jsonEncode({
      'roomId': roomId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'callerToken': callerToken,
      'callerId': callerId,
      'targetId': targetId, // ✅ Include in payload
      'isVideoCall': isVideoCall,
    });

    // Android notification with action buttons
    // Android notification with action buttons
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'call_channel_id',
          'Incoming Calls',
          channelDescription: 'Notifications for incoming video/audio calls',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // Shows as heads-up notification
          category: AndroidNotificationCategory.call,
          ongoing: true, // Makes it non-dismissable
          autoCancel: false,
          playSound: true,
          // sound: const RawResourceAndroidNotificationSound('ringtone'),
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'decline_$roomId',
              'Decline',
              showsUserInterface: false,
              cancelNotification: true,
              titleColor: const Color(0xFFFF0000),
            ),
            AndroidNotificationAction(
              'answer_$roomId',
              'Answer',
              showsUserInterface: true,
              cancelNotification: true,
              titleColor: const Color(0xFF00FF00),
            ),
          ],
        );

    // iOS notification
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel:
          InterruptionLevel.timeSensitive, // Critical for iOS calls
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Force re-create notification ID to ensure updates
    // Use a fixed ID per room to avoid stacking multiple updates for same call
    await _notificationsPlugin.show(
      id: roomId.hashCode,
      title: isVideoCall ? '📹 Incoming Video Call' : '📞 Incoming Call',
      body: '$callerName is calling...',
      notificationDetails: notificationDetails,
      payload: payload,
    );

    print('🔔 Call notification shown for $callerName (Room: $roomId)');
  }

  // Cancel/dismiss a notification
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  // Store call in history
  static Future<void> _storeCallInHistory(
    Map<String, dynamic> data,
    String status,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final callData = {
      'roomId': data['roomId'],
      'name': data['callerName'],
      'avatar': data['callerAvatar'],
      'token': data['callerToken'],
      'type': data['isVideoCall'] == true ? 'video' : 'audio',
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final historyJson = prefs.getString('call_history') ?? '[]';
    List<dynamic> history = jsonDecode(historyJson);
    history.insert(0, callData);
    if (history.length > 50) history = history.sublist(0, 50);

    await prefs.setString('call_history', jsonEncode(history));
  }

  // Handle answer call action
  static Future<void> _handleAnswerCall(Map<String, dynamic> data) async {
    print('✅ User answered the call from notification');
    await _storeCallInHistory(data, 'incoming');

    final roomId = data['roomId'];
    final targetId = data['targetId'];

    // Cancel the notification
    if (roomId != null) {
      await cancelNotification(roomId.hashCode);

      // ✅ Store in SharedPreferences as a direct signal for Cold Start
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_answered_roomId', roomId.toString());
        print('💾 SharedPreferences: Marked room $roomId as answered');
      } catch (e) {
        print('❌ Error saving answer signal to Prefs: $e');
      }
    }

    // Write FULL call data to RTDB so app can auto-join when it opens
    try {
      // Use targetId from payload if available (robust for background isolates)
      final uid = targetId ?? FirebaseAuth.instance.currentUser?.uid;

      if (uid != null && roomId != null) {
        // Store the COMPLETE call data including caller info
        await FirebaseDatabase.instance
            .ref()
            .child('pending_calls')
            .child(uid)
            .child(roomId)
            .set({
              'accepted': true,
              'acceptedAt': ServerValue.timestamp,
              'roomId': roomId,
              'callerName': data['callerName'] ?? 'Unknown',
              'callerAvatar': data['callerAvatar'] ?? '',
              'callerToken': data['callerToken'] ?? '',
              'callerId': data['callerId'] ?? '',
              'isVideoCall': data['isVideoCall'] ?? false,
            });

        print('✅ Full call data written to RTDB for user $uid node: $roomId');
      } else {
        print(
          '⚠️ AlertDispatcher: Cannot write to RTDB, UID or RoomID missing',
        );
      }
    } catch (e) {
      print('❌ Error writing call acceptance: $e');
    }
  }

  // Handle decline call action
  static Future<void> _handleDeclineCall(Map<String, dynamic> data) async {
    print('❌ User declined the call');
    await _storeCallInHistory(data, 'missed');

    // Send decline notification back to caller
    final fcmSender = NotifTransmitter();
    await fcmSender.sendCallDeclinedNotification(
      targetToken: data['callerToken'],
      roomId: data['roomId'],
      declinedBy: 'User',
    );

    // Update firestore to end the call room
    // Use Realtime Database to end the call (instead of Firestore)
    await FirebaseDatabase.instance
        .ref()
        .child('calls')
        .child(data['roomId'])
        .update({
          'status': 'ended',
          'endReason': 'declined',
          'endedAt': ServerValue.timestamp,
        });

    // Also remote from pending_calls
    final uid = data['targetId'] ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseDatabase.instance
          .ref()
          .child('pending_calls')
          .child(uid)
          .child(data['roomId'])
          .remove();
    }
  }
}


