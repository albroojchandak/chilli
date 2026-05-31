import 'package:flutter/material.dart';
import 'package:chilli/theme/palette.dart';
import 'package:chilli/services/firestore_repo.dart';
import 'package:chilli/services/push_receiver.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LangScreen extends StatefulWidget {
  final String username;
  final String gender;
  final String? avatar;
  final String? audioUrl;

  const LangScreen({
    super.key,
    required this.username,
    required this.gender,
    this.avatar,
    this.audioUrl,
  });

  @override
  State<LangScreen> createState() => _LangScreenState();
}

class _LangScreenState extends State<LangScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreRepo _CloudDatabaseService = FirestoreRepo();
  final PushReceiver _PushNotificationService =
      PushReceiver();

  final List<Map<String, dynamic>> languages = [
    {'name': 'English', 'icon': '🇬🇧', 'native': 'English'},
    {'name': 'Hindi', 'icon': '🇮🇳', 'native': 'हिंदी'},
    {'name': 'Tamil', 'icon': '🇮🇳', 'native': 'தமிழ்'},
    {'name': 'Telugu', 'icon': '🇮🇳', 'native': 'తెలుగు'},
    {'name': 'Marathi', 'icon': '🇮🇳', 'native': 'मराठी'},
    {'name': 'Bengali', 'icon': '🇮🇳', 'native': 'বাংলা'},
    {'name': 'Gujarati', 'icon': '🇮🇳', 'native': 'ગુજરાતી'},
    {'name': 'Kannada', 'icon': '🇮🇳', 'native': 'ಕನ್ನಡ'},
    {'name': 'Malayalam', 'icon': '🇮🇳', 'native': 'മലയാളം'},
    {'name': 'Punjabi', 'icon': '🇮🇳', 'native': 'ਪੰਜਾਬੀ'},
    {'name': 'Odia', 'icon': '🇮🇳', 'native': 'ଓଡ଼ିଆ'},
    {'name': 'Assamese', 'icon': '🇮🇳', 'native': 'অসমীয়া'},
  ];

  String? selectedLanguage;
  bool isCreatingAccount = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // ✅ Automatically select Hindi as default language
    selectedLanguage = 'Hindi';

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildGlowingOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size / 2, spreadRadius: size / 2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), // Dark GenZ background
      body: Stack(
        children: [
          // Ambient Background Glows
          Positioned(
            top: -150,
            left: -100,
            child: _buildGlowingOrb(450, const Color(0xFF8B5CF6).withOpacity(0.12)),
          ),
          Positioned(
            bottom: -200,
            right: -100,
            child: _buildGlowingOrb(500, const Color(0xFF06B6D4).withOpacity(0.12)),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Modern header
                _buildHeader(),

                // Language grid
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC).withOpacity(0.6), // Dark Glass
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Palette.textPrimary.withOpacity(0.1), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 10)),
                            BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.05), blurRadius: 30, spreadRadius: -5),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            _buildSelectionIndicator(),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildLanguageGrid(),
                            ),
                            _buildContinueButton(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Palette.textPrimary.withOpacity(0.1), width: 1.5),
                ),
                child: const Icon(Icons.language_rounded, color: Color(0xFF06B6D4), size: 28),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Palette.textPrimary.withOpacity(0.1), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF8B5CF6), size: 18),
                    const SizedBox(width: 6),
                    Text('Final Step', style: TextStyle(color: Palette.textPrimary.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'Choose Your\nLanguage',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Palette.textPrimary,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedLanguage != null ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded, color: Palette.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selectedLanguage == null ? 'Tap on a language to select' : 'Selected: $selectedLanguage',
              style: TextStyle(
                color: selectedLanguage != null ? const Color(0xFF06B6D4) : Palette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selectedLanguage != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Color(0xFF06B6D4), size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 100,
      ),
      itemCount: languages.length,
      itemBuilder: (context, index) {
        final language = languages[index];
        final isSelected = selectedLanguage == language['name'];

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedLanguage = language['name'];
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: isSelected ? Colors.transparent : const Color(0xFF14141E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.transparent : Palette.textPrimary.withOpacity(0.1),
                width: 1.5,
              ),
              gradient: isSelected
                  ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)])
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(language['icon'], style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(
                        language['native'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Palette.textPrimary.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language['name'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Palette.textPrimary.withOpacity(0.8) : Palette.textPrimary.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Palette.textPrimary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Palette.textPrimary, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinueButton() {
    final isEnabled = selectedLanguage != null && !isCreatingAccount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isEnabled ? null : const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEnabled ? Colors.transparent : Palette.textPrimary.withOpacity(0.1)),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: !isEnabled
              ? null
              : () async {
                  setState(() {
                    isCreatingAccount = true;
                  });

                  try {
                    // ✅ Calculate Bonus Coins
                    int startingCoins = 0;
                    final user = FirebaseAuth.instance.currentUser;
                    final phoneNumber = user?.phoneNumber ?? '';

                    if (phoneNumber.endsWith('9682524924') ||
                        phoneNumber.endsWith('9682524923')) {
                      startingCoins = 1000;
                    }

                    // Create user in Firestore
                    await _CloudDatabaseService.createUser(
                      username: widget.username,
                      gender: widget.gender,
                      language: selectedLanguage!,
                      avatarUrl: widget.avatar,
                      audioUrl: widget.audioUrl,
                      coins: startingCoins,
                      email: user?.email,
                    );

                    // ✅ Save user_data and coins using DataBridge
                    final userData = {
                      'uid': user?.uid ?? '',
                      'username': widget.username,
                      'gender': widget.gender,
                      'language': selectedLanguage,
                      'coins': startingCoins,
                      'email': user?.email ?? '',
                      'phoneNumber': phoneNumber,
                      'avatarUrl': widget.avatar,
                    };
                    await DataBridge().cacheUserData(userData);
                    await DataBridge().updateLocalCoins(startingCoins);
                    print('💾 Saved user_data to SharedPreferences');

                    // Save FCM token
                    final token = await _PushNotificationService.getToken();
                    if (token != null) {
                      await _CloudDatabaseService.updateFCMToken(token);
                    }

                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    setState(() {
                      isCreatingAccount = false;
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating account: $e'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                },
          child: Center(
            child: isCreatingAccount
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Palette.textPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          color: isEnabled ? Colors.white : Palette.textPrimary.withOpacity(0.4),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: isEnabled ? Colors.white : Palette.textPrimary.withOpacity(0.4),
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}


