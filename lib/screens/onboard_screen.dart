import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:chilli/screens/lang_screen.dart';
import 'package:chilli/utils/avatar_store.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  String? _selectedGender;
  String? _selectedAvatarUrl;

  late final AnimationController _formAnimController;
  late final AnimationController _meshAnimController;

  static const Color _bgDark = Color(0xFF090412);
  static const Color _primaryNeon = Color(0xFF00E5FF);
  static const Color _secondaryNeon = Color(0xFFFF007F);
  static const Color _accentViolet = Color(0xFF7000FF);

  final List<String> _femaleAvatars = AvatarVault.femaleAvatars;
  final List<String> _maleAvatars = AvatarVault.maleAvatars;

  @override
  void initState() {
    super.initState();
    _formAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _meshAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();

    _formAnimController.forward();
    _usernameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocus.dispose();
    _formAnimController.dispose();
    _meshAnimController.dispose();
    super.dispose();
  }

  String? _validateUsername(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return 'Username is required';
    if (text.length < 3) return 'Too short (min 3 chars)';
    if (RegExp(r'^[0-9]+$').hasMatch(text)) return 'Cannot be only numbers';
    if (RegExp(r'\d{10}').hasMatch(text)) return 'No phone numbers allowed';
    
    final restricted = ['whatsapp', 'insta', 'telegram', 'snap', 'facebook', 'porn'];
    for (final word in restricted) {
      if (text.contains(word)) return 'Inappropriate content';
    }
    return null;
  }

  void _handleContinue() {
    final error = _validateUsername(_usernameController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageSelectionScreen(
          username: _usernameController.text,
          gender: _selectedGender!,
          avatar: _selectedAvatarUrl!,
          audioUrl: null,
        ),
      ),
    );
  }

  Widget _buildFadeSlide(int delayIndex, Widget child) {
    final start = (delayIndex * 0.15).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
    
    final animation = CurvedAnimation(
      parent: _formAnimController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _meshAnimController,
            builder: (context, _) {
              return CustomPaint(
                painter: _MeshGradientPainter(_meshAnimController.value),
                size: Size.infinite,
              );
            },
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _buildFadeSlide(0, _buildHeader()),
                            const SizedBox(height: 48),
                            _buildFadeSlide(1, _buildInputSection()),
                            const SizedBox(height: 40),
                            _buildFadeSlide(2, _buildGenderSection()),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 40),
                            _buildFadeSlide(3, _buildSubmitButton()),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: _primaryNeon.withOpacity(0.1), blurRadius: 20)
            ],
          ),
          child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 28),
        const Text(
          'Configure\nIdentity',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1.2,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Establish your presence in the network.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    final isFocused = _usernameFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'USERNAME',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          decoration: BoxDecoration(
            color: isFocused ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFocused ? _primaryNeon.withOpacity(0.6) : Colors.white.withOpacity(0.06),
              width: 1.5,
            ),
            boxShadow: isFocused ? [BoxShadow(color: _primaryNeon.withOpacity(0.12), blurRadius: 24, spreadRadius: -5)] : [],
          ),
          child: TextFormField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            decoration: InputDecoration(
              hintText: 'e.g. Maverick',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Icon(Icons.alternate_email_rounded, color: isFocused ? _primaryNeon : Colors.white.withOpacity(0.3), size: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'IDENTIFY AS',
            style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildGenderCard('Male', Icons.face_6_rounded, _primaryNeon)),
            const SizedBox(width: 20),
            Expanded(child: _buildGenderCard('Female', Icons.face_3_rounded, _secondaryNeon)),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderCard(String gender, IconData icon, Color color) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
          final avatars = gender == 'Male' ? _maleAvatars : _femaleAvatars;
          _selectedAvatarUrl = avatars[math.Random().nextInt(avatars.length)];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.04),
            width: 1.5,
          ),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(isSelected ? 18 : 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.03),
              ),
              child: Icon(icon, size: 36, color: isSelected ? color : Colors.white.withOpacity(0.3)),
            ),
            const SizedBox(height: 18),
            Text(
              gender.toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool isValid = _selectedGender != null && _usernameController.text.trim().length >= 3;
    return GestureDetector(
      onTap: isValid ? _handleContinue : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isValid
              ? const LinearGradient(
                  colors: [_primaryNeon, _accentViolet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
                ),
          boxShadow: isValid
              ? [
                  BoxShadow(color: _primaryNeon.withOpacity(0.35), blurRadius: 25, offset: const Offset(-5, 8)),
                  BoxShadow(color: _accentViolet.withOpacity(0.35), blurRadius: 25, offset: const Offset(5, 8)),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            isValid ? 'INITIALIZE' : 'MISSING DATA',
            style: TextStyle(
              color: isValid ? Colors.white : Colors.white.withOpacity(0.25),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final double progress;

  _MeshGradientPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final ox1 = cx + math.cos(progress * math.pi * 2) * 140;
    final oy1 = cy + math.sin(progress * math.pi * 2) * 180;

    final ox2 = cx + math.cos((progress + 0.33) * math.pi * 2) * -160;
    final oy2 = cy + math.sin((progress + 0.33) * math.pi * 2) * 120;

    final ox3 = cx + math.cos((progress + 0.66) * math.pi * 2) * 100;
    final oy3 = cy + math.sin((progress + 0.66) * math.pi * 2) * -160;

    void drawGlow(Offset center, Color color, double radius) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
        
      canvas.drawCircle(center, radius, paint);
    }

    drawGlow(Offset(ox1, oy1), const Color(0xFF00E5FF), 280);
    drawGlow(Offset(ox2, oy2), const Color(0xFFFF007F), 300);
    drawGlow(Offset(ox3, oy3), const Color(0xFF7000FF), 320);
  }

  @override
  bool shouldRepaint(_MeshGradientPainter old) => true;
}
