import 'dart:convert';

class ChilliGift {
  final String id;
  final String name;
  final String emoji;
  final int cost;
  final int reward;
  final String animation;

  const ChilliGift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.reward,
    required this.animation,
  });
}

class GiftRegistry {
  static const List<ChilliGift> catalog = [
    ChilliGift(
      id: 'heart',
      name: 'Heart',
      emoji: '❤️',
      cost: 10,
      reward: 5,
      animation: 'heart_pulse',
    ),
    ChilliGift(
      id: 'rose',
      name: 'Rose',
      emoji: '🌹',
      cost: 50,
      reward: 25,
      animation: 'rose_fall',
    ),
    ChilliGift(
      id: 'diamond',
      name: 'Diamond',
      emoji: '💎',
      cost: 100,
      reward: 50,
      animation: 'diamond_sparkle',
    ),
    ChilliGift(
      id: 'crown',
      name: 'Crown',
      emoji: '👑',
      cost: 500,
      reward: 250,
      animation: 'crown_overlay',
    ),
    ChilliGift(
      id: 'car',
      name: 'Super Car',
      emoji: '🏎️',
      cost: 1000,
      reward: 500,
      animation: 'car_driveBy',
    ),
  ];

  static ChilliGift? find(String id) {
    try {
      return catalog.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }
}

class GiftEvent {
  final String type = 'Gift';
  final String giftId;
  final String senderName;
  final String senderAvatar;
  final String senderGender;
  final DateTime timestamp;
  final int cost;
  final int reward;

  GiftEvent({
    required this.giftId,
    required this.senderName,
    required this.senderAvatar,
    required this.senderGender,
    required this.timestamp,
    required this.cost,
    required this.reward,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'giftId': giftId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'senderGender': senderGender,
    'timestamp': timestamp.toIso8601String(),
    'cost': cost,
    'reward': reward,
  };

  String toJson() => jsonEncode(toMap());

  factory GiftEvent.fromMap(Map<String, dynamic> map) => GiftEvent(
    giftId: map['giftId'] ?? map['GiftModelId'] ?? '',
    senderName: map['senderName'] ?? '',
    senderAvatar: map['senderAvatar'] ?? '',
    senderGender: map['senderGender'] ?? 'male',
    timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    cost: map['cost'] ?? map['senderCost'] ?? 0,
    reward: map['reward'] ?? map['receiverReward'] ?? 0,
  );

  factory GiftEvent.fromJson(String source) => GiftEvent.fromMap(jsonDecode(source));
}

class GiftAnimator {
  static Duration getDuration(String animation) {
    switch (animation) {
      case 'heart_pulse': return const Duration(seconds: 2);
      case 'rose_fall': return const Duration(seconds: 3);
      case 'diamond_sparkle': return const Duration(seconds: 3);
      case 'crown_overlay': return const Duration(seconds: 4);
      case 'car_driveBy': return const Duration(seconds: 5);
      default: return const Duration(seconds: 2);
    }
  }
}
