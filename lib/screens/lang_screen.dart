import 'package:flutter/material.dart';
import 'package:chilli/services/firestore_repo.dart';
import 'package:chilli/services/push_receiver.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final String username;
  final String gender;
  final String? avatar;
  final String? audioUrl;

  const LanguageSelectionScreen({
    super.key,
    required this.username,
    required this.gender,
    this.avatar,
    this.audioUrl,
  });

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> with TickerProviderStateMixin {
  final FirestoreRepository _firestore = FirestoreRepository();
  final PushReceiver _push = PushReceiver();

  final List<Map<String, String>> _languages = [
    {'id': 'en', 'name': 'English', 'native': 'English', 'flag': '🇬🇧'},
    {'id': 'hi', 'name': 'Hindi', 'native': 'हिंदी', 'flag': '🇮🇳'},
    {'id': 'te', 'name': 'Telugu', 'native': 'తెలుగు', 'flag': '🇮🇳'},
    {'id': 'ta', 'name': 'Tamil', 'native': 'தமிழ்', 'flag': '🇮🇳'},
    {'id': 'mr', 'name': 'Marathi', 'native': 'मराठी', 'flag': '🇮🇳'},
    {'id': 'bn', 'name': 'Bengali', 'native': 'বাংলা', 'flag': '🇮🇳'},
  ];

  String? _selectedId = 'en';
  bool _isFinalizing = false;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleFinalize() async {
    if (_selectedId == null || _isFinalizing) return;

    setState(() => _isFinalizing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final phone = user?.phoneNumber ?? '';
      final coins = (phone.endsWith('9682524924') || phone.endsWith('9682524923')) ? 1000 : 0;

      final langName = _languages.firstWhere((l) => l['id'] == _selectedId)['name']!;

      await _firestore.registerUser(
        username: widget.username,
        gender: widget.gender,
        language: langName,
        avatarUrl: widget.avatar,
        audioUrl: widget.audioUrl,
        coins: coins,
        email: user?.email,
      );

      final profile = {
        'uid': user?.uid ?? '',
        'username': widget.username,
        'gender': widget.gender,
        'language': langName,
        'coins': coins,
        'email': user?.email ?? '',
        'phoneNumber': phone,
        'avatarUrl': widget.avatar,
      };

      await DataBridge().cacheUserData(profile);
      await DataBridge().updateLocalCoins(coins);

      final token = await _push.readToken();
      if (token != null) await _firestore.savePushToken(token);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ChilliHomeScreen()),
          (r) => false,
        );
      }
    } catch (e) {
      setState(() => _isFinalizing = false);
      _showError('Failed to create account: $e');
    }
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _buildTopGlow(size),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 48),
                      _buildSectionLabel('Preferred Language'),
                      const SizedBox(height: 20),
                      Expanded(child: _buildLanguageList()),
                      const SizedBox(height: 32),
                      _buildActionButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopGlow(Size size) {
    return Positioned(
      top: -100,
      left: -50,
      child: Container(
        width: size.width * 0.8,
        height: size.width * 0.8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [_neonCyan.withOpacity(0.12), Colors.transparent]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _neonViolet.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: _neonViolet.withOpacity(0.2), blurRadius: 20)],
          ),
          child: const Icon(Icons.translate_rounded, color: _neonViolet, size: 28),
        ),
        const SizedBox(height: 24),
        const Text(
          'Almost There,\nPick a Tongue',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Tailor your experience by choosing the language you speak best.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.0),
    );
  }

  Widget _buildLanguageList() {
    return ListView.builder(
      itemCount: _languages.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final lang = _languages[index];
        final isSelected = _selectedId == lang['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedId = lang['id']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isSelected ? _neonViolet.withOpacity(0.1) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _neonViolet.withOpacity(0.8) : Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang['native']!,
                        style: TextStyle(color: isSelected ? Colors.white : Colors.white.withOpacity(0.7), fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        lang['name']!,
                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: _neonCyan, size: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: _handleFinalize,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_neonPink, _neonViolet]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _neonPink.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 8))],
        ),
        child: Center(
          child: _isFinalizing
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'FINISH SETUP',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.done_all_rounded, color: Colors.white, size: 22),
                  ],
                ),
        ),
      ),
    );
  }
}
