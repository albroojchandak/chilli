import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    {'id': 'hi', 'name': 'Hindi', 'native': 'हिंदी', 'flag': '🇮🇳'},
    {'id': 'en', 'name': 'English', 'native': 'English', 'flag': '🇬🇧'},
    {'id': 'te', 'name': 'Telugu', 'native': 'తెలుగు', 'flag': '🇮🇳'},
    {'id': 'ta', 'name': 'Tamil', 'native': 'தமிழ்', 'flag': '🇮🇳'},
    {'id': 'mr', 'name': 'Marathi', 'native': 'मరాఠీ', 'flag': '🇮🇳'},
    {'id': 'bn', 'name': 'Bengali', 'native': 'বাংলা', 'flag': '🇮🇳'},
  ];

  // Make Hindi ('hi') default selected
  String? _selectedId = 'hi';
  bool _isFinalizing = false;

  late final AnimationController _entranceController;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleFinalize() async {
    if (_selectedId == null || _isFinalizing) return;
    HapticFeedback.heavyImpact();
    setState(() => _isFinalizing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final phone = user?.phoneNumber ?? '';
      final coins = (phone.endsWith('1234567890') || phone.endsWith('1234567890')) ? 1000 : 0;

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
      if (mounted) setState(() => _isFinalizing = false);
      _showError('Failed to create account: $e');
    }
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _neonPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accentColor = widget.gender.toLowerCase() == 'female' ? _neonPink : _neonCyan;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Elegant animated/particle-like custom background
          CustomPaint(
            size: size,
            painter: _ParticleFieldPainter(),
          ),
          _buildBackgroundGlows(size),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  _buildHeader(accentColor),
                  const SizedBox(height: 32),
                  Expanded(
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
                      ),
                      child: _buildLanguagesGrid(accentColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildContinueButton(accentColor),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows(Size size) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -size.height * 0.2,
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neonPink.withOpacity(0.08),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_neonPink.withOpacity(0.12), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.2,
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neonCyan.withOpacity(0.08),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_neonCyan.withOpacity(0.12), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 24,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PREFERENCE',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose Language',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your preferred language to connect and talk with others.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagesGrid(Color accentColor) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.35,
      ),
      itemCount: _languages.length,
      itemBuilder: (context, index) {
        final lang = _languages[index];
        final isSelected = _selectedId == lang['id'];

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedId = lang['id'];
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [accentColor.withOpacity(0.08), accentColor.withOpacity(0.02)]
                    : [Colors.white.withOpacity(0.03), Colors.white.withOpacity(0.01)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? accentColor.withOpacity(0.8) : Colors.white.withOpacity(0.08),
                width: isSelected ? 1.5 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Flag & Selection Radio Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Sleek flag pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? accentColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          lang['flag']!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      // Premium Radio Indicator
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? accentColor : Colors.white.withOpacity(0.2),
                            width: isSelected ? 5.5 : 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Native Language Name
                  Text(
                    lang['native']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // English Name
                  Text(
                    lang['name']!.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? accentColor.withOpacity(0.9) : Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinueButton(Color accentColor) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
      child: GestureDetector(
        onTap: _handleFinalize,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                accentColor,
                _neonViolet,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: _isFinalizing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'CONTINUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Custom Painters matching the visual design
// ----------------------------------------------------------------------------

class _ParticleFieldPainter extends CustomPainter {
  final List<_Particle> _particles = List.generate(40, (i) {
    final rng = math.Random(i * 17 + 5);
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: rng.nextDouble() * 2.0 + 0.5,
      opacity: rng.nextDouble() * 0.25 + 0.05,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Particle {
  final double x, y, size, opacity;
  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
  });
}
