import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../services/notif_transmitter.dart';

class AlertDispatcher {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  static Future<void> bootstrap() async {
    if (_ready) return;

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

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onTapped,
      onDidReceiveBackgroundNotificationResponse: _onTapped,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'call_channel_id',
      'Incoming Calls',
      description: 'Notifications for incoming video/audio calls',
      importance: Importance.max,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _ready = true;
    print('AlertDispatcher: ready');
  }

  @pragma('vm:entry-point')
  static void _onTapped(NotificationResponse response) async {
    print('AlertDispatcher: notification tapped: ${response.actionId}');

    if (response.payload == null) return;

    final data = jsonDecode(response.payload!);
    final roomId = data['roomId'];
    final actionId = response.actionId ?? '';

    if (actionId.startsWith('answer_')) {
      await _handleAccept(data);
    } else if (actionId.startsWith('decline_')) {
      await _handleReject(data);
    } else {
      await _handleAccept(data);
    }
  }

  static Future<void> presentCallAlert({
    required String roomId,
    required String callerName,
    required String callerAvatar,
    required String callerToken,
    required String callerId,
    required String targetId,
    required bool isVideoCall,
  }) async {
    final payload = jsonEncode({
      'roomId': roomId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'callerToken': callerToken,
      'callerId': callerId,
      'targetId': targetId,
      'isVideoCall': isVideoCall,
    });

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'call_channel_id',
          'Incoming Calls',
          channelDescription: 'Notifications for incoming video/audio calls',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          ongoing: true,
          autoCancel: false,
          playSound: true,
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

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: roomId.hashCode,
      title: isVideoCall ? '📹 Incoming Video Call' : '📞 Incoming Call',
      body: '$callerName is calling...',
      notificationDetails: notificationDetails,
      payload: payload,
    );

    print('AlertDispatcher: call alert shown ($callerName, $roomId)');
  }

  static Future<void> dismiss(int id) async {
    await _plugin.cancel(id: id);
  }

  static Future<void> dismissAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> _archiveCallEntry(
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

  static Future<void> _handleAccept(Map<String, dynamic> data) async {
    print('AlertDispatcher: call accepted from notification');
    await _archiveCallEntry(data, 'incoming');

    final roomId = data['roomId'];
    final targetId = data['targetId'];

    if (roomId != null) {
      await dismiss(roomId.hashCode);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_answered_roomId', roomId.toString());
        print('AlertDispatcher: marked room $roomId as answered');
      } catch (e) {
        print('AlertDispatcher: prefs write error: $e');
      }
    }

    try {
      final uid = targetId ?? FirebaseAuth.instance.currentUser?.uid;

      if (uid != null && roomId != null) {
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

        print('AlertDispatcher: RTDB updated for uid=$uid, room=$roomId');
      } else {
        print('AlertDispatcher: missing uid or roomId for RTDB update');
      }
    } catch (e) {
      print('AlertDispatcher: RTDB write error: $e');
    }
  }

  static Future<void> _handleReject(Map<String, dynamic> data) async {
    print('AlertDispatcher: call rejected from notification');
    await _archiveCallEntry(data, 'missed');

    final transmitter = NotificationTransmitter();
    await transmitter.dispatchCallDeclined(
      targetToken: data['callerToken'],
      roomId: data['roomId'],
      declinedBy: 'User',
    );

    await FirebaseDatabase.instance
        .ref()
        .child('calls')
        .child(data['roomId'])
        .update({
          'status': 'ended',
          'endReason': 'declined',
          'endedAt': ServerValue.timestamp,
        });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseDatabase.instance
          .ref()
          .child('pending_calls')
          .child(currentUser.uid)
          .child(data['roomId'])
          .remove();
    }
  }
}
