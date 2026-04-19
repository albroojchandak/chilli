import 'package:cloud_firestore/cloud_firestore.dart';

class ChilliProfile {
  final String uid;
  final String? phone;
  final String? email;
  final String name;
  final String gender;
  final String language;
  final String? avatarUrl;
  final String? audioUrl;
  final DateTime createdAt;
  final DateTime? lastActive;
  final bool isOnline;
  final String status;
  final num coins;
  final String? fcmToken;
  final String career;

  const ChilliProfile({
    required this.uid,
    this.phone,
    this.email,
    required this.name,
    required this.gender,
    required this.language,
    this.avatarUrl,
    this.audioUrl,
    required this.createdAt,
    this.lastActive,
    this.isOnline = false,
    this.status = 'offline',
    this.coins = 0,
    this.fcmToken,
    this.career = 'Expert',
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'phoneNumber': phone,
    'email': email,
    'username': name,
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

  Map<String, dynamic> toRTDBMap() => {
    'uid': uid,
    'n': name,
    'g': gender,
    'l': language.isEmpty ? 'English' : language,
    'a': avatarUrl,
    'ft': fcmToken,
  };

  factory ChilliProfile.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseOpt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ChilliProfile(
      uid: map['uid'] ?? '',
      phone: map['phoneNumber'],
      email: map['email'] ?? map['Email'],
      name: map['n'] ?? map['username'] ?? '',
      gender: map['g'] ?? map['gender'] ?? '',
      language: map['l'] ?? map['language'] ?? '',
      avatarUrl: map['a'] ?? map['avatarUrl'],
      audioUrl: map['audioUrl'],
      createdAt: parse(map['createdAt']),
      lastActive: parseOpt(map['la'] ?? map['lastActive']),
      isOnline: map['isOnline'] ?? false,
      status: map['s'] ?? map['status'] ?? 'offline',
      coins: (map['coins'] as num?) ?? 0,
      fcmToken: map['ft'] ?? map['fcmToken'],
      career: map['career'] ?? 'Expert',
    );
  }

  ChilliProfile copyWith({
    String? uid,
    String? phone,
    String? email,
    String? name,
    String? gender,
    String? language,
    String? avatarUrl,
    String? audioUrl,
    DateTime? createdAt,
    DateTime? lastActive,
    bool? isOnline,
    String? status,
    num? coins,
    String? fcmToken,
    String? career,
  }) {
    return ChilliProfile(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      coins: coins ?? this.coins,
      fcmToken: fcmToken ?? this.fcmToken,
      career: career ?? this.career,
    );
  }
}
