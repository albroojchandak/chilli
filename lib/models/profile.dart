import 'package:cloud_firestore/cloud_firestore.dart';

class Profile {
  final String uid;
  final String? phoneNumber;
  final String? email; // ✅ Added Email
  final String username;
  final String gender;
  final String language;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? lastActive; // ✅ Track last activity
  final bool isOnline;
  final String status; // ✅ online/offline/busy
  final num coins;
  final String? fcmToken;
  final String? audioUrl;
  final String career; // User's profession/career

  Profile({
    required this.uid,
    this.phoneNumber,
    this.email,
    required this.username,
    required this.gender,
    required this.language,
    this.avatarUrl,
    this.audioUrl,
    required this.createdAt,
    this.lastActive,
    this.isOnline = false,
    this.status = 'offline', // ✅ Default status
    this.coins = 0,
    this.fcmToken,
    this.career = 'Professional', // Default career
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'email': email,
      'username': username,
      'gender': gender,
      'language': language,
      'avatarUrl': avatarUrl,
      'audioUrl': audioUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'isOnline': isOnline,
      'status': status,
      'coins': coins,
      'fcmToken': fcmToken,
      'career': career,
    };
  }

  // Convert to Map for Realtime Database (Optimized: Compact Keys)
  Map<String, dynamic> toRTDBMap() {
    return {
      'uid': uid,
      'n': username,
      'g': gender,
      'l': language.isNotEmpty ? language : 'English',
      'a': avatarUrl,
      'ft': fcmToken, // ✅ Added: FCM Token for calling support (Compact: ft)
      // Removed: 's' (status) and 'la' (lastActive) - Moved to userPresence node
    };
  }

  // Create from Map (Firestore or RTDB)
  factory Profile.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Profile(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'],
      email: map['email'] ?? map['Email'], // Handle both cases
      username: map['n'] ?? map['username'] ?? '', // Support short key 'n'
      gender: map['g'] ?? map['gender'] ?? '', // Support short key 'g'
      language: map['l'] ?? map['language'] ?? '', // Support short key 'l'
      avatarUrl: map['a'] ?? map['avatarUrl'], // Support short key 'a'
      audioUrl: map['audioUrl'],
      createdAt: parseDate(map['createdAt']),
      lastActive: parseNullableDate(
        map['la'] ?? map['lastActive'],
      ), // ✅ Support short key 'la'
      isOnline: map['isOnline'] ?? false,
      status: map['s'] ?? map['status'] ?? 'offline', // Support short key 's'
      coins: (map['coins'] as num?) ?? 0,
      fcmToken: map['ft'] ?? map['fcmToken'], // ✅ Support short key 'ft'
      career: map['career'] ?? 'Professional', // Default if not set
    );
  }

  // Copy with method for updates
  Profile copyWith({
    String? uid,
    String? phoneNumber,
    String? email,
    String? username,
    String? gender,
    String? language,
    String? avatarUrl,
    String? audioUrl,
    DateTime? createdAt,
    DateTime? lastActive, // ✅
    bool? isOnline,
    String? status, // ✅
    num? coins,
    String? fcmToken,
    String? career,
  }) {
    return Profile(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      username: username ?? this.username,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive, // ✅
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status, // ✅
      coins: coins ?? this.coins,
      fcmToken: fcmToken ?? this.fcmToken,
      career: career ?? this.career,
    );
  }
}

