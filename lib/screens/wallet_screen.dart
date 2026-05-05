import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/theme/palette.dart';
import 'package:chilli/screens/txn_screen.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:crypto/crypto.dart';
import 'package:scratcher/scratcher.dart';

final FacebookAppEvents facebookAppEvents = FacebookAppEvents();

class WithdrawRequest {
  final String email;
  final double amount;
  final String status;
  final String upi;
  final String date;
  final String? withdrawalId;
  final String? name;

  WithdrawRequest({
    required this.email,
    required this.amount,
    required this.status,
    required this.upi,
    required this.date,
    this.withdrawalId,
    this.name,
  });

  factory WithdrawRequest.fromJson(Map<String, dynamic> json) {
    return WithdrawRequest(
      email: json['Email'] ?? '',
      amount: (json['Amount'] ?? 0.0).toDouble(),
      status: json['Status'] ?? '',
      upi: json['Upi'] ?? '',
      date: json['Date'] ?? '',
      withdrawalId: json['withdrawal_id'],
      name: json['name'],
    );
  }
}

class ChilliWalletScreen extends StatefulWidget {
  const ChilliWalletScreen({super.key});

  @override
  State<ChilliWalletScreen> createState() => _ChilliWalletScreenState();
}

class _ChilliWalletScreenState extends State<ChilliWalletScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final IdentityManager _identityManager = IdentityManager();

  // Using AppPalette for consistency, mapped to local variables for ease of porting
  final primaryColor = AppPalette.primary; // Was Color(0xFF6A98F0)
  final secondaryColor = const Color(0xFF8BB3FF); // Kept specific
  final backgroundColor = const Color(0xFFF8F9FE);
  final accentColor = const Color(0xFFFF9B7D);

  Map<String, dynamic>? userData;
  num currentCoins =
      0; // Renamed from currentTokens to currentCoins for consistency
  bool isLoading = true;
  String userGender = 'male';
  double minDepositAmount = 79.0;
  double minWithdrawalAmount = 50.0;

  num _selectedPackageCoins = 0;
  num _selectedPackagePrice = 0;

  String? merchantId;
  String? paygicToken;

  late AnimationController _controller;
  StreamSubscription<num>? _coinSubscription;

  bool _isPaymentProcessing = false;
  String? _currentRefId;
  Timer? _paymentTimeoutTimer;
  static const String _pendingPaymentPrefsKey = 'pending_paygic_payment';
  Set<String> _processedPaymentRefs =
      {}; // Track processed payments to prevent duplicates

  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoadingWithdrawal = false;
  int? _tempSelectedIndex;

  final Map<String, Color> colorScheme = {
    'primary': AppPalette.primary,
    'secondary': Color(0xFF8BB3FF),
    'accent': Color(0xFFFF9B7D),
    'success': Color(0xFF10B981),
    'warning': Color(0xFFF59E0B),
    'error': Color(0xFFEF4444),
    'text': Color(0xFF1F2937),
    'textLight': Color(0xFF6B7280),
    'background': Color(0xFFF8F9FE),
    'cardBg': Colors.white,
    'surface': Color(0xFFF8F9FE),
    'border': Color(0xFFE5E7EB),
  };
  // final ApiHandler _HttpService = ApiHandler(); // Add after AuthHandler
  // final HttpService _HttpService = HttpService();
  // balanceupa() async {
  //   await _HttpService.updateLocalCoins(102);
  // }

  @override
  void initState() {
    super.initState();
    // balanceupa();
    _loadUserData();
    _loadProcessedPaymentRefs(); // Load processed payments to prevent duplicates
    WidgetsBinding.instance.addObserver(this);

    // ✅ Auto-check last unresolved payment status on page open
    // Delayed so that _loadUserData() finishes first (credentials needed)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkLastPendingPaymentOnStart();
    });

    _coinSubscription = DataBridge.balanceStream.listen((newCoins) {
      if (mounted) {
        setState(() {
          currentCoins = newCoins;
        });
        print('💰 ChilliWalletScreen: Coins updated to $newCoins');
      }
    });

    _tempSelectedIndex = 4; // Default selection (Popular)

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  // ─── Auto-check last pending/failed payment on page open ────────────────
  /// Reads local history, finds the most recent pending/failed deposit with a
  /// refId, and calls the Paygic checkPaymentStatus API. If the server returns
  /// SUCCESS the coins are credited and the local record is updated.
  Future<void> _checkLastPendingPaymentOnStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString =
          prefs.getString('local_transaction_history') ?? '[]';
      final List<dynamic> history = jsonDecode(historyString);

      // Find the most-recent unresolved deposit (iterate from newest → oldest)
      Map<String, dynamic>? lastUnresolved;
      for (int i = history.length - 1; i >= 0; i--) {
        final item = Map<String, dynamic>.from(history[i]);
        final status = (item['status'] ?? '').toString().toLowerCase();
        final refId = item['refId']?.toString() ?? '';
        final type = (item['type'] ?? 'deposit').toString();
        if (type == 'deposit' &&
            refId.isNotEmpty &&
            (status == 'pending' || status == 'failed')) {
          lastUnresolved = item;
          break;
        }
      }

      if (lastUnresolved == null) {
        print('🔍 No unresolved payment found on start.');
        return;
      }

      final refId = lastUnresolved['refId'].toString();

      // Skip if already processed (duplicate guard)
      if (_processedPaymentRefs.contains(refId)) {
        print('⚠️ Auto-check: $refId already processed, skipping.');
        return;
      }

      // Resolve credentials: prefer what was saved in the record
      final mid = (lastUnresolved['mid']?.toString() ?? '').isNotEmpty
          ? lastUnresolved['mid'].toString()
          : merchantId ??
                DataBridge.appConfig['paygic_mid']?.toString().trim() ??
                '';
      final token = (lastUnresolved['token']?.toString() ?? '').isNotEmpty
          ? lastUnresolved['token'].toString()
          : paygicToken ??
                DataBridge.appConfig['paygic_token']?.toString().trim() ??
                '';

      if (mid.isEmpty || token.isEmpty) {
        print('⚠️ Auto-check: credentials not ready yet, skipping.');
        return;
      }

      print('🔄 Auto-checking payment status for refId: $refId');

      final response = await http
          .post(
            Uri.parse('https://server.paygic.in/api/v2/checkPaymentStatus'),
            headers: {'Content-Type': 'application/json', 'token': token},
            body: jsonEncode({'mid': mid, 'merchantReferenceId': refId}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('⚠️ Auto-check: server returned ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      final txnStatus = (data['txnStatus'] ?? data['status'] ?? '')
          .toString()
          .toUpperCase();
      final isSuccess =
          data['status'] == true ||
          data['statusCode'] == 200 ||
          txnStatus == 'SUCCESS';

      print('🔍 Auto-check result for $refId → txnStatus: $txnStatus');

      if (!isSuccess || txnStatus != 'SUCCESS') {
        print(
          'ℹ️ Auto-check: payment not successful yet ($txnStatus). No action.',
        );
        return;
      }

      // Payment is confirmed SUCCESS ─ credit coins and update record
      // Prevent double-credit using the processed-refs guard
      await _saveProcessedPaymentRef(refId);

      // Determine coins to add: prefer tokens saved in local record
      final num coinsToAdd =
          (lastUnresolved['tokens'] as num?) ??
          (data['data']?['amount'] as num?) ??
          0;

      if (coinsToAdd > 0) {
        final currentBalance = await DataBridge().getLocalCoins();
        final newBalance = currentBalance + coinsToAdd.toDouble();
        await prefs.setDouble('local_coins', newBalance);
        DataBridge.broadcastBalance(newBalance.toInt());
        print(
          '💰 Auto-check: credited $coinsToAdd coins. New balance: $newBalance',
        );
      }

      // Update the local history record to 'success'
      await _updateTransactionStatus(refId, 'success');

      // Notify the user
      if (mounted) {
        _showToast(
          '✅ Payment of ₹${lastUnresolved['amount']} verified! Coins credited.',
          Colors.green,
        );
      }
    } catch (e) {
      print('⚠️ Auto payment status check error: $e');
    }
  }

  // Daily Bonus State
  bool _canClaimBonus = false;
  int _currentStreakDay = 1;

  Future<void> _checkDailyBonusStatus() async {
    // Check if rewards are enabled from server
    if (DataBridge.appConfig['is_reward_enabled'] != true) {
      if (mounted) setState(() => _canClaimBonus = false);
      return;
    }

    try {
      // 1. Get Trusted Date (Prevents Phone Time exploit)
      // Convert to Local Time to align with User's Midnight
      final DateTime serverNowRaw = await DataBridge().fetchServerTime();
      final DateTime serverNow = serverNowRaw.toLocal();
      final todayStr =
          "${serverNow.year}-${serverNow.month.toString().padLeft(2, '0')}-${serverNow.day.toString().padLeft(2, '0')}";

      // 2. Get Last Claim Info (Prioritize Cloud/Cache over just SharedPreferences)
      final prefs = await SharedPreferences.getInstance();

      // Check multiple sources for the last claim date
      // Check multiple sources for the last claim date
      final String firestoreDate =
          userData?['last_daily_bonus_claim']?.toString() ?? '';
      final String localDate = prefs.getString('last_daily_bonus_claim') ?? '';

      // Use the one that is 'today' if possible (Optimistic Locking)
      String lastClaimDateStr = firestoreDate;
      if (localDate == todayStr) {
        lastClaimDateStr = localDate;
      } else if (firestoreDate.isNotEmpty) {
        lastClaimDateStr = firestoreDate;
      } else {
        lastClaimDateStr = localDate;
      }

      _currentStreakDay =
          userData?['daily_bonus_day_count'] ??
          prefs.getInt('daily_bonus_day_count') ??
          1;

      if (lastClaimDateStr.isEmpty) {
        if (mounted) setState(() => _canClaimBonus = true);
        return;
      }

      // 3. Comparison (Strict Date Check)
      if (todayStr != lastClaimDateStr) {
        // Different day!
        // Optional: Check if streak is broken (difference > 1)
        try {
          final lastDate = DateTime.parse(lastClaimDateStr);
          final todayDate = DateTime.parse(todayStr);
          final diff = todayDate.difference(lastDate).inDays;
          if (diff > 1) {
            // Streak broken - reset to 1
            _currentStreakDay = 1;
          }
        } catch (e) {}

        if (mounted) setState(() => _canClaimBonus = true);
      } else {
        // Already claimed today
        if (mounted) setState(() => _canClaimBonus = false);
      }
    } catch (e) {
      debugPrint('Error checking bonus status: $e');
    }
  }

  Future<void> _claimDailyBonus() async {
    // Check if rewards are enabled from server
    if (DataBridge.appConfig['is_reward_enabled'] != true) {
      _showToast("Daily rewards are currently disabled.", Colors.orange);
      return;
    }

    if (!_canClaimBonus) return;

    try {
      // 1. Get Trusted Date
      final DateTime serverNowRaw = await DataBridge().fetchServerTime();
      final DateTime serverNow = serverNowRaw.toLocal();
      final todayStr =
          "${serverNow.year}-${serverNow.month.toString().padLeft(2, '0')}-${serverNow.day.toString().padLeft(2, '0')}";

      // 2. Reward Coins
      const bonusAmount = 10;
      await DataBridge().updateLocalCoins(bonusAmount);
      await DataBridge().syncCoinsWithServer();

      // 3. Increment Streak (Loop 1-10)
      int nextDay = _currentStreakDay + 1;
      if (nextDay > 10) nextDay = 1;

      // 4. Persistence (Cloud + Local)
      final updates = {
        'last_daily_bonus_claim': todayStr,
        'daily_bonus_day_count': nextDay,
      };

      // update Firestore (via IdentityManager helper or direct if needed)
      // Here we use updateLocalData to update cache, and we should also push to Firestore
      await _identityManager.patchLocalProfile(updates);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_identityManager.activeUser?.uid)
          .update(updates);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_daily_bonus_claim', todayStr);
      await prefs.setInt('daily_bonus_day_count', nextDay);

      // 5. Broadcast & State Update
      final newCoins = await DataBridge().getLocalCoins();
      DataBridge.broadcastBalance(newCoins.toInt());

      setState(() {
        _canClaimBonus = false;
        currentCoins = newCoins;
        _currentStreakDay = nextDay;
        if (userData != null) {
          userData!['last_daily_bonus_claim'] = todayStr;
          userData!['daily_bonus_day_count'] = nextDay;
        }
      });

      _showToast("🎉 You won 10 Daily Bonus Coins!", Colors.green);
    } catch (e) {
      debugPrint('Error claiming bonus: $e');
    }
  }

  String _timeUntilNextBonus() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final difference = tomorrow.difference(now);

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }

  void _showScratchCardDialog({bool isClaimed = false, int? day}) {
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissal for info view
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isClaimed ? 'Day $day Bonus' : 'Scratch & Win!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isClaimed
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 60,
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Bonus Claimed!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _timeUntilNextBonus() == '0h 0m'
                                      ? 'Come back tomorrow!'
                                      : 'Next bonus in ${_timeUntilNextBonus()}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Scratcher(
                            brushSize: 50,
                            threshold: 50,
                            color: Colors.amber, // Gold scratch layer
                            image: null,
                            onChange: (value) {},
                            onThreshold: () async {
                              // User won!
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );
                              if (mounted) {
                                Navigator.pop(context); // Close dialog first
                                _claimDailyBonus(); // Then claim
                              }
                            },
                            child: Container(
                              height: 250,
                              width: double.infinity,
                              alignment: Alignment.center,
                              color: Colors.white,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.celebration,
                                    size: 80,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'You Won!',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '10 Coins',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppPalette.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _upiController.dispose();
    _amountController.dispose();

    _coinSubscription?.cancel();
    _paymentTimeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _resetPaymentState({bool clearStoredPending = false}) {
    setState(() {
      _isPaymentProcessing = false;
      if (clearStoredPending) {
        _currentRefId = null;
      }
    });
    _paymentTimeoutTimer?.cancel();
    if (clearStoredPending) {
      _clearPendingPaymentState();
    }
  }

  Future<void> _clearPendingPaymentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingPaymentPrefsKey);
    } catch (e) {
      print('⚠️ Error clearing pending payment state: $e');
    }
  }

  Future<void> _resumePendingPaymentIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString(_pendingPaymentPrefsKey);

      if (pendingData != null) {
        final Map<String, dynamic> data = jsonDecode(pendingData);
        final refId = data['refId'];
        final coins = data['tokens']; // stored as tokens
        final price = data['price'];

        if (refId != null && mounted) {
          print('📱 Resuming pending payment check for: $refId');
          setState(() {
            _isPaymentProcessing = true;
            _currentRefId = refId;
            _selectedPackageCoins = coins ?? 0;
            _selectedPackagePrice = price ?? 0;
          });
          _startPaymentStatusCheck();
        }
      }
    } catch (e) {
      print('⚠️ Error resuming pending payment: $e');
    }
  }

  Future<void> _persistPendingPaymentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'refId': _currentRefId,
        'tokens': _selectedPackageCoins,
        'price': _selectedPackagePrice,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_pendingPaymentPrefsKey, jsonEncode(data));
    } catch (e) {
      print('⚠️ Error persisting pending payment state: $e');
    }
  }

  Future<void> _loadProcessedPaymentRefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final processedList = prefs.getStringList('processed_payment_refs') ?? [];
      setState(() {
        _processedPaymentRefs = processedList.toSet();
      });
      print('📋 Loaded ${_processedPaymentRefs.length} processed payment refs');
    } catch (e) {
      print('⚠️ Error loading processed payment refs: $e');
    }
  }

  Future<void> _saveProcessedPaymentRef(String refId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _processedPaymentRefs.add(refId);
      await prefs.setStringList(
        'processed_payment_refs',
        _processedPaymentRefs.toList(),
      );
      print('✅ Saved processed payment ref: $refId');
    } catch (e) {
      print('⚠️ Error saving processed payment ref: $e');
    }
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _showSuccessDialog(
    String title,
    String message,
    IconData icon,
    Color color,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadUserData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _hasPendingPaymentStored() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_pendingPaymentPrefsKey);
    } catch (e) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _isPaymentProcessing) {
      print('📱 App resumed - checking for payment confirmation...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkPaymentStatus();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isPaymentProcessing) {
              _checkPaymentStatus();
            }
            // Only check rewards if NOT paying
            if (mounted && !_isPaymentProcessing) {
              _checkDailyBonusStatus();
            }
          });
        }
      });
      Future.delayed(const Duration(seconds: 40), () {
        if (mounted && _isPaymentProcessing) {
          _resetPaymentState();
          _showToast('Payment timeout. Check payment history.', Colors.orange);
        }
      });
    }
  }

  // 🔥 Firebase Analytics Purchase Tracking
  Future<void> _logFirebasePurchaseEvent({
    required String transactionId,
    required double value,
    required int coinsAdded,
    required String packageName,
  }) async {
    try {
      await FirebaseAnalytics.instance.logPurchase(
        transactionId: transactionId,
        currency: 'INR', // REQUIRED
        value: value, // REQUIRED
        items: [
          AnalyticsEventItem(
            itemId: packageName,
            itemName: '$coinsAdded Coins',
            quantity: 1,
            price: value,
          ),
        ],
      );
      print('✅ Firebase Analytics: Purchase logged successfully');
    } catch (e) {
      print('❌ Firebase Analytics error logging purchase: $e');
    }
  }

  Future<Map<String, String?>> _getCampaignInfo() async {
    try {
      final campaignSource = _getCampaignSourceFromIntent();
      return {
        'source': campaignSource['source'],
        'medium': campaignSource['medium'],
        'campaign': campaignSource['campaign'],
        'campaign_id': campaignSource['campaign_id'],
      };
    } catch (e) {
      return {
        'source': null,
        'medium': null,
        'campaign': null,
        'campaign_id': null,
      };
    }
  }

  Map<String, String?> _getCampaignSourceFromIntent() {
    return {
      'source': 'google_ads',
      'medium': 'cpc',
      'campaign': 'app_install',
      'campaign_id': '',
    };
  }

  Future<void> _setUserPropertiesForTracking() async {
    try {
      final email = userData?['Email']?.toString() ?? '';
      if (email.isNotEmpty) {
        await FirebaseAnalytics.instance.setUserId(id: email);
      }
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'user_type',
        value: userGender,
      );
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'has_purchased',
        value: 'true',
      );
    } catch (e) {
      print('Error setting user properties: $e');
    }
  }

  String _getPackageName(int price) {
    for (var pkg in tokenPackages) {
      if (pkg['price'] == price) return pkg['name'];
    }
    return 'Coins Package';
  }

  Future<void> _loadUserData() async {
    final data = await _identityManager.loadProfile();
    // Ensure app config is loaded
    if (DataBridge.appConfig['paygic_mid'] == '') {
      await DataBridge().fetchAppConfig();
    }

    if (mounted) {
      final config = DataBridge.appConfig;

      setState(() {
        userData = data;
        userGender = (data?['gender'] ?? data?['Gender'] ?? 'male')
            .toString()
            .toLowerCase();

        // Use App Config values
        paygicToken = config['paygic_token']?.toString().trim();
        merchantId = config['paygic_mid']?.toString().trim();
        minDepositAmount = (config['min_deposit'] as num?)?.toDouble() ?? 79.0;
        minWithdrawalAmount =
            (config['min_withdrawal'] as num?)?.toDouble() ?? 50.0;
      });

      // ✅ Fetch REAL balance from local storage/RTDB (Source of Truth)
      final realBalance = await DataBridge().getLocalCoins();
      if (mounted) {
        setState(() {
          currentCoins = realBalance;
        });
      }

      // Update Mini package price
      for (var pkg in tokenPackages) {
        if (pkg['name'] == 'Mini') {
          pkg['price'] = minDepositAmount.toInt();
          pkg['tokens'] = minDepositAmount.toInt(); // 1:1 ratio
        }
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      // Debug Toast (Remove later)
      if (merchantId == null || merchantId!.isEmpty) {
        _showToast('Warning: MID not loaded from server', Colors.orange);
      } else {
        // _showToast('Config Loaded: MID $merchantId', Colors.green);
      }
      await _resumePendingPaymentIfAny();
      await _checkDailyBonusStatus(); // ✅ Check bonus AFTER userData is loaded
    }
  }

  final List<Map<String, dynamic>> tokenPackages = [
    {
      'name': 'Mini',
      'tokens': 89, // Generous start
      'price': 78,
      'color': Color(0xFFFFD700),
      'icon': Icons.circle,
      'popular': false,
      'discount': '',
    },
    {
      'name': 'Starter',
      'tokens': 115, // Requested
      'price': 99,
      'color': Color(0xFFFFD700),
      'icon': Icons.circle,
      'popular': false,
      'discount': '',
    },
    {
      'name': 'Silver', // Rename duplicate 'Starter' to Silver for clarity
      'tokens': 225, // Requested
      'price': 199,
      'color': Color(0xFFFFD700),
      'icon': Icons.circle,
      'popular': false,
      'discount': 'Extra 10%',
    },
    {
      'name': 'Basic',
      'tokens': 642, // Requested
      'price': 487,
      'color': Color(0xFFFFD700),
      'icon': Icons.circle,
      'popular': false,
      'discount': 'Extra 12%',
    },
    {
      'name': 'Standard',
      'tokens': 800,
      'price': 599,
      'color': Color(0xFFFFD700),
      'icon': Icons.circle,
      'popular': false,
      'discount': 'Extra 15%',
    },
    {
      'name': 'Advanced',
      'tokens': 1050,
      'price': 799,
      'color': Color(0xFFFFD700),
      'icon': Icons.circle,
      'popular': false,
      'discount': 'Extra 18%',
    },
    {
      'name': 'Popular',
      'tokens': 1300, // Generous bump
      'price': 999,
      'color': Color(0xFFFFD700),
      'icon': Icons.local_fire_department,
      'popular': true,
      'discount': 'Extra 20%',
    },
    {
      'name': 'Value Pack',
      'tokens': 1850, // Generous bump
      'price': 1499,
      'color': Color(0xFFFFD700),
      'icon': Icons.diamond,
      'popular': false,
      'discount': 'Extra 23%',
    },
    {
      'name': 'Premium',
      'tokens': 3000,
      'price': 1999,
      'color': Color(0xFFFFD700),
      'icon': Icons.diamond,
      'popular': false,
      'discount': 'Extra 25%',
    },
    {
      'name': 'Spark',
      'tokens': 4500,
      'price': 2999,
      'color': Color(0xFFFFD700),
      'icon': Icons.diamond,
      'popular': false,
      'discount': 'Extra 30%',
    },
    {
      'name': 'Great Value',
      'tokens': 8000, // Generous bump
      'price': 5499,
      'color': Color(0xFFFFD700),
      'icon': Icons.diamond,
      'popular': false,
      'discount': 'Extra 27%',
    },
    {
      'name': 'Best Saver',
      'tokens': 15000, // Generous bump
      'price': 9999,
      'color': Color(0xFFFFD700),
      'icon': Icons.diamond,
      'popular': false,
      'discount': 'Extra 35%',
    },
  ];

  Future<void> _submitWithdrawalRequest(double amount, String upi) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('User not authenticated', Colors.red);
      return;
    }

    setState(() => _isLoadingWithdrawal = true);

    try {
      final withdrawalData = {
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'status': 'pending',
        'upiId': upi,
        'userAvatar': userData?['Avatar'] ?? userData?['avatarUrl'] ?? '',
        'userId': user.uid,
        'userName': userData?['Name'] ?? userData?['username'] ?? 'User',
        'Email':
            userData?['email'] ??
            userData?['Email'] ??
            user.email ??
            '', // ✅ Added Email
        'app': 'Chilli',
      };

      await FirebaseFirestore.instance
          .collection('withdrawals')
          .add(withdrawalData);

      // Set balance to zero after withdrawal (deduct entire balance)
      final currentBalance = await DataBridge().getLocalCoins();
      await DataBridge().updateLocalCoins(currentBalance, isDeduction: true);
      await DataBridge().syncCoinsWithServer(); // Sync to Firestore

      final newCoins = 0;
      DataBridge.broadcastBalance(newCoins);

      setState(() {
        currentCoins = newCoins.toDouble();
      });

      _showToast('✅ Withdrawal request submitted successfully!', Colors.green);
      _upiController.clear();
      _amountController.clear();
    } catch (e) {
      debugPrint('Error submitting withdrawal: $e');
      _showToast('Failed to submit withdrawal: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoadingWithdrawal = false);
      }
    }
  }

  void _handleWithdraw() {
    if (_upiController.text.isEmpty) {
      _showToast('Please fill UPI ID', Colors.red);
      return;
    }
    final upiId = _upiController.text.trim();
    if (upiId.contains(' ') || !upiId.contains('@')) {
      _showToast(
        'Invalid UPI ID. UPI ID must contain @ and no spaces',
        Colors.red,
      );
      return;
    }

    late double amount;
    if (userGender == 'female') {
      amount = currentCoins.toDouble();
    } else {
      if (_amountController.text.isEmpty) {
        _showToast('Please fill all fields', Colors.red);
        return;
      }
      amount = (double.tryParse(_amountController.text) ?? 0);
    }

    if (amount < minWithdrawalAmount) {
      _showToast(
        'Minimum withdrawal amount is ₹${minWithdrawalAmount.toInt()}',
        Colors.red,
      );
      return;
    }
    if (amount > currentCoins) {
      _showToast('Insufficient balance', Colors.red);
      return;
    }

    _submitWithdrawalRequest(amount, _upiController.text);
  }

  Future<void> _initiatePayment(Map<String, dynamic> package) async {
    if (userData == null) {
      _showToast('User data not found', Colors.red);
      return;
    }
    if (_isPaymentProcessing) {
      _showToast('Payment already in progress', Colors.orange);
      return;
    }

    setState(() {
      _isPaymentProcessing = true;
    });

    _selectedPackageCoins = package['tokens'];
    _selectedPackagePrice = package['price'];

    try {
      // Refresh credentials logic if needed (simplified)
      _currentRefId = 'REF${DateTime.now().millisecondsSinceEpoch}';

      final currentUser = FirebaseAuth.instance.currentUser;

      // ✅ Robust Name Fetching
      String customerName =
          userData?['username'] ??
          userData?['Name'] ??
          currentUser?.displayName ??
          'User';

      // ✅ Robust Email Fetching
      String customerEmail =
          userData?['email'] ?? userData?['Email'] ?? currentUser?.email ?? '';
      if (customerEmail.isEmpty || !customerEmail.contains('@')) {
        customerEmail = '${customerName.replaceAll(' ', '')}@Chilli.com';
      }

      // ✅ Robust Mobile Fetching
      String customerMobile =
          userData?['phoneNumber']?.toString() ??
          userData?['phonenumber']?.toString() ??
          currentUser?.phoneNumber ??
          '';
      if (customerMobile.isEmpty || customerMobile.length < 10) {
        customerMobile = '9999999999'; // Default fallback
      }

      final response = await http
          .post(
            Uri.parse('https://server.paygic.in/api/v2/createPaymentRequest'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $paygicToken',
              'X-API-Token': '$paygicToken',
              'token': '$paygicToken',
            },
            body: jsonEncode({
              'mid': merchantId,
              'merchantReferenceId': _currentRefId,
              'amount': _selectedPackagePrice.toString(),
              'customer_name': customerName,
              'customer_email': customerEmail,
              'customer_mobile': customerMobile,
              'redirect_URL': 'https://www.nurxian.site/',
              'failed_URL': 'https://www.nurxian.site/',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == false) {
          _showToast('Payment error: ${responseData['msg']}', Colors.red);
          _resetPaymentState();
          return;
        }

        if (responseData['data'] != null &&
            responseData['data']['intent'] != null) {
          final paymentUrl = responseData['data']['intent'];
          String cleanUrl = paymentUrl.toString().trim();
          if (!cleanUrl.contains('://')) cleanUrl = 'https://$cleanUrl';

          final Uri url = Uri.parse(cleanUrl);

          bool launched = false;
          try {
            // Try launching directly, sometimes canLaunchUrl returns false for UPI intents
            launched = await launchUrl(
              url,
              mode: LaunchMode.externalApplication,
            );
          } catch (e) {
            debugPrint('⚠️ Initial launch failed: $e');
            // Fallback to simpler check
            if (await canLaunchUrl(url)) {
              launched = await launchUrl(
                url,
                mode: LaunchMode.externalApplication,
              );
            }
          }

          if (launched) {
            debugPrint('✅ Payment app launched successfully');
            // ✅ Save as PENDING immediately so history always has a record
            await _savePendingTransaction();
            await _persistPendingPaymentState();
            _startPaymentStatusCheck();
          } else {
            debugPrint('❌ Could not launch payment URL: $cleanUrl');
            _showToast(
              'No UPI app found. Please install Google Pay or PhonePe.',
              Colors.red,
            );
            // Save a failed record
            await _saveFailedTransaction('No UPI app available');
            _resetPaymentState();
          }
        }
      } else {
        _showToast('Payment gateway error: ${response.statusCode}', Colors.red);
        await _saveFailedTransaction('Gateway error ${response.statusCode}');
        _resetPaymentState();
      }
    } catch (e) {
      _showToast('Network error: $e', Colors.red);
      await _saveFailedTransaction('Network error');
      _resetPaymentState();
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (userData == null || _currentRefId == null) return;
    try {
      final response = await http
          .post(
            Uri.parse('https://server.paygic.in/api/v2/checkPaymentStatus'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $paygicToken',
              'token': '$paygicToken',
            },
            body: jsonEncode({
              'mid': merchantId,
              'merchantReferenceId': _currentRefId,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true ||
            data['status'] == 'success' ||
            data['code'] == 200) {
          await _handleSuccessfulPayment();
        }
      }
    } catch (e) {
      print('Status check error: $e');
    }
  }

  void _startPaymentStatusCheck() {
    // Auto-cancel after 30 seconds
    _paymentTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_isPaymentProcessing && mounted) {
        // Mark the pending transaction as failed/timeout in history
        _updateTransactionStatus(_currentRefId, 'failed');
        _resetPaymentState(clearStoredPending: true);
        _showToast(
          'Payment timed out. Check payment history to retry.',
          Colors.orange,
        );
      }
    });

    int attemptCount = 0;
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      attemptCount++;
      if (!mounted || _currentRefId == null || !_isPaymentProcessing) {
        timer.cancel();
        return;
      }
      await _checkPaymentStatus();
      if (attemptCount >= 40) timer.cancel();
    });
  }

  static const MethodChannel _snapchatChannel = MethodChannel(
    'snapchat_events',
  );

  Future<void> logSnapchatPurchaseEvent({
    required String transactionId,
    required double value,
    required int tokensAdded,
    required String packageName,
  }) async {
    try {
      // ✅ Now using Native SDK via MethodChannel as requested!
      // This uses the Snapchat App Ads Kit installed in Android/iOS.
      await _snapchatChannel.invokeMethod('logPurchase', {
        'amount': value,
        'currency': 'INR',
        'transactionId': transactionId,
        'packageName': packageName,
        'tokensAdded': tokensAdded,
      });
      print('✅ Snapchat: Native App Purchase Event triggered');
    } catch (e) {
      print('❌ Snapchat Native Error: $e');
      // Fallback or handle error
    }
  }

  Future<void> _handleSuccessfulPayment() async {
    final num coinsToAdd = _selectedPackageCoins;
    final String? paymentRefId = _currentRefId; // Capture before reset

    // ✅ FIX: Check if this payment has already been processed
    if (paymentRefId == null || paymentRefId.isEmpty) {
      print('⚠️ Payment refId is null or empty, skipping');
      _resetPaymentState(clearStoredPending: true);
      return;
    }

    if (_processedPaymentRefs.contains(paymentRefId)) {
      print('⚠️ Payment already processed: $paymentRefId');
      _resetPaymentState(clearStoredPending: true);
      _showToast('Payment already credited', Colors.orange);
      return;
    }

    // Mark this payment as processed IMMEDIATELY to prevent race conditions
    await _saveProcessedPaymentRef(paymentRefId);

    _resetPaymentState(clearStoredPending: true);

    final currentUser = FirebaseAuth.instance.currentUser;
    String userEmail =
        userData?['email'] ?? userData?['Email'] ?? currentUser?.email ?? '';

    // Fallback if email is still missing (e.g. Phone Login)
    if (userEmail.isEmpty || !userEmail.contains('@')) {
      final customerName =
          userData?['username'] ??
          userData?['Name'] ??
          currentUser?.displayName ??
          'User';
      userEmail = '${customerName.replaceAll(' ', '')}@Chilli.com';
      debugPrint('⚠️ User email missing, using fallback: $userEmail');
    }

    // ✅ FIX: Definitive Update
    // We override any partial updates from server by setting the verified total ourselves.
    final currentBalance = await DataBridge().getLocalCoins();
    final targetBalance = currentBalance + _selectedPackageCoins;

    debugPrint(
      '💰 Definitive Update: Curr: $currentBalance, Target: $targetBalance',
    );

    // Force set the balance (this uses setDouble internally to override)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('local_coins', targetBalance.toDouble());

    // Broadcast the new definitive value
    DataBridge.broadcastBalance(targetBalance);

    // Logging
    facebookAppEvents.setAdvertiserTracking(enabled: true);
    String hashData(String data) {
      return sha256.convert(utf8.encode(data.toLowerCase().trim())).toString();
    }

    // Facebook
    facebookAppEvents.setUserData(
      email: hashData(userEmail),
      firstName: hashData(userData?['Name']?.toString() ?? ''),
      country: hashData('India'),
    );
    facebookAppEvents.logPurchase(
      amount: _selectedPackagePrice.toDouble(),
      currency: "INR",
      parameters: {'user_id': hashData(userEmail)},
    );

    // Firebase
    await _setUserPropertiesForTracking();
    await _logFirebasePurchaseEvent(
      transactionId:
          paymentRefId ?? 'REF${DateTime.now().millisecondsSinceEpoch}',
      value: _selectedPackagePrice.toDouble(),
      coinsAdded: coinsToAdd.toInt(),
      packageName: _getPackageName(_selectedPackagePrice.toInt()),
    );

    // Snapchat
    await logSnapchatPurchaseEvent(
      transactionId:
          paymentRefId ?? 'REF${DateTime.now().millisecondsSinceEpoch}',
      value: _selectedPackagePrice.toDouble(),
      tokensAdded: coinsToAdd.toInt(),
      packageName: _getPackageName(_selectedPackagePrice.toInt()),
    );

    // Google Sheets log (stub)
    // ❌ Removed Google Sheets tracking
    final String customerName =
        userData?['username'] ??
        userData?['Name'] ??
        currentUser?.displayName ??
        'User';
    final String customerPhone =
        userData?['phoneNumber']?.toString() ??
        userData?['phonenumber']?.toString() ??
        currentUser?.phoneNumber ??
        '';

    // Firestore Data (Specific Fields)
    final firestoreData = {
      'amount': _selectedPackagePrice,
      'date': DateTime.now().toIso8601String(),
      'username': customerName, // Use consistent key
      'Email': userEmail, // ✅ Primary identifier
      'email': userEmail, // Lowercase alias for consistency
      'refid': paymentRefId ?? '',
      'phoneNumber': customerPhone, // Use consistent key
      'app name': 'Chilli',
      'tokens': coinsToAdd, // ✅ Send tokens so server can use it if configured
    };

    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .add(firestoreData);
    } catch (e) {
      print('Firestore save error: $e');
    }

    // ✅ Update existing pending record to success (or add new success record)
    await _updateTransactionStatus(paymentRefId, 'success');

    _showSuccessDialog(
      '+$coinsToAdd Coins',
      'Payment verified!',
      Icons.check_circle,
      Colors.green,
    );
  }
  /*
    final num coinsToAdd = _selectedPackageCoins;
    _resetPaymentState(clearStoredPending: true);

    String userEmail = userData?['Email']?.toString() ?? '';
    // Fallback if email is missing (e.g. Phone Login)
    if (userEmail.isEmpty || !userEmail.contains('@')) {
      userEmail =
          userData?['phoneNumber']?.toString() ??
          'user_${DateTime.now().millisecondsSinceEpoch}';
      print('⚠️ User email missing, using ID: $userEmail');
    }

    // ✅ FIX: Get current coins and ADD new amount
    final currentBalance = await DataBridge().getLocalCoins();
    final newBalance = currentBalance + coinsToAdd;

    await HttpService().updateUserTokens(userEmail, newBalance);

    setState(() {
      currentCoins = newBalance;
    });

    if (_currentRefId != null) {
      await _updatePaymentStatusToSuccess(_currentRefId!, userEmail);
    }

    // Logging
    facebookAppEvents.setAdvertiserTracking(enabled: true);
    String hashData(String data) {
      return sha256.convert(utf8.encode(data.toLowerCase().trim())).toString();
    }

    // Facebook
    facebookAppEvents.setUserData(
      email: hashData(userEmail),
      firstName: hashData(userData?['Name']?.toString() ?? ''),
      country: hashData('India'),
    );
    facebookAppEvents.logPurchase(
      amount: _selectedPackagePrice.toDouble(),
      currency: "INR",
      parameters: {'user_id': hashData(userEmail)},
    );

    // Firebase
    await _setUserPropertiesForTracking();
    await _logFirebasePurchaseEvent(
      transactionId:
          _currentRefId ?? 'REF${DateTime.now().millisecondsSinceEpoch}',
      value: _selectedPackagePrice.toDouble(),
      coinsAdded: coinsToAdd.toInt(),
      packageName: _getPackageName(_selectedPackagePrice.toInt()),
    );

    // Snapchat
    await logSnapchatPurchaseEvent(
      transactionId:
          _currentRefId ?? 'REF${DateTime.now().millisecondsSinceEpoch}',
      value: _selectedPackagePrice.toDouble(),
      tokensAdded: coinsToAdd.toInt(),
      packageName: _getPackageName(_selectedPackagePrice.toInt()),
    );

    // Google Sheets log (stub)
    _googleSheetsService.logPayment(
      email: userEmail,
      userName: userData?['Name']?.toString() ?? 'User',
      amount: _selectedPackagePrice.toDouble(),
      tokens: coinsToAdd.toInt(),
      referenceId: _currentRefId ?? '',
      paymentStatus: 'success',
      userGender: userGender,
      deviceInfo: 'App',
      appVersion: '1.0',
    );

    // Save to Firestore & Local
    final transactionData = {
      'amount': _selectedPackagePrice,
      'tokens': coinsToAdd,
      'date': DateTime.now().toIso8601String(),
      'status': 'success',
      'type': 'deposit',
      'refId': _currentRefId,
      'email': userEmail,
    };

    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .add(transactionData);
    } catch (e) {
      print('Firestore save error: $e');
    }

    await _saveLocalTransaction(transactionData);

    _showSuccessDialog(
      '+$coinsToAdd Coins',
      'Payment verified!',
      Icons.check_circle,
      Colors.green,
    );
  } */

  Future<void> _saveLocalTransaction(Map<String, dynamic> transaction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString =
          prefs.getString('local_transaction_history') ?? '[]';
      final List<dynamic> currentHistory = jsonDecode(historyString);

      currentHistory.add(transaction);

      await prefs.setString(
        'local_transaction_history',
        jsonEncode(currentHistory),
      );
    } catch (e) {
      print('Error saving local transaction: $e');
    }
  }

  /// Save an immediate PENDING record when the UPI app is launched.
  Future<void> _savePendingTransaction() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail =
        userData?['email'] ?? userData?['Email'] ?? currentUser?.email ?? '';
    final transactionData = {
      'amount': _selectedPackagePrice,
      'tokens': _selectedPackageCoins,
      'date': DateTime.now().toIso8601String(),
      'status': 'pending',
      'type': 'deposit',
      'refId': _currentRefId,
      'email': userEmail,
      // Store credentials so TxnScreen can check status independently
      'mid': merchantId ?? '',
      'token': paygicToken ?? '',
    };
    await _saveLocalTransaction(transactionData);
  }

  /// Save a FAILED record (e.g., network error, no UPI app).
  Future<void> _saveFailedTransaction(String reason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail =
        userData?['email'] ?? userData?['Email'] ?? currentUser?.email ?? '';
    final transactionData = {
      'amount': _selectedPackagePrice,
      'tokens': _selectedPackageCoins,
      'date': DateTime.now().toIso8601String(),
      'status': 'failed',
      'type': 'deposit',
      'refId': _currentRefId,
      'email': userEmail,
      'failReason': reason,
      'mid': merchantId ?? '',
      'token': paygicToken ?? '',
    };
    await _saveLocalTransaction(transactionData);
  }

  /// Update the status of an existing transaction record by refId.
  Future<void> _updateTransactionStatus(String? refId, String newStatus) async {
    if (refId == null || refId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString =
          prefs.getString('local_transaction_history') ?? '[]';
      final List<dynamic> currentHistory = jsonDecode(historyString);

      bool updated = false;
      for (int i = currentHistory.length - 1; i >= 0; i--) {
        final item = currentHistory[i] as Map<String, dynamic>;
        if (item['refId'] == refId && item['status'] == 'pending') {
          currentHistory[i]['status'] = newStatus;
          updated = true;
          break;
        }
      }

      if (updated) {
        await prefs.setString(
          'local_transaction_history',
          jsonEncode(currentHistory),
        );
        print('✅ Updated transaction $refId → $newStatus');
      }
    } catch (e) {
      print('Error updating transaction status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF06010F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF2D78)),
        ),
      );
    }

    if (userGender == 'female') {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: _buildCleanWithdrawalUI(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _buildProfessionalRechargeUI(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildCleanWithdrawalUI() {
    return SafeArea(
      child: Column(
        children: [
          _buildCleanHeader(title: 'Withdraw Funds', isWithdrawal: true),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  _buildCleanBalanceCard(),
                  const SizedBox(height: 32),
                  _buildCleanUpiInput(),
                  const SizedBox(height: 40),
                  _buildCleanWithdrawBtn(),
                  const SizedBox(height: 24),
                  _buildCleanSecurityInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanHeader({
    required String title,
    required bool isWithdrawal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ),
          if (Navigator.canPop(context)) const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TxnScreen(isWithdrawal: isWithdrawal),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.history_rounded, color: Colors.black87, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'History',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141E30), Color(0xFF243B55)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF141E30).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Available Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currentCoins.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCleanUpiInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transfer Destination',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _upiController,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter UPI ID (e.g. name@upi)',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(
                Icons.payment_rounded,
                color: Color(0xFF243B55),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Funds will be transferred to this UPI ID within 24 hours.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCleanWithdrawBtn() {
    return GestureDetector(
      onTap: _isLoadingWithdrawal ? null : _handleWithdraw,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF243B55),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF243B55).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoadingWithdrawal
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Withdraw Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCleanSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_outline_rounded, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text(
            "Secured & Encrypted Transaction",
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalRechargeUI() {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: SafeArea(
        child: Column(
          children: [
            _buildCleanHeader(title: 'Recharge', isWithdrawal: false),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildCleanBalanceCard(),
            ),
            if (_isPaymentProcessing) _buildCleanPaymentProgress(),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: tokenPackages.length,
                itemBuilder: (context, index) =>
                    _buildProfessionalGridCard(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanPaymentProgress() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Processing Payment...',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => _resetPaymentState(clearStoredPending: true),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalGridCard(int index) {
    final package = tokenPackages[index];
    final isSelected = _tempSelectedIndex == index;
    final isPopular = package['popular'] == true;
    final discount = package['discount'];
    final coins = package['tokens'];
    final price = package['price'];

    return GestureDetector(
      onTap: () {
        setState(() => _tempSelectedIndex = index);
        _initiatePayment(package);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF243B55)
                : Colors.grey.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF243B55).withOpacity(0.15)
                  : Colors.black.withOpacity(0.03),
              blurRadius: isSelected ? 15 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFFFFD700),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (coins as num).toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'Coins',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF243B55)
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '₹${(price as num).toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF243B55),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (discount != null && discount.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    discount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isPopular)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9B7D),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (!_isPaymentProcessing) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: () {
        _resetPaymentState(clearStoredPending: true);
        _showToast('Payment cancelled', Colors.orange);
      },
      backgroundColor: const Color(0xFFE53935),
      icon: const Icon(Icons.close_rounded, color: Colors.white),
      label: const Text(
        'Cancel Payment',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00F5FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.verified_user_rounded, color: Color(0xFF00F5FF), size: 22),
          SizedBox(width: 10),
          Text(
            "100% Secure & Encrypted",
            style: TextStyle(
              color: Color(0xFF00F5FF),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
