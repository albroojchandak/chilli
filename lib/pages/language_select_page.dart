import 'package:flutter/material.dart';
import 'package:chilli/core_services/cloud_database_service.dart';
import 'package:chilli/core_services/push_notification_service.dart';
import 'package:chilli/core_services/http_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_page.dart';

class LanguageSelectPage extends StatefulWidget {
  final String username;
  final String gender;
  final String? avatar;
  final String? audioUrl;

  const LanguageSelectPage({
    super.key,
    required this.username,
    required this.gender,
    this.avatar,
    this.audioUrl,
  });

  @override
  State<LanguageSelectPage> createState() => _LanguageSelectPageState();
}

class _LanguageSelectPageState extends State<LanguageSelectPage>
    with SingleTickerProviderStateMixin {
  final CloudDatabaseService _CloudDatabaseService = CloudDatabaseService();
  final PushNotificationService _PushNotificationService =
      PushNotificationService();

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6B4CE6),
              const Color(0xFF4834DF),
              const Color(0xFF2E1F8A),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern header
              _buildHeader(),

              // Language grid
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      _buildSelectionIndicator(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildLanguageGrid(),
                        ),
                      ),
                      _buildContinueButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Final Step',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Choose Your\nLanguage',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the language you\'re most comfortable with',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w400,
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
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B4CE6).withOpacity(0.1),
            const Color(0xFF4834DF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B4CE6).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B4CE6), Color(0xFF4834DF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selectedLanguage == null
                  ? 'Tap on a language to select'
                  : 'Selected: $selectedLanguage',
              style: TextStyle(
                color: const Color(0xFF6B4CE6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selectedLanguage != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10D078),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
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
        childAspectRatio: 1.5,
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
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF6B4CE6), Color(0xFF4834DF)],
                    )
                  : null,
              color: isSelected ? null : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade200,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6B4CE6).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(language['icon'], style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(
                        language['native'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language['name'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey.shade500,
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
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
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

  Widget _buildContinueButton() {
    final isEnabled = selectedLanguage != null && !isCreatingAccount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFF6B4CE6), Color(0xFF4834DF)],
              )
            : null,
        color: isEnabled ? null : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF6B4CE6).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
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

                    // ✅ Save user_data and coins using HttpService
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
                    await HttpService().cacheUserData(userData);
                    await HttpService().updateLocalCoins(startingCoins);
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
                          builder: (context) => const MainPage(),
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
                          backgroundColor: Colors.red.shade600,
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
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: isEnabled ? Colors.white : Colors.grey.shade600,
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
