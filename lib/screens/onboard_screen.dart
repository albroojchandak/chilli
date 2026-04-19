import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:chilli/screens/lang_screen.dart';

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

  late final AnimationController _entranceController;
  late final AnimationController _floatController;
  late final AnimationController _shimmerController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _floatAnimation;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);

  final List<String> _femaleAvatars = List.generate(22, (i) => 'https://via.placeholder.com/150?text=F$i');
  final List<String> _maleAvatars = List.generate(19, (i) => 'https://via.placeholder.com/150?text=M$i');

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _fadeAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0)
        .animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    _entranceController.forward();
    _usernameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocus.dispose();
    _entranceController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  String? _validateUsername(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return 'Username is required';
    if (text.length < 3) return 'Too short (min 3 chars)';
    if (RegExp(r'^[0-9]+$').hasMatch(text)) return 'Cannot be only numbers';
    if (RegExp(r'\d{10}').hasMatch(text)) return 'No phone numbers allowed';
    
    final restricted = ['whatsapp', 'insta', 'telegram', 'snap', 'facebook', 'porn', 'xxx', 'fuck'];
    for (final word in restricted) {
      if (text.contains(word)) return 'Inappropriate or restricted content';
    }
    return null;
  }

  void _handleGenderSelection(String gender) {
    setState(() {
      _selectedGender = gender;
      final avatars = gender == 'Male' ? _maleAvatars : _femaleAvatars;
      _selectedAvatarUrl = avatars[math.Random().nextInt(avatars.length)];
    });
  }

  void _handleContinue() {
    final error = _validateUsername(_usernameController.text);
    if (error != null) {
      _showError(error);
      return;
    }
    if (_selectedGender == null) {
      _showError('Please select your gender');
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
          _buildBackgroundGlow(size),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 48),
                      _buildSectionLabel('Identify As'),
                      const SizedBox(height: 16),
                      _buildGenderPicker(),
                      const SizedBox(height: 48),
                      _buildSectionLabel('Unique Username'),
                      const SizedBox(height: 16),
                      _buildUsernameCard(),
                      const SizedBox(height: 64),
                      _buildPremiumButton(),
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

  Widget _buildBackgroundGlow(Size size) {
    return Positioned(
      top: -150,
      right: -100,
      child: Container(
        width: size.width * 1.2,
        height: size.width * 1.2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [_neonViolet.withOpacity(0.12), Colors.transparent],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, _) => Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_neonCyan.withOpacity(0.2), Colors.transparent]),
                border: Border.all(color: _neonCyan.withOpacity(0.4), width: 1.5),
                boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.15), blurRadius: 25)],
              ),
              child: const Icon(Icons.stars_rounded, color: _neonCyan, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Complete Your\nProfile',
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1.8),
        ),
        const SizedBox(height: 14),
        Text(
          'Stand out from the crowd with a unique identity.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2.5),
    );
  }

  Widget _buildGenderPicker() {
    return Row(
      children: [
        Expanded(child: _buildGenderCard('Male', Icons.face_6_rounded, _neonCyan)),
        const SizedBox(width: 16),
        Expanded(child: _buildGenderCard('Female', Icons.face_3_rounded, _neonPink)),
      ],
    );
  }

  Widget _buildGenderCard(String gender, IconData icon, Color color) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => _handleGenderSelection(gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? color.withOpacity(0.8) : Colors.white.withOpacity(0.08), width: 2),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, spreadRadius: -5)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, size: 34, color: isSelected ? color : Colors.white.withOpacity(0.2)),
            const SizedBox(height: 10),
            Text(
              gender,
              style: TextStyle(color: isSelected ? Colors.white : Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameCard() {
    final isFocused = _usernameFocus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isFocused ? _neonViolet.withOpacity(0.8) : Colors.white.withOpacity(0.1), width: 2),
        boxShadow: isFocused ? [BoxShadow(color: _neonViolet.withOpacity(0.12), blurRadius: 20)] : [],
      ),
      child: TextField(
        controller: _usernameController,
        focusNode: _usernameFocus,
        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        onChanged: (v) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Choose a spicy tag...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.badge_rounded, color: isFocused ? _neonViolet : Colors.white.withOpacity(0.2)),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildPremiumButton() {
    final bool isValid = _selectedGender != null && _usernameController.text.trim().length >= 3;
    return GestureDetector(
      onTap: isValid ? _handleContinue : null,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, _) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isValid ? 1.0 : 0.3,
            child: Container(
              width: double.infinity,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(_neonViolet, _neonPink, _shimmerController.value)!,
                    Color.lerp(_neonPink, _neonViolet, _shimmerController.value)!,
                  ],
                ),
                boxShadow: isValid ? [BoxShadow(color: _neonViolet.withOpacity(0.35), blurRadius: 25, offset: const Offset(0, 10))] : [],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "LET'S GET STARTED",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
