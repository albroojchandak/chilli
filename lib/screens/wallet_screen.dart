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

class ChilliWalletScreen extends StatefulWidget {
  const ChilliWalletScreen({super.key});

  @override
  State<ChilliWalletScreen> createState() => _ChilliWalletScreenState();
}

class _ChilliWalletScreenState extends State<ChilliWalletScreen> with SingleTickerProviderStateMixin {
  final _identity = IdentityManager();
  final _bridge = DataBridge();
  final _auth = FirebaseAuth.instance;

  num _coins = 0;
  bool _isLoading = true;
  bool _isClaimable = false;
  int _streakDay = 1;
  bool _isPaying = false;

  final List<Map<String, dynamic>> _packages = [
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

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _loadBalance();
    _checkBonus();
  }

  void _loadBalance() async {
    final c = await _bridge.getLocalCoins();
    if (mounted) setState(() { _coins = c; _isLoading = false; });
    DataBridge.balanceStream.listen((c) { if (mounted) setState(() => _coins = c); });
  }

  void _checkBonus() async {
    final enabled = DataBridge.appConfig['is_reward_enabled'] == true;
    if (!enabled) return;
    
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_bonus_claim') ?? '';
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";
    
    setState(() {
      _isClaimable = last != today;
      _streakDay = prefs.getInt('bonus_streak') ?? 1;
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonCyan))
        : _buildBody(),
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
    return GestureDetector(
      onTap: _isClaimable ? _showScratchDialog : null,
      child: Opacity(
        opacity: _isClaimable ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_neonPink.withOpacity(0.2), Colors.transparent]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _neonPink.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _neonPink.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.card_giftcard_rounded, color: _neonPink, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Reward', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(_isClaimable ? 'Tap to scratch and win coins!' : 'Come back tomorrow for more', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ),
              if (_isClaimable) const Icon(Icons.chevron_right_rounded, color: _neonPink),
            ],
          ),
        ),
      ),
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
    Navigator.pop(context);
    await _bridge.updateLocalCoins(10);
    await _bridge.syncCoinsWithServer();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString('last_bonus_claim', "${now.year}-${now.month}-${now.day}");
    _checkBonus();
    _showToast('Claimed 10 coins!');
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
    // Implement Paygic or Razorpay logic here
    _showToast('Starting payment for ₹${pkg['price']}...');
  }

  void _showToast(String m) => Fluttertoast.showToast(msg: m, backgroundColor: _neonViolet);
  static const _surface = Color(0xFF1A1030);
}
