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

  // ✅ Cache user data locally
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

      // ❌ REMOVED: Do not set local_coins here.
      // This prevents stale Firestore data from overwriting local/RTDB balance.
      // New users are handled in LangScreen.
      // Re-installs are handled in HomeScreen sync.

      debugPrint('💾 User data cached locally');
    } catch (e) {
      debugPrint('❌ Error caching user data: $e');
    }
  }

  // ✅ Stream for broadcasting token updates
  static final StreamController<num> _tokenStreamController =
      StreamController<num>.broadcast();

  // ✅ Public getter for token stream
  static Stream<num> get tokenStream => _tokenStreamController.stream;

  // ✅ Broadcast token update to all listeners
  static void broadcastTokenUpdate(num tokens) {
    _tokenStreamController.add(tokens);
  }

  // Update user online/busy status in REALTIME DATABASE (Split: userPresence)
  Future<void> updateUserStatus(String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ Cannot update status: No user logged in');
        return;
      }

      // ✅ Write dynamic status to 'userPresence'
      final presenceRef = _db.child('userPresence').child(user.uid);

      if (status == 'offline') {
        debugPrint('🔴 Removing user from userPresence: ${user.uid}');
        await presenceRef.remove();
      } else {
        debugPrint(
          '🔄 Updating status to "$status" in userPresence for user: ${user.uid}',
        );

        await presenceRef.update({
          's': status, // 's' = status
          'la': ServerValue
              .timestamp, // ✅ Update last active whenever status changes
        });

        // ✅ DISABLED: Keep user ALWAYS visible in presence for incoming calls
        // await presenceRef.onDisconnect().remove();

        debugPrint('✅ Status successfully updated in userPresence to: $status');
      }
    } catch (e) {
      debugPrint(
        '❌ Error updating user status in userPresence to "$status": $e',
      );
    }
  }

  // ✅ Get local coins from cache (Fallback to 0)
  Future<num> getLocalCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Prioritize 'local_coins' key
      if (prefs.containsKey('local_coins')) {
        final value = prefs.get('local_coins');
        if (value is num) return value;
        if (value is String) return double.tryParse(value) ?? 0;
      }

      // Fallback to user_data for legacy compatibility
      final userDataString = prefs.getString(_userCacheKey);
      if (userDataString != null) {
        final data = jsonDecode(userDataString);
        return (data['coins'] as num?) ?? 0;
      }
    } catch (e) {
      debugPrint('Error getting local coins: $e');
    }
    return 0;
  }

  // ✅ Update local coins in cache
  Future<void> updateLocalCoins(num amount, {bool isDeduction = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get current balance from SOURCE OF TRUTH
      num currentCoins = await getLocalCoins();

      // Calculate new balance:
      // - If isDeduction = true: subtract amount (currentCoins - amount)
      // - If isDeduction = false: add amount (currentCoins + amount)
      num newBalance = isDeduction
          ? currentCoins - amount
          : currentCoins + amount;

      // ✅ CRITICAL: Prevent balance from going below zero
      if (newBalance < 0) {
        debugPrint('⚠️ Balance would go negative ($newBalance), capping at 0');
        newBalance = 0;
      }

      // Save to 'local_coins' (Source of Truth) - Use double for fractional support
      await prefs.setDouble('local_coins', newBalance.toDouble());

      // Also update user_data cache to keep it in sync (optional but good for safety)
      final userDataString = prefs.getString(_userCacheKey);
      if (userDataString != null) {
        final data = jsonDecode(userDataString);
        data['coins'] = newBalance;
        await prefs.setString(_userCacheKey, jsonEncode(data));
      }

      print(
        '💾 Local Coins Updated: $currentCoins ${isDeduction ? '-' : '+'} $amount = $newBalance',
      );
      broadcastTokenUpdate(newBalance);
    } catch (e) {
      debugPrint('Error updating local coins: $e');
    }
  }

  // ✅ Sync local balance to RTDB
  Future<void> syncCoinsWithServer() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();

      if (prefs.containsKey('local_coins')) {
        // Local exists, so it is Source of Truth.
        final localCoins = await getLocalCoins();
        // ❌ REMOVED RTDB SYNC as per user request to save bandwidth
        // await _db.child('users').child(user.uid).update({'coins': localCoins});
        // print('☁️ Coins synced to RTDB (Local -> Server): $localCoins');
        broadcastTokenUpdate(localCoins);
      } else {
        // Local missing (Fresh Install / Clear Data). Sync FROM Server (RTDB).
        final snapshot = await _db
            .child('users')
            .child(user.uid)
            .child('coins')
            .get();
        if (snapshot.exists) {
          final serverCoins = (snapshot.value as num?) ?? 0;
          await prefs.setDouble('local_coins', serverCoins.toDouble());
          print('☁️ Coins synced from RTDB (Server -> Local): $serverCoins');
          broadcastTokenUpdate(serverCoins);
        }
      }
    } catch (e) {
      debugPrint('Error syncing coins with RTDB: $e');
    }
  }

  // ✅ Save call history LOCALLY (SharedPreferences)
  Future<void> saveCallHistory({
    required String roomId,
    required String callerName,
    required String receiverName,
    required String callerId, // ✅ Added
    required String receiverId, // ✅ Added
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
        'callerId': callerId, // ✅ Added
        'receiverId': receiverId, // ✅ Added
        'callerName': callerName,
        'receiverName': receiverName,
        'callerAvatar': callerAvatar,
        'receiverAvatar': receiverAvatar,
        'type': type,
        'duration': durationSeconds,
        'status': status,
        'timestamp': DateTime.now()
            .toIso8601String(), // ISO string for local storage
      };

      // Add to beginning
      historyList.insert(0, newEntry);

      // Limit to last 50 calls to save space
      if (historyList.length > 50) {
        historyList = historyList.sublist(0, 50);
      }

      await prefs.setString('call_history_local', jsonEncode(historyList));
      print('💾 Call history saved locally');
    } catch (e) {
      debugPrint('Error saving local call history: $e');
    }
  }

  // Get current coin balance from Server (or call getLocalCoins if desired)
  Future<num> getCurrentCoins() async {
    // For now, we return local for speed, but could fetch from FS
    return await getLocalCoins();
  }

  // Check if call can continue (balance > 0)
  Future<bool> canContinueCall() async {
    final coins = await getLocalCoins();
    return coins > 0;
  }

  // ✅ App Config (Default values) - STATIC to share across instances
  static Map<String, dynamic> _appConfig = {
    'male_audio_cost': 2.5, // 5 per min
    'male_video_cost': 2.5, // 5 per min
    'female_audio_reward': 5.0, // 10 per min
    'female_video_reward': 10.0, // 20 per min
    'min_coins_required': 5.0,
    'min_deposit': 89.0,
    'min_withdrawal': 50.0,
    'paygic_mid': '',
    'paygic_token': '',
    'cashfree_app_id': '',
    'cashfree_secret_key': '',
    'min_app_version': '1.0.0',
    'latest_app_version': '1.0.0',
    'update_url':
        'https://play.google.com/store/apps/details?id=com.nurxian.chilli',
    'is_reward_enabled': true, // ✅ New field: Default True
  };

  // ✅ Getter for App Config
  static Map<String, dynamic> get appConfig => _appConfig;

  // ✅ Initialize Firestore Config - CALL THIS ONCE TO SET UP YOUR DATABASE
  Future<void> initializeFirestoreConfig() async {
    try {
      debugPrint('');
      debugPrint('🟡 ========================================');
      debugPrint('🟡 INITIALIZING FIRESTORE CONFIG');
      debugPrint('🟡 ========================================');
      debugPrint('⚠️  WARNING: This will OVERWRITE existing config!');
      debugPrint('');

      // 1. Create PRICING document
      debugPrint('💰 Creating pricing document...');
      await _firestore.collection('app_config').doc('pricing').set({
        // Male pricing (per 30 seconds)
        'male_audio_rate': 5.0, // 5 coins per minute for audio
        'male_video_rate': 10.0, // 5 coins per minute for video
        // Female rewards (per 30 seconds)
        'female_audio_rate': 10.0, // 10 coins per minute for audio
        'female_video_rate': 20.0, // 20 coins per minute for video
        // Minimum coins required
        'min_coins_required': 5.0, // Minimum coins to start call
        // Reward system
        'is_reward_enabled': true, // Enable/disable female rewards
        // Payment thresholds (optional - can also go in payment doc)
        'min_deposit': 89.0, // Minimum recharge amount
        'min_withdrawal': 50.0, // Minimum withdrawal amount
        // Metadata
        'last_updated': FieldValue.serverTimestamp(),
        'created_by': 'initializeFirestoreConfig',
      });
      debugPrint('✅ Pricing document created!');

      // 2. Create PAYMENT document
      debugPrint('');
      debugPrint('💳 Creating payment document...');
      await _firestore.collection('app_config').doc('payment').set({
        // Payment gateway credentials
        'paygic_mid': 'CHITCHATZ', // Add your Merchant ID here
        'paygic_token':
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJtaWQiOiJFTElURVpFRU5aR0ZSIiwiX2lkIjoiNjhlNzUxOWJiNGE0NmMzYjc3NDhkNzdlIiwiaWF0IjoxNzY3MjQ1MDA0LCJleHAiOjE3Njk4MzcwMDR9.BP1apIcNcGmHfTHKSlcNGgxtYo3gQ3NQ5beSbylSPjo', // Add your API Token here
        // Payment thresholds
        'min_deposit': 89.0,
        'min_withdrawal': 50.0,

        // Alternative field names (for compatibility)
        'min_recharge': 10.0,
        'min_payout': 50.0,

        // Metadata
        'last_updated': FieldValue.serverTimestamp(),
        'created_by': 'initializeFirestoreConfig',
      });
      debugPrint('✅ Payment document created!');
      debugPrint('⚠️  Remember to add your paygic_mid and paygic_token!');

      // 3. Create VERSION document
      debugPrint('');
      debugPrint('📱 Creating version document...');
      await _firestore.collection('app_config').doc('version').set({
        'min_version': '1.0.0', // Minimum app version allowed
        'latest_version': '1.0.0', // Latest available version
        'update_url':
            'https://play.google.com/store/apps/details?id=com.nurxian.chilli',

        // Metadata
        'last_updated': FieldValue.serverTimestamp(),
        'created_by': 'initializeFirestoreConfig',
      });
      debugPrint('✅ Version document created!');

      debugPrint('');
      debugPrint('🟢 ========================================');
      debugPrint('🟢 FIRESTORE CONFIG INITIALIZATION COMPLETE!');
      debugPrint('🟢 ========================================');
      debugPrint('✅ Created 3 documents:');
      debugPrint('   1. app_config/pricing');
      debugPrint('   2. app_config/payment');
      debugPrint('   3. app_config/version');
      debugPrint('');
      debugPrint('📝 Next steps:');
      debugPrint('   1. Open Firestore Console');
      debugPrint('   2. Navigate to app_config/payment');
      debugPrint('   3. Add your paygic_mid and paygic_token');
      debugPrint('   4. Adjust pricing values if needed');
      debugPrint('🟢 ========================================');
      debugPrint('');
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('🔴 ========================================');
      debugPrint('🔴 ERROR INITIALIZING FIRESTORE CONFIG');
      debugPrint('🔴 ========================================');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack trace:');
      debugPrint(stackTrace.toString());
      debugPrint('');
      debugPrint('💡 Common issues:');
      debugPrint('   - Firestore rules may not allow write access');
      debugPrint('   - Firebase not properly initialized');
      debugPrint('   - No internet connection');
      debugPrint('🔴 ========================================');
      debugPrint('');
      rethrow;
    }
  }

  // ✅ Fetch app config from Firestore
  Future<void> fetchAppConfig() async {
    double parseDouble(dynamic value, double def) {
      if (value == null) return def;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? def;
      return def;
    }

    try {
      debugPrint('');
      debugPrint('� ========================================');
      debugPrint('🔵 STARTING FIRESTORE CONFIG FETCH');
      debugPrint('🔵 ========================================');

      // Check Firestore connection
      debugPrint('📡 Checking Firestore connection...');

      // 1. Fetch Pricing

      debugPrint('');
      debugPrint('💰 Step 1: Fetching PRICING config...');
      debugPrint('📍 Path: app_config/pricing');

      final pricingDoc = await _firestore
          .collection('app_config')
          .doc('pricing')
          .get();

      debugPrint('✅ Pricing fetch completed');
      debugPrint('📊 Document exists: ${pricingDoc.exists}');
      debugPrint('📊 Has data: ${pricingDoc.data() != null}');

      if (pricingDoc.exists && pricingDoc.data() != null) {
        final data = pricingDoc.data()!;
        debugPrint('📦 Raw pricing data: $data');
        debugPrint('🔑 Available keys: ${data.keys.toList()}');

        // Support multiple field names for pricing
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

        debugPrint('✅ Pricing values parsed:');
        debugPrint('   Male Audio: ${_appConfig['male_audio_cost']}');
        debugPrint('   Male Video: ${_appConfig['male_video_cost']}');
        debugPrint('   Female Audio: ${_appConfig['female_audio_reward']}');
        debugPrint('   Female Video: ${_appConfig['female_video_reward']}');
        debugPrint('   Min Coins: ${_appConfig['min_coins_required']}');

        // ✅ Fetch is_reward_enabled from Firestore
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
            // Treat 1 as true, 0 as false
            _appConfig['is_reward_enabled'] = (val == 1);
          }
          debugPrint('   Rewards Enabled: ${_appConfig['is_reward_enabled']}');
        }

        // ✅ Check for Payment fields in 'pricing' doc (Fallback/User convenience)
        if (data.containsKey('paygic_mid') ||
            data.containsKey('mid') ||
            data.containsKey('min_deposit')) {
          debugPrint('💳 Payment fields found in pricing doc');
          _appConfig['min_deposit'] = parseDouble(
            data['min_deposit'] ?? data['min_recharge'],
            89.0,
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
        debugPrint('❌ Pricing config document NOT FOUND or empty!');
        debugPrint(
          '⚠️  Make sure you created: app_config/pricing in Firestore',
        );
      }

      // 2. Fetch Payment Config
      debugPrint('');
      debugPrint('💳 Step 2: Fetching PAYMENT config...');
      debugPrint('📍 Path: app_config/payment');

      final paymentDoc = await _firestore
          .collection('app_config')
          .doc('payment')
          .get();

      debugPrint('✅ Payment fetch completed');
      debugPrint('📊 Document exists: ${paymentDoc.exists}');
      debugPrint('📊 Has data: ${paymentDoc.data() != null}');

      if (paymentDoc.exists && paymentDoc.data() != null) {
        final data = paymentDoc.data()!;
        debugPrint('📦 Raw payment data: $data');
        debugPrint('🔑 Available keys: ${data.keys.toList()}');

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
        _appConfig['cashfree_app_id'] =
            (data['cashfree_app_id'] ?? _appConfig['cashfree_app_id'])
                .toString()
                .trim();
        _appConfig['cashfree_secret_key'] =
            (data['cashfree_secret_key'] ?? _appConfig['cashfree_secret_key'])
                .toString()
                .trim();

        debugPrint('✅ Payment values parsed:');
        debugPrint('   Min Deposit: ${_appConfig['min_deposit']}');
        debugPrint('   Min Withdrawal: ${_appConfig['min_withdrawal']}');
        debugPrint(
          '   MID: ${_appConfig['paygic_mid'].toString().isEmpty ? "EMPTY" : "Set"}',
        );
        debugPrint(
          '   Token: ${_appConfig['paygic_token'].toString().isEmpty ? "EMPTY" : "Set"}',
        );
      } else {
        debugPrint('⚠️  Payment document not found (optional)');
      }

      // Only warn if still empty after both checks
      if (_appConfig['paygic_mid'] == '') {
        debugPrint('');
        debugPrint('⚠️  WARNING: Payment gateway not configured!');
        debugPrint(
          '⚠️  Add paygic_mid and paygic_token to pricing or payment doc',
        );
      }

      // 3. Fetch Version Config
      debugPrint('');
      debugPrint('📱 Step 3: Fetching VERSION config...');
      debugPrint('📍 Path: app_config/version');

      final versionDoc = await _firestore
          .collection('app_config')
          .doc('version')
          .get();

      debugPrint('✅ Version fetch completed');
      debugPrint('📊 Document exists: ${versionDoc.exists}');
      debugPrint('📊 Has data: ${versionDoc.data() != null}');

      if (versionDoc.exists && versionDoc.data() != null) {
        final data = versionDoc.data()!;
        debugPrint('📦 Raw version data: $data');
        debugPrint('🔑 Available keys: ${data.keys.toList()}');

        _appConfig['min_app_version'] =
            data['min_version']?.toString() ?? '1.0.0';
        _appConfig['latest_app_version'] =
            data['latest_version']?.toString() ?? '1.0.0';
        _appConfig['update_url'] =
            data['update_url']?.toString() ??
            'https://play.google.com/store/apps/details?id=com.nurxian.chilli';

        debugPrint('✅ Version values parsed:');
        debugPrint('   Min Version: ${_appConfig['min_app_version']}');
        debugPrint('   Latest Version: ${_appConfig['latest_app_version']}');
        debugPrint('   Update URL: ${_appConfig['update_url']}');
      } else {
        debugPrint('⚠️  Version document not found (optional)');
      }

      debugPrint('');
      debugPrint('🟢 ========================================');
      debugPrint('🟢 FINAL CONFIG LOADED:');
      debugPrint('🟢 ========================================');
      debugPrint(_appConfig.toString());
      debugPrint('🟢 ========================================');
      debugPrint('');
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('🔴 ========================================');
      debugPrint('🔴 ERROR FETCHING APP CONFIG');
      debugPrint('🔴 ========================================');
      debugPrint('❌ Error: $e');
      debugPrint('📍 Stack trace:');
      debugPrint(stackTrace.toString());
      debugPrint('🔴 ========================================');
      debugPrint('');
    }
  }

  // ✅ UPDATED: Handle coins LOCALLY during call
  Future<void> handlePeriodicCallCoins({
    required bool isVideoCall,
    required String gender,
  }) async {
    try {
      // Ensure config is loaded
      if (_appConfig['paygic_mid'] == '') await fetchAppConfig();

      final genderLower = gender.toLowerCase();
      num amount = 0;

      if (genderLower == 'male') {
        // Deduct cost
        if (isVideoCall) {
          amount = -(_appConfig['male_video_cost'] ?? 2.5);
        } else {
          amount = -(_appConfig['male_audio_cost'] ?? 2.5);
        }
      } else if (genderLower == 'female') {
        // Add reward
        if (isVideoCall) {
          amount = _appConfig['female_video_reward'] ?? 10.0;
        } else {
          amount = _appConfig['female_audio_reward'] ?? 5.0;
        }
      }

      await updateLocalCoins(amount, isDeduction: false);
    } catch (e) {
      debugPrint('Error handling periodic coins: $e');
    }
  }

  // Handle coins with specific amount locally
  Future<void> handlePeriodicCallCoinsWithAmount(double amount) async {
    await updateLocalCoins(amount, isDeduction: true);
  }

  // Check if has minimum coins to start a call (Males only)
  Future<bool> hasMinimumCoinsForCall(bool isVideoCall, String gender) async {
    if (gender.toLowerCase() == 'female') return true;

    final coins = await getLocalCoins();
    // Min required for 1 minute
    final minRequired = _appConfig['min_coins_required'] ?? 5.0;
    return coins >= minRequired;
  }

  // Update user tokens/coins manually both locally and on RTDB
  Future<void> updateUserTokens(String email, num balance) async {
    try {
      await updateLocalCoins(balance);

      final snapshot = await _db.child('users').get();
      if (snapshot.exists) {
        final usersMap = snapshot.value as Map<dynamic, dynamic>;
        usersMap.forEach((key, value) async {
          final userData = Map<String, dynamic>.from(value as Map);
          if (userData['email'] == email || userData['Email'] == email) {
            // ❌ REMOVED RTDB SYNC
            // await _db.child('users').child(key).update({'coins': balance});
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating user tokens in RTDB: $e');
    }
  }

  // ✅ Get Trusted Server Date (Prevents Phone Time exploit)
  Future<DateTime> getServerDate() async {
    try {
      final response = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/Etc/UTC'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DateTime.parse(data['datetime']);
      }
    } catch (e) {
      debugPrint('⚠️ WorldTimeAPI failed, falling back to local time: $e');
    }
    return DateTime.now(); // Fallback
  }
}
