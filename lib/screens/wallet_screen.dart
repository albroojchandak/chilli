import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:scratcher/scratcher.dart';
import 'package:chilli/theme/palette.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/screens/txn_screen.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:paygic/paygic.dart';
import 'package:url_launcher/url_launcher.dart';

class ChilliWalletScreen extends StatefulWidget {
  const ChilliWalletScreen({super.key});

  @override
  State<ChilliWalletScreen> createState() => _ChilliWalletScreenState();
}

class _ChilliWalletScreenState extends State<ChilliWalletScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _identity = IdentityManager();
  final _bridge = DataBridge();
  final _auth = FirebaseAuth.instance;

  num _coins = 0;
  bool _isLoading = true;
  bool _isClaimable = false;
  int _streakDay = 1;
  bool _isPaying = false;

  final List<Map<String, dynamic>> _packages = [
    {'coins': 5, 'price': 5, 'bonus': 0, 'popular': false},
    {'coins': 10, 'price': 10, 'bonus': 0, 'popular': false},
    {'coins': 100, 'price': 79, 'bonus': 0, 'popular': false},
    {'coins': 250, 'price': 199, 'bonus': 10, 'popular': true},
    {'coins': 500, 'price': 399, 'bonus': 25, 'popular': false},
    {'coins': 1200, 'price': 799, 'bonus': 100, 'popular': false},
  ];

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);

  late final AnimationController _glowController;
  Timer? _paymentTimeoutTimer;
  String? _currentRefId;
  Map? _currentPkg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _loadBalance();
    _checkBonus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPaying && _currentRefId != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkPaymentStatusPolled();
      });
    }
  }

  void _loadBalance() async {
    final c = await _bridge.getLocalCoins();
    if (mounted) setState(() { _coins = c; _isLoading = false; });
    DataBridge.balanceStream.listen((c) { if (mounted) setState(() => _coins = c); });
  }

  void _checkBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString('last_bonus_claim_date') ?? '';
    final streak = prefs.getInt('bonus_streak_count') ?? 0;
    
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    
    if (lastStr == todayStr) {
      setState(() {
        _isClaimable = false;
        _streakDay = streak;
      });
    } else {
      int nextStreak = 1;
      if (lastStr.isNotEmpty) {
        try {
          final parts = lastStr.split('-');
          final lastDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final diff = DateTime(now.year, now.month, now.day).difference(lastDate).inDays;
          
          if (diff == 1) {
            nextStreak = (streak % 7) + 1;
          } else {
            nextStreak = 1;
          }
        } catch (_) {
          nextStreak = 1;
        }
      }
      setState(() {
        _isClaimable = true;
        _streakDay = nextStreak;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentTimeoutTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: _neonCyan))
            : _buildBody(),
        ),
        if (_isPaying)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _neonCyan),
                    SizedBox(height: 20),
                    Text('INITIATING PAYMENT...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    SizedBox(height: 8),
                    Text('Please do not close the app', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      title: const Text('WALLET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white70),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TxnScreen())),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 32),
          _buildDailyRewardSection(),
          const SizedBox(height: 32),
          _buildSectionHeader('TOP UP COINS'),
          const SizedBox(height: 16),
          _buildPackageGrid(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _neonViolet.withOpacity(0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _neonViolet.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: _neonViolet.withOpacity(0.1), blurRadius: 40, spreadRadius: -10)],
      ),
      child: Column(
        children: [
          Text('CURRENT BALANCE', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.toll_rounded, color: Colors.amber, size: 40),
              const SizedBox(width: 16),
              Text(
                _coins.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_rounded, color: _neonCyan, size: 14),
          const SizedBox(width: 8),
          Text('SECURE WALLET', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.5));
  }

  Widget _buildDailyRewardSection() {
    final List<int> rewards = [5, 11, 17, 23, 29, 35, 51];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('DAILY REWARDS'),
            if (_isClaimable) 
              GestureDetector(
                onTap: _handleClaim,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _neonPink.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: _neonPink.withOpacity(0.5))),
                  child: const Text('CLAIM NOW', style: TextStyle(color: _neonPink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            itemBuilder: (context, i) {
              final day = i + 1;
              final isToday = day == _streakDay && _isClaimable;
              final isClaimed = day < _streakDay || (day == _streakDay && !_isClaimable);
              final isFuture = day > _streakDay;
              
              return Container(
                width: 75,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isToday ? _neonPink.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isToday ? _neonPink : (isClaimed ? _neonCyan.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                    width: isToday ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('DAY $day', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Icon(
                      isClaimed ? Icons.check_circle_rounded : Icons.toll_rounded,
                      color: isClaimed ? _neonCyan : (isToday ? _neonPink : Colors.amber.withOpacity(0.5)),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text('${rewards[i]}', style: TextStyle(color: isToday ? _neonPink : Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showScratchDialog() {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          height: 350,
          width: 300,
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(32), border: Border.all(color: _neonViolet.withOpacity(0.5))),
          child: Scratcher(
            brushSize: 50,
            threshold: 50,
            color: _neonViolet,
            onThreshold: () => _handleClaim(),
            child: Container(
              color: _surface,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars_rounded, color: Colors.amber, size: 80),
                  SizedBox(height: 16),
                  Text('YOU WON!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  Text('10 COINS', style: TextStyle(color: _neonCyan, fontSize: 24, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleClaim() async {
    if (!_isClaimable) return;
    
    final List<int> rewards = [5, 11, 17, 23, 29, 35, 51];
    final reward = rewards[_streakDay - 1];
    
    setState(() => _isPaying = true);
    await Future.delayed(const Duration(seconds: 1));

    try {
      await _bridge.updateLocalCoins(reward);
      
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance.ref().child('users').child(user.uid).update({
          'coins': ServerValue.increment(reward)
        });
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'coins': FieldValue.increment(reward)
        });
      }

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString('last_bonus_claim_date', "${now.year}-${now.month}-${now.day}");
      await prefs.setInt('bonus_streak_count', _streakDay);
      
      if (mounted) {
        setState(() {
          _isClaimable = false;
          _isPaying = false;
        });
        _showToast('CLAIMED $reward COINS!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        _showToast('Claim Failed');
      }
    }
  }

  Widget _buildPackageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _packages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
      itemBuilder: (context, i) => _buildPackageCard(_packages[i]),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    return GestureDetector(
      onTap: () => _startPurchase(pkg),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pkg['popular'] ? _neonCyan : Colors.white.withOpacity(0.08), width: 2),
        ),
        child: Stack(
          children: [
            if (pkg['popular']) Positioned(top: 0, right: 0, child: _buildPopularBadge()),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.toll_rounded, color: Colors.amber, size: 32),
                  const SizedBox(height: 12),
                  Text(pkg['coins'].toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  Text('COINS', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w800)),
                  if (pkg['bonus'] > 0) Text('+${pkg['bonus']} BONUS', style: const TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: _neonCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('₹${pkg['price']}', style: const TextStyle(color: _neonCyan, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(color: _neonCyan, borderRadius: BorderRadius.only(topRight: Radius.circular(22), bottomLeft: Radius.circular(12))),
      child: const Text('BEST', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  void _startPurchase(Map pkg) async {
    setState(() => _isPaying = true);
    
    final user = _auth.currentUser;
    final price = (pkg['price'] as num).toDouble();
    
    String mobile = user?.phoneNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '9999999999';
    if (mobile.length > 10) {
      mobile = mobile.substring(mobile.length - 10);
    } else if (mobile.length < 10) {
      mobile = '9999999999';
    }

    try {
      final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJtaWQiOiJDSElUQ0hBVFoiLCJfaWQiOiI2ODVmY2VlYjFhOWQ4NDQ0YjRjZGI5OGEiLCJpYXQiOjE3Nzc5MDA2OTEsImV4cCI6MTc4MDQ5MjY5MX0.cqL4D0Le3fxD7ZhXl6ckbnbaBURW_AuGiw7ip-VBoyk';
      final mref = 'ORD_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse('https://server.paygic.in/api/v2/createPaymentRequest'),
        headers: {
          'Content-Type': 'application/json',
          'token': token,
        },
        body: jsonEncode({
          'mid': 'CHITCHATZ',
          'amount': price,
          'merchantReferenceId': mref,
          'customer_name': user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Chilli User',
          'customer_email': user?.email?.isNotEmpty == true ? user!.email! : 'user@chilli.app',
          'customer_mobile': mobile,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['status'] == true && data['data'] != null && data['data']['intent'] != null) {
        final intentUrl = data['data']['intent'];

        final uri = Uri.parse(intentUrl);
        if (await canLaunchUrl(uri)) {
           await launchUrl(uri, mode: LaunchMode.externalApplication);
           
           if (!mounted) return;
           _startPaymentStatusCheck(mref, pkg);
        } else {
           _showToast('No UPI app found to handle payment');
           setState(() => _isPaying = false);
        }
      } else {
         _showToast('Failed to create payment request');
         setState(() => _isPaying = false);
      }
    } catch (e) {
      if (mounted) {
        _showToast('Error initiating payment');
        setState(() => _isPaying = false);
      }
    }
  }

  void _startPaymentStatusCheck(String mref, Map pkg) {
    _currentRefId = mref;
    _currentPkg = pkg;
    
    _paymentTimeoutTimer?.cancel();
    _paymentTimeoutTimer = Timer(const Duration(seconds: 120), () {
      if (_isPaying && mounted) {
        setState(() => _isPaying = false);
        _currentRefId = null;
        _currentPkg = null;
        _showToast('Payment timeout. Please try again.');
      }
    });

    int attemptCount = 0;
    // Increased to 10 seconds to avoid Paygic API "Too many OTP requests" rate limit
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      attemptCount++;
      if (!mounted || !_isPaying || _currentRefId == null) {
        timer.cancel();
        return;
      }
      await _checkPaymentStatusPolled();
      if (attemptCount >= 12) timer.cancel();
    });
  }

  Future<void> _checkPaymentStatusPolled() async {
    if (_currentRefId == null || _currentPkg == null) return;
    try {
      final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJtaWQiOiJDSElUQ0hBVFoiLCJfaWQiOiI2ODVmY2VlYjFhOWQ4NDQ0YjRjZGI5OGEiLCJpYXQiOjE3Nzc5MDA2OTEsImV4cCI6MTc4MDQ5MjY5MX0.cqL4D0Le3fxD7ZhXl6ckbnbaBURW_AuGiw7ip-VBoyk';
      
      final response = await http.post(
        Uri.parse('https://server.paygic.in/api/v2/checkPaymentStatus'),
        headers: {
          'Content-Type': 'application/json',
          'token': token,
        },
        body: jsonEncode({
          'mid': 'CHITCHATZ',
          'merchantReferenceId': _currentRefId,
        }),
      );

      if (response.statusCode == 429 || response.body.contains('Too many')) {
        return; // Rate limited, ignore and wait for next poll
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extract exact transaction status properly
        final dynamic statusVal = (data['data'] != null && data['data']['txnStatus'] != null) 
            ? data['data']['txnStatus'] 
            : (data['txnStatus'] ?? data['status']);
            
        final txnStatus = statusVal.toString().toUpperCase();
        
        if (txnStatus == 'SUCCESS') {
          _paymentTimeoutTimer?.cancel();
          final pkg = _currentPkg!;
          _currentRefId = null;
          _currentPkg = null;
          
          final coinsToAdd = (pkg['coins'] as num) + (pkg['bonus'] as num);
          await _bridge.updateLocalCoins(coinsToAdd, isDeduction: false);
          final user = _auth.currentUser;
          if (user != null) {
            await FirebaseDatabase.instance.ref().child('users').child(user.uid).update({
              'coins': ServerValue.increment(coinsToAdd)
            });
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'coins': FieldValue.increment(coinsToAdd)
            });
          }
          if (mounted) {
            setState(() => _isPaying = false);
            _showToast('SUCCESS! Credited $coinsToAdd coins');
          }
        } else if (txnStatus == 'FAILED' || txnStatus == 'CANCELLED') {
          _paymentTimeoutTimer?.cancel();
          _currentRefId = null;
          _currentPkg = null;
          if (mounted) {
            setState(() => _isPaying = false);
            _showToast('Payment $txnStatus');
          }
        }
        // If PENDING, we do nothing and let it continue polling
      }
    } catch (e) {
      // Ignore transient errors during polling
    }
  }

  void _showToast(String m) => Fluttertoast.showToast(msg: m, backgroundColor: _neonViolet);
  static const _surface = Color(0xFF1A1030);
}
