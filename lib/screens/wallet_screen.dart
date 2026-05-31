import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/material.dart';
import 'package:chilli/theme/palette.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chilli/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/services/data_bridge.dart';

import 'package:chilli/theme/palette.dart';
import 'package:chilli/screens/txn_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:crypto/crypto.dart';
import 'package:scratcher/scratcher.dart';

import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentcomponents/cfpaymentcomponent.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

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

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final IdentityManager _AuthenticationService = IdentityManager();

  // Using Palette for consistency, mapped to local variables for ease of porting
  final primaryColor = Palette.primary; // Was Color(0xFF6A98F0)
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
    'primary': Palette.primary,
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
  final DataBridge _HttpService = DataBridge();
  var cfPaymentGatewayService = CFPaymentGatewayService();
  // balanceupa() async {
  //   await _HttpService.updateLocalCoins(102);
  // }

  @override
  void initState() {
    super.initState();
    cfPaymentGatewayService.setCallback(verifyPayment, onError);
    // balanceupa();
    _loadUserData();
    _loadProcessedPaymentRefs(); // Load processed payments to prevent duplicates
    WidgetsBinding.instance.addObserver(this);

    // ✅ Auto-check last unresolved payment status on page open
    // Delayed so that _loadUserData() finishes first (credentials needed)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkLastPendingPaymentOnStart();
    });

    _coinSubscription = DataBridge.tokenStream.listen((newCoins) {
      if (mounted) {
        setState(() {
          currentCoins = newCoins;
        });
        print('💰 WalletScreen: Coins updated to $newCoins');
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

      // Resolve credentials: use Cashfree from app config
      final String appId = DataBridge.appConfig['cashfree_app_id']?.toString() ?? '';
      final String secretKey = DataBridge.appConfig['cashfree_secret_key']?.toString() ?? '';

      if (appId.isEmpty || secretKey.isEmpty) {
        print('⚠️ Auto-check: credentials not ready yet, skipping.');
        return;
      }

      print('🔄 Auto-checking payment status for refId: $refId');

      final response = await http.get(
        Uri.parse('https://api.cashfree.com/pg/orders/$refId'),
        headers: {
          'x-client-id': appId,
          'x-client-secret': secretKey,
          'x-api-version': '2023-08-01',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('⚠️ Auto-check: server returned ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);
      final txnStatus = data['order_status']?.toString().toUpperCase() ?? '';
      final isSuccess = txnStatus == 'PAID';

      print('🔍 Auto-check result for $refId → txnStatus: $txnStatus');

      if (!isSuccess) {
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
        DataBridge.broadcastTokenUpdate(newBalance.toInt());
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
      final DateTime serverNowRaw = await DataBridge().getServerDate();
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
      final DateTime serverNowRaw = await DataBridge().getServerDate();
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
      await _AuthenticationService.updateLocalData(updates);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_AuthenticationService.currentUser?.uid)
          .update(updates);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_daily_bonus_claim', todayStr);
      await prefs.setInt('daily_bonus_day_count', nextDay);

      // 5. Broadcast & State Update
      final newCoins = await DataBridge().getLocalCoins();
      DataBridge.broadcastTokenUpdate(newCoins.toInt());

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
                        color: Palette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Palette.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Palette.textPrimary,
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
                              color: Palette.textPrimary,
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
                                      color: Palette.primary,
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
      textColor: Palette.textPrimary,
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
            color: Palette.textPrimary,
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
                    color: Palette.textPrimary,
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
    final data = await _AuthenticationService.getUserData();
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
      'name': 'Elite',
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
        'app': 'chilli',
      };

      await FirebaseFirestore.instance
          .collection('withdrawals')
          .add(withdrawalData);

      // Set balance to zero after withdrawal (deduct entire balance)
      final currentBalance = await DataBridge().getLocalCoins();
      await DataBridge().updateLocalCoins(currentBalance, isDeduction: true);
      await DataBridge().syncCoinsWithServer(); // Sync to Firestore

      final newCoins = 0;
      DataBridge.broadcastTokenUpdate(newCoins);

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

  void verifyPayment(String orderId) {
    debugPrint("✅ Cashfree Verify Payment for $orderId");
    if (mounted) {
      setState(() {
        _currentRefId = orderId;
      });
      _handleSuccessfulPayment();
    }
  }

  void onError(CFErrorResponse errorResponse, String orderId) {
    debugPrint("❌ Cashfree Error: ${errorResponse.getMessage()}");
    _showToast('Payment Error: ${errorResponse.getMessage()}', Colors.red);
    _resetPaymentState();
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
      _currentRefId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';

      final currentUser = FirebaseAuth.instance.currentUser;

      String customerName = userData?['username'] ?? userData?['Name'] ?? currentUser?.displayName ?? 'User';
      String customerEmail = userData?['email'] ?? userData?['Email'] ?? currentUser?.email ?? '';
      if (customerEmail.isEmpty || !customerEmail.contains('@')) {
        customerEmail = '${customerName.replaceAll(' ', '')}@chilli.com';
      }

      String customerMobile = userData?['phoneNumber']?.toString() ?? userData?['phonenumber']?.toString() ?? currentUser?.phoneNumber ?? '';
      if (customerMobile.isEmpty || customerMobile.length < 10) {
        customerMobile = '9999999999';
      }

      final String appId = DataBridge.appConfig['cashfree_app_id']?.toString() ?? '';
      final String secretKey = DataBridge.appConfig['cashfree_secret_key']?.toString() ?? '';

      if (appId.isEmpty || secretKey.isEmpty) {
        _showToast('Payment configuration missing', Colors.red);
        _resetPaymentState();
        return;
      }

      // Call Cashfree API directly to create order and get payment session id
      final response = await http
          .post(
            Uri.parse('https://api.cashfree.com/pg/orders'),
            headers: {
              'x-client-id': appId,
              'x-client-secret': secretKey,
              'x-api-version': '2023-08-01',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'order_id': _currentRefId,
              'order_amount': _selectedPackagePrice,
              'order_currency': 'INR',
              'customer_details': {
                'customer_id': 'cust_${DateTime.now().millisecondsSinceEpoch}',
                'customer_name': customerName,
                'customer_email': customerEmail,
                'customer_phone': customerMobile,
              },
              'order_meta': {
                 'return_url': 'https://www.nurxian.site/?order_id={order_id}',
              }
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final sessionId = responseData['payment_session_id'];

        if (sessionId != null) {
          try {
            var session = CFSessionBuilder()
                .setEnvironment(CFEnvironment.PRODUCTION)
                .setOrderId(_currentRefId!)
                .setPaymentSessionId(sessionId)
                .build();
            
            var theme = CFThemeBuilder()
                .setNavigationBarBackgroundColorColor("#0F0A1E")
                .setPrimaryFont("Roboto")
                .setSecondaryFont("Roboto")
                .build();
                
            var cfDropCheckoutPayment = CFDropCheckoutPaymentBuilder()
                .setSession(session)
                .setTheme(theme)
                .build();

            await _savePendingTransaction();
            await _persistPendingPaymentState();

            cfPaymentGatewayService.doPayment(cfDropCheckoutPayment);
          } on CFException catch (e) {
            _showToast('Cashfree init error: ${e.message}', Colors.red);
            _resetPaymentState();
          }
        } else {
          _showToast('Failed to generate payment session', Colors.red);
          _resetPaymentState();
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
    
    final String appId = DataBridge.appConfig['cashfree_app_id']?.toString() ?? '';
    final String secretKey = DataBridge.appConfig['cashfree_secret_key']?.toString() ?? '';
    
    if (appId.isEmpty || secretKey.isEmpty) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://api.cashfree.com/pg/orders/$_currentRefId'),
        headers: {
          'x-client-id': appId,
          'x-client-secret': secretKey,
          'x-api-version': '2023-08-01',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['order_status'] == 'PAID') {
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
      userEmail = '${customerName.replaceAll(' ', '')}@chilli.com';
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
    DataBridge.broadcastTokenUpdate(targetBalance);

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
      'app name': 'chilli',
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

    await DataBridge().updateUserTokens(userEmail, newBalance);

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


  Widget _buildUniqueHeader(BuildContext context, bool isFemale, num currentCoins) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Deep Slate
            Color(0xFF3B82F6), // Vibrant Blue
          ],
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative Watermark Icon
          Positioned(
            right: -20,
            top: -20,
            child: Transform.rotate(
              angle: -0.2,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context)) ...[
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFemale ? 'My Earnings' : 'Wallet',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFemale ? 'Withdraw' : 'Store',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!isFemale) ...[
                        // Debug button for Male
                        GestureDetector(
                          onTap: () async {
                            await DataBridge().updateLocalCoins(1000);
                            await DataBridge().syncCoinsWithServer();
                            _showToast('Debug: Added 1000 coins', Colors.green);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              '+1000',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TxnScreen(isWithdrawal: isFemale),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Balance Row
              Text(
                'Available Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    currentCoins.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    // Show withdrawal page for female users
    if (userGender == 'female') {
      return Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Stack(
          children: [
            // Background ambient glows
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      blurRadius: 100,
                      spreadRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEAB308).withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEAB308).withValues(alpha: 0.1),
                      blurRadius: 100,
                      spreadRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                _buildUniqueHeader(context, true, currentCoins),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 24),
                    physics: const BouncingScrollPhysics(),
                    children: [_buildWithdrawalSection()],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Recharge page for male users
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                // blur using BoxShadow
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              _buildUniqueHeader(context, false, currentCoins),
              if (_isPaymentProcessing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment in progress...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Click cancel if payment failed or was cancelled.',
                                style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _resetPaymentState(clearStoredPending: true),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Packages Grid - Scrollable with all packages
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(), // Enable scrolling
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.88,
                        ),
                    itemCount: tokenPackages.length, // Show all packages
                    itemBuilder: (context, index) => _buildRechargeCard(index),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeCard(int index) {
    final package = tokenPackages[index];
    final coins = package['tokens'];
    final price = package['price'];
    final isPopular = package['popular'] ?? false;

    // Calculate savings
    final baseValue = price * 1.0;
    final actualValue = coins.toDouble();
    final savings = (actualValue - baseValue).toInt();

    return GestureDetector(
      onTap: () {
        setState(() {
          _tempSelectedIndex = index;
        });
        _initiatePayment(package);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPopular
                ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                : Palette.textPrimary.withValues(alpha: 0.1),
            width: isPopular ? 2 : 1,
          ),
          boxShadow: [
            if (isPopular)
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Palette.textPrimary.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Coins Number
                Text(
                  '$coins',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Palette.textPrimary,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                // "coins" label
                Text(
                  'coins',
                  style: TextStyle(
                    fontSize: 12,
                    color: Palette.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                // Divider
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Palette.textPrimary.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.currency_rupee_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                    Text(
                      '$price',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Popular badge
            if (isPopular)
              Positioned(
                top: -30,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'HOT DEAL',
                    style: TextStyle(
                      color: Palette.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
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
    // Only show button if processing (to allow cancel)
    if (!_isPaymentProcessing) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          _resetPaymentState(clearStoredPending: true);
          _showToast('Payment cancelled', Colors.orange);
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.cancel_rounded, color: Palette.textPrimary),
        label: const Text(
          'Cancel Payment',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Palette.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildWithdrawalSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildWithdrawalForm(),
          const SizedBox(height: 20),
          _buildSecurityInfo(),
        ],
      ),
    );
  }

  Widget _buildWithdrawalForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Palette.textPrimary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Palette.textPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Withdraw Funds',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Palette.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Transfer to your UPI account',
                      style: TextStyle(
                        color: Palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Balance Display Card (Glassmorphic)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Palette.textPrimary.withValues(alpha: 0.1),
                  Palette.textPrimary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Palette.textPrimary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Palette.textPrimary.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹',
                          style: TextStyle(
                            color: Palette.textPrimary.withValues(alpha: 0.8),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          (currentCoins).toStringAsFixed(2),
                          style: const TextStyle(
                            color: Palette.textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Palette.textPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Palette.textPrimary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Palette.textPrimary,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // UPI Input Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPI ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Palette.textPrimary.withValues(alpha: 0.7),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Palette.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Palette.textPrimary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _upiController,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Palette.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'username@paytm',
                    hintStyle: TextStyle(
                      color: Colors.white24,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Palette.textPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.payment_rounded,
                        color: Palette.textPrimary,
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Withdraw Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoadingWithdrawal ? null : _handleWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoadingWithdrawal
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Palette.textPrimary,
                        strokeWidth: 3,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          color: Palette.textPrimary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Withdraw Now',
                          style: TextStyle(
                            color: Palette.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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

  Widget _buildPackageButton(int index) {
    final package = tokenPackages[index];
    final isSelected = _tempSelectedIndex == index;
    final discount = package['discount'];
    final isPopular = package['popular'] == true;

    return GestureDetector(
      onTap: () {
        debugPrint('🚀 Direct launch for package index: $index');
        setState(() {
          _tempSelectedIndex = index;
        });

        // Single tap launch as requested
        _initiatePayment(package);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Palette.textPrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Palette.primary
                    : (isPopular
                          ? Colors.orange.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.1)),
                width: isSelected ? 4 : (isPopular ? 2 : 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Palette.primary.withValues(alpha: 0.3)
                      : (isPopular
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.05)),
                  blurRadius: isSelected ? 12 : 8,
                  offset: isSelected ? const Offset(0, 6) : const Offset(0, 4),
                ),
              ],
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        Palette.primary.withValues(alpha: 0.15),
                        Colors.white,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(package['icon'], color: package['color'], size: 28),
                const SizedBox(height: 6),
                Text(
                  '${package['tokens']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Coins',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isPopular
                        ? Palette.primary
                        : Palette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    gradient: isPopular
                        ? const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '₹${package['price']}',
                      style: TextStyle(
                        color: isPopular ? Colors.white : Palette.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (discount != null && discount.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4757),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Text(
                  discount,
                  style: const TextStyle(
                    color: Palette.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (isPopular)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Palette.primary : Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isSelected ? Palette.primary : Colors.orange)
                                .withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    isSelected ? 'SELECTED' : 'POPULAR',
                    style: const TextStyle(
                      color: Palette.textPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          if (isSelected && !isPopular)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.primary.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Palette.textPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.security, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your payment is 100% secure.",
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Column(
      children: [
        ExpansionTile(
          title: const Text("Is it secure?"),
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Yes, 100% secure."),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text("When are coins added?"),
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Instantly after payment."),
            ),
          ],
        ),
      ],
    );
  }
}


