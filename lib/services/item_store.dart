import 'dart:convert';

class VirtualItem {
  final String id;
  final String name;
  final String emoji;
  final int cost;
  final int reward;
  final String animation;

  const VirtualItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.reward,
    required this.animation,
  });
}

class VirtualItemCatalog {
  static const List<VirtualItem> allGiftModels = [
    VirtualItem(
      id: 'heart',
      name: 'Heart',
      emoji: '❤️',
      cost: 10,
      reward: 5,
      animation: 'heart_pulse',
    ),
    VirtualItem(
      id: 'rose',
      name: 'Rose',
      emoji: '🌹',
      cost: 50,
      reward: 25,
      animation: 'rose_fall',
    ),
    VirtualItem(
      id: 'diamond',
      name: 'Diamond',
      emoji: '💎',
      cost: 100,
      reward: 50,
      animation: 'diamond_sparkle',
    ),
    VirtualItem(
      id: 'crown',
      name: 'Crown',
      emoji: '👑',
      cost: 500,
      reward: 250,
      animation: 'crown_overlay',
    ),
    VirtualItem(
      id: 'car',
      name: 'Super Car',
      emoji: '🏎️',
      cost: 1000,
      reward: 500,
      animation: 'car_driveBy',
    ),
  ];

  static VirtualItem? getGiftModelById(String id) {
    try {
      return allGiftModels.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }
}

class VirtualItemMessage {
  final String type = 'VirtualItem';
  final String GiftModelId;
  final String senderName;
  final String senderAvatar;
  final String senderGender;
  final DateTime timestamp;
  final int senderCost;
  final int receiverReward;

  VirtualItemMessage({
    required this.GiftModelId,
    required this.senderName,
    required this.senderAvatar,
    required this.senderGender,
    required this.timestamp,
    required this.senderCost,
    required this.receiverReward,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'GiftModelId': GiftModelId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderGender': senderGender,
      'timestamp': timestamp.toIso8601String(),
      'senderCost': senderCost,
      'receiverReward': receiverReward,
    };
  }

  String toJson() {
    return jsonEncode(toMap());
  }

  factory VirtualItemMessage.fromMap(Map<String, dynamic> map) {
    return VirtualItemMessage(
      GiftModelId: map['GiftModelId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'] ?? '',
      senderGender: map['senderGender'] ?? 'male',
      timestamp: DateTime.parse(
        map['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      senderCost: (map['senderCost'] is num)
          ? (map['senderCost'] as num).toInt()
          : 0,
      receiverReward: (map['receiverReward'] is num)
          ? (map['receiverReward'] as num).toInt()
          : 0,
    );
  }

  factory VirtualItemMessage.fromJson(String source) {
    return VirtualItemMessage.fromMap(jsonDecode(source));
  }
}

class VirtualItemAnimation {
  static Duration getDuration(String animationName) {
    switch (animationName) {
      case 'heart_pulse':
        return const Duration(seconds: 2);
      case 'rose_fall':
        return const Duration(seconds: 3);
      case 'diamond_sparkle':
        return const Duration(seconds: 3);
      case 'crown_overlay':
        return const Duration(seconds: 4);
      case 'car_driveBy':
        return const Duration(seconds: 5);
      default:
        return const Duration(seconds: 2);
    }
  }
}

