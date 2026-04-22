import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class DataBridge {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static const String _userCacheKey = 'user_data';

  Future<void> cacheUserData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'uid': data['uid'] ?? data['id'] ?? '',
        'Name': data['username'] ?? data['Name'] ?? '',
        'Gender': data['gender'] ?? data['Gender'] ?? '',
        'Language': data['language'] ?? data['Language'] ?? '',
        'coins': data['coins'] ?? 0,
        'Email': data['email'] ?? data['Email'] ?? '',
        'phoneNumber': data['phoneNumber'] ?? data['phonenumber'] ?? '',
        'ProfilePicture': data['avatarUrl'] ?? data['ProfilePicture'] ?? '',
      };
      await prefs.setString(_userCacheKey, jsonEncode(userData));
      debugPrint('DataBridge: user data cached');
    } catch (e) {
      debugPrint('DataBridge: cacheUserData error: $e');
    }
  }

  static final StreamController<num> _balanceStreamController =
      StreamController<num>.broadcast();

  static Stream<num> get balanceStream => _balanceStreamController.stream;

  static void broadcastBalance(num tokens) {
    _balanceStreamController.add(tokens);
  }

  Future<void> updateUserStatus(String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('DataBridge: no user, cannot update status');
        return;
      }

      final presenceRef = _db.child('userPresence').child(user.uid);

      if (status == 'offline') {
        debugPrint('DataBridge: removing presence for ${user.uid}');
        await presenceRef.remove();
      } else {
        debugPrint('DataBridge: updating status to "$status" for ${user.uid}');

        await presenceRef.update({'s': status, 'la': ServerValue.timestamp});

        debugPrint('DataBridge: status updated to $status');
      }
    } catch (e) {
      debugPrint('DataBridge: updateUserStatus error: $e');
    }
  }

  Future<num> getLocalCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('local_coins')) {
        final value = prefs.get('local_coins');
        if (value is num) return value;
        if (value is String) return double.tryParse(value) ?? 0;
      }

      final userDataString = prefs.getString(_userCacheKey);
      if (userDataString != null) {
        final data = jsonDecode(userDataString);
        return (data['coins'] as num?) ?? 0;
      }
    } catch (e) {
      debugPrint('DataBridge: getLocalCoins error: $e');
    }
    return 0;
  }

  Future<void> updateLocalCoins(num amount, {bool isDeduction = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      num currentCoins = await getLocalCoins();

      num newBalance = isDeduction
          ? currentCoins - amount
          : currentCoins + amount;

      if (newBalance < 0) {
        debugPrint('DataBridge: balance would go negative, capping at 0');
        newBalance = 0;
      }

      await prefs.setDouble('local_coins', newBalance.toDouble());

      final userDataString = prefs.getString(_userCacheKey);
      if (userDataString != null) {
        final data = jsonDecode(userDataString);
        data['coins'] = newBalance;
        await prefs.setString(_userCacheKey, jsonEncode(data));
      }

      print(
        'DataBridge: coins update $currentCoins ${isDeduction ? '-' : '+'} $amount = $newBalance',
      );
      broadcastBalance(newBalance);
      
      // Push to cloud
      unawaited(syncBalanceToCloud(newBalance));
    } catch (e) {
      debugPrint('DataBridge: updateLocalCoins error: $e');
    }
  }

  Future<void> syncBalanceToCloud(num balance) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({'coins': balance});
      
      // Update RTDB
      await _db.child('users').child(user.uid).update({'coins': balance});
      await _db.child('usersProfile').child(user.uid).update({'coins': balance});
      
      debugPrint('DataBridge: balance synced to cloud: $balance');
    } catch (e) {
      debugPrint('DataBridge: syncBalanceToCloud error: $e');
    }
  }

  Future<void> syncCoinsWithServer() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      if (prefs.containsKey('local_coins')) {
        final localCoins = await getLocalCoins();
        broadcastBalance(localCoins);
      } else {
        final snapshot = await _db
            .child('users')
            .child(user.uid)
            .child('coins')
            .get();
        if (snapshot.exists) {
          final serverCoins = (snapshot.value as num?) ?? 0;
          await prefs.setDouble('local_coins', serverCoins.toDouble());
          print('DataBridge: coins synced from server: $serverCoins');
          broadcastBalance(serverCoins);
        }
      }
    } catch (e) {
      debugPrint('DataBridge: syncCoinsWithServer error: $e');
    }
  }

  Future<void> saveCallHistory({
    required String roomId,
    required String callerName,
    required String receiverName,
    required String callerId,
    required String receiverId,
    required String type,
    required int durationSeconds,
    required String status,
    String? callerAvatar,
    String? receiverAvatar,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('call_history_local') ?? '[]';
      List<dynamic> historyList = [];
      try {
        historyList = jsonDecode(historyString);
      } catch (e) {
        historyList = [];
      }

      final newEntry = {
        'roomId': roomId,
        'callerId': callerId,
        'receiverId': receiverId,
        'callerName': callerName,
        'receiverName': receiverName,
        'callerAvatar': callerAvatar,
        'receiverAvatar': receiverAvatar,
        'type': type,
        'duration': durationSeconds,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      };

      historyList.insert(0, newEntry);

      if (historyList.length > 50) {
        historyList = historyList.sublist(0, 50);
      }

      await prefs.setString('call_history_local', jsonEncode(historyList));
      print('DataBridge: call history saved');
    } catch (e) {
      debugPrint('DataBridge: saveCallHistory error: $e');
    }
  }

  Future<num> getCurrentCoins() async {
    return await getLocalCoins();
  }

  Future<bool> canContinueCall() async {
    final coins = await getLocalCoins();
    return coins > 0;
  }

  static Map<String, dynamic> _appConfig = {
    'male_audio_cost': 2.5,
    'male_video_cost': 2.5,
    'female_audio_reward': 5.0,
    'female_video_reward': 10.0,
    'min_coins_required': 5.0,
    'min_deposit': 79.0,
    'min_withdrawal': 50.0,
    'paygic_mid': '',
    'paygic_token': '',
    'min_app_version': '1.0.0',
    'latest_app_version': '1.0.0',
    'update_url': '',
    'is_reward_enabled': true,
  };

  static Map<String, dynamic> get appConfig => _appConfig;

  Future<void> initializeFirestoreConfig() async {
    try {
      debugPrint('DataBridge: initializing Firestore config');

      await _firestore.collection('app_config').doc('pricing').set({
        'male_audio_rate': 5.0,
        'male_video_rate': 10.0,
        'female_audio_rate': 10.0,
        'female_video_rate': 20.0,
        'min_coins_required': 5.0,
        'is_reward_enabled': true,
        'min_deposit': 79.0,
        'min_withdrawal': 50.0,
        'last_updated': FieldValue.serverTimestamp(),
        'created_by': 'initializeFirestoreConfig',
      });
      debugPrint('DataBridge: pricing doc created');

      debugPrint('DataBridge: Firestore config initialization complete');
    } catch (e, stackTrace) {
      debugPrint('DataBridge: initializeFirestoreConfig error: $e');
      debugPrint('DataBridge: stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> fetchAppConfig() async {
    double parseDouble(dynamic value, double def) {
      if (value == null) return def;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? def;
      return def;
    }

    try {
      debugPrint('DataBridge: fetching app config');

      final pricingDoc = await _firestore
          .collection('app_config')
          .doc('pricing')
          .get();

      debugPrint('DataBridge: pricing doc exists: ${pricingDoc.exists}');

      if (pricingDoc.exists && pricingDoc.data() != null) {
        final data = pricingDoc.data()!;
        debugPrint('DataBridge: pricing data: $data');

        _appConfig['male_audio_cost'] =
            parseDouble(
              data['male_audio_rate'] ?? data['male_audio_cost'],
              5.0,
            ) /
            2;
        _appConfig['male_video_cost'] =
            parseDouble(
              data['male_video_rate'] ?? data['male_video_cost'],
              5.0,
            ) /
            2;
        _appConfig['female_audio_reward'] =
            parseDouble(
              data['female_audio_rate'] ?? data['female_audio_reward'],
              10.0,
            ) /
            2;
        _appConfig['female_video_reward'] =
            parseDouble(
              data['female_video_rate'] ?? data['female_video_reward'],
              20.0,
            ) /
            2;
        _appConfig['min_coins_required'] = parseDouble(
          data['min_coins_required'] ?? data['min_coins'],
          5.0,
        );

        debugPrint('DataBridge: pricing parsed');

        if (data.containsKey('is_reward_enabled')) {
          final val = data['is_reward_enabled'];
          if (val is bool) {
            _appConfig['is_reward_enabled'] = val;
          } else if (val is String) {
            final lower = val.toLowerCase().trim();
            _appConfig['is_reward_enabled'] =
                (lower == 'true' ||
                lower == 'enable' ||
                lower == 'enabled' ||
                lower == 'yes' ||
                lower == 'on' ||
                lower == '1');
          } else if (val is num) {
            _appConfig['is_reward_enabled'] = (val == 1);
          }
        }

        if (data.containsKey('paygic_mid') ||
            data.containsKey('mid') ||
            data.containsKey('min_deposit')) {
          _appConfig['min_deposit'] = parseDouble(
            data['min_deposit'] ?? data['min_recharge'],
            79.0,
          );
          _appConfig['min_withdrawal'] = parseDouble(
            data['min_withdrawal'] ?? data['min_payout'],
            50.0,
          );
          _appConfig['paygic_mid'] =
              (data['paygic_mid'] ??
                      data['mid'] ??
                      data['MID'] ??
                      _appConfig['paygic_mid'])
                  .toString()
                  .trim();
          _appConfig['paygic_token'] =
              (data['paygic_token'] ??
                      data['token'] ??
                      data['temtoken'] ??
                      _appConfig['paygic_token'])
                  .toString()
                  .trim();
        }
      } else {
        debugPrint('DataBridge: pricing config not found');
      }

      final paymentDoc = await _firestore
          .collection('app_config')
          .doc('payment')
          .get();

      if (paymentDoc.exists && paymentDoc.data() != null) {
        final data = paymentDoc.data()!;
        debugPrint('DataBridge: payment data: $data');

        _appConfig['min_deposit'] = parseDouble(
          data['min_deposit'] ?? data['min_recharge'],
          _appConfig['min_deposit'],
        );
        _appConfig['min_withdrawal'] = parseDouble(
          data['min_withdrawal'] ?? data['min_payout'],
          _appConfig['min_withdrawal'],
        );

        _appConfig['paygic_mid'] =
            (data['paygic_mid'] ??
                    data['mid'] ??
                    data['MID'] ??
                    _appConfig['paygic_mid'])
                .toString()
                .trim();
        _appConfig['paygic_token'] =
            (data['paygic_token'] ??
                    data['token'] ??
                    data['temtoken'] ??
                    _appConfig['paygic_token'])
                .toString()
                .trim();

        debugPrint('DataBridge: payment parsed');
      } else {
        debugPrint('DataBridge: payment config not found');
      }

      final versionDoc = await _firestore
          .collection('app_config')
          .doc('version')
          .get();

      if (versionDoc.exists && versionDoc.data() != null) {
        final data = versionDoc.data()!;
        debugPrint('DataBridge: version data: $data');

        _appConfig['min_app_version'] =
            data['min_version']?.toString() ?? '1.0.0';
        _appConfig['latest_app_version'] =
            data['latest_version']?.toString() ?? '1.0.0';
        _appConfig['update_url'] = data['update_url']?.toString() ?? '';

        debugPrint('DataBridge: version parsed');
      } else {
        debugPrint('DataBridge: version config not found');
      }

      debugPrint('DataBridge: config loaded: $_appConfig');
    } catch (e, stackTrace) {
      debugPrint('DataBridge: fetchAppConfig error: $e');
      debugPrint('DataBridge: stack: $stackTrace');
    }
  }

  Future<void> applyCallBilling({
    required bool isVideoCall,
    required String gender,
  }) async {
    try {
      if (_appConfig['paygic_mid'] == '') await fetchAppConfig();

      final genderLower = gender.toLowerCase();
      num amount = 0;

      // Billing is triggered every 30 seconds.
      // The male_video_cost/male_audio_cost in _appConfig are already halved (per 30s rate).

      if (genderLower == 'male') {
        // CALLER (Male) pays the full rate defined in app_config
        if (isVideoCall) {
          amount = -(_appConfig['male_video_cost'] ?? 5.0);
        } else {
          amount = -(_appConfig['male_audio_cost'] ?? 2.5);
        }
      } else if (genderLower == 'female') {
        // HOST (Female) earns 1/3 of what the male user is charged
        // This ensures the 1:3 ratio requested by the user.
        if (isVideoCall) {
          final baseRate = _appConfig['male_video_cost'] ?? 5.0;
          amount = baseRate / 3.0;
        } else {
          final baseRate = _appConfig['male_audio_cost'] ?? 2.5;
          amount = baseRate / 3.0;
        }
      }

      if (amount != 0) {
        debugPrint('DataBridge: Applying call billing: gender=$genderLower, amount=$amount');
        await updateLocalCoins(amount, isDeduction: false);
      }
    } catch (e) {
      debugPrint('DataBridge: applyCallBilling error: $e');
    }
  }

  Future<void> chargeCallAmount(double amount) async {
    await updateLocalCoins(amount, isDeduction: true);
  }

  Future<bool> hasMinimumBalance(bool isVideoCall, String gender) async {
    if (gender.toLowerCase() == 'female') return true;

    final coins = await getLocalCoins();
    final minRequired = _appConfig['min_coins_required'] ?? 5.0;
    return coins >= minRequired;
  }

  Future<void> setUserBalance(String email, num balance) async {
    try {
      await updateLocalCoins(balance);

      final snapshot = await _db.child('users').get();
      if (snapshot.exists) {
        final usersMap = snapshot.value as Map<dynamic, dynamic>;
        usersMap.forEach((key, value) async {
          final userData = Map<String, dynamic>.from(value as Map);
          if (userData['email'] == email || userData['Email'] == email) {}
        });
      }
    } catch (e) {
      debugPrint('DataBridge: setUserBalance error: $e');
    }
  }

  Future<DateTime> fetchServerTime() async {
    try {
      final response = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/Etc/UTC'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DateTime.parse(data['datetime']);
      }
    } catch (e) {
      debugPrint('DataBridge: fetchServerTime error, using local: $e');
    }
    return DateTime.now();
  }
}
