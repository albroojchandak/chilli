import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chilli/core_services/authentication_service.dart';
import 'package:chilli/localization/locale_manager.dart';
import 'package:chilli/core_services/http_service.dart';
import 'package:chilli/core_services/fb_analytics_service.dart';
import 'package:chilli/core_services/analytics_tracking_service.dart';
import 'user_details_page.dart';
import '../legal_pages/privacy_page.dart';
import '../legal_pages/terms_page.dart';
import 'package:flutter/gestures.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  bool isLoading = false;
  bool isAgreed = true;
  final AuthenticationService _AuthenticationService = AuthenticationService();

  final FbAnalyticsService _facebookTracking = FbAnalyticsService();
  final AnalyticsTrackingService _analyticsService = AnalyticsTrackingService();
  Locale _currentLocale = const Locale('en', '');
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Scale animation
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Slide animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Pulse animation for logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    final double screenWidth = size.width;
    final bool isSmallDevice = screenHeight < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Even darker GenZ background
      body: Stack(
        children: [
          // 1. Massive Ambient Background Glows
          Positioned(
            top: -150,
            left: -100,
            child: _buildGlowingOrb(
              450,
              const Color(0xFF8B5CF6).withOpacity(0.12),
            ), // Massive Purple
          ),
          Positioned(
            bottom: -200,
            right: -100,
            child: _buildGlowingOrb(
              500,
              const Color(0xFF06B6D4).withOpacity(0.12),
            ), // Massive Cyan
          ),

          // 2. Animated Floating Elements
          Positioned(
            top: 200,
            right: 40,
            child: _buildFloatingElement(
              50,
              const Color(0xFF06B6D4).withOpacity(0.2),
              20,
            ),
          ),
          Positioned(
            bottom: 250,
            left: 50,
            child: _buildFloatingElement(
              80,
              const Color(0xFF8B5CF6).withOpacity(0.2),
              30,
            ),
          ),

          // 3. Foreground Content - CENTERED LAYOUT
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // The Single Centered Glass Card
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 400),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 40,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1E293B,
                              ).withOpacity(0.6), // Dark Glass
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 40,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF06B6D4,
                                  ).withOpacity(0.05),
                                  blurRadius: 30,
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo
                                ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      double logoSize = isSmallDevice
                                          ? 80
                                          : 100;

                                      return Transform.scale(
                                        scale: _pulseAnimation.value,
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            color: const Color(0xFF14141E),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF06B6D4,
                                              ).withOpacity(0.6),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF06B6D4,
                                                ).withOpacity(0.4),
                                                blurRadius: 20,
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              22,
                                            ),
                                            child: Image.network(
                                              'https://play-lh.googleusercontent.com/cdzMWiJebn2kjeCrUt7bI47-QQF-ttZGQZY6g0CVMcREiztlyFKRLSYY-tdCehS7Cfq5Z9_lzNl6x7S4Kr6ET5c=w240-h480-rw',
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.video_call_rounded,
                                                      size: logoSize * 0.5,
                                                      color: Colors.white,
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // App Name
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFF8B5CF6), // Purple
                                          Color(0xFF06B6D4), // Cyan
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                  child: Text(
                                    'chilli',
                                    style: TextStyle(
                                      fontSize: isSmallDevice ? 40 : 48,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Tagline
                                Text(
                                  'Meet. Match. Vibe.',
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 12 : 14,
                                    color: Colors.white.withOpacity(0.6),
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 48),

                                // Welcome Text
                                Text(
                                  LocaleManager(
                                    Locale(_currentLocale.languageCode),
                                  ).welcomeBack,
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 24 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Dive in and find your people',
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 14 : 15,
                                    color: Colors.white.withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Google Sign In Button
                                Container(
                                  width: double.infinity,
                                  height: isSmallDevice ? 56 : 60,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF06B6D4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF06B6D4,
                                        ).withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : _handleGoogleSignIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Image.network(
                                                  'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                                                  height: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Jump in with Google',
                                                style: TextStyle(
                                                  fontSize: isSmallDevice
                                                      ? 15
                                                      : 17,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Privacy & Terms Agreement
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Theme(
                                      data: ThemeData(
                                        unselectedWidgetColor: Colors.white
                                            .withOpacity(0.3),
                                      ),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Checkbox(
                                          value: isAgreed,
                                          activeColor: const Color(0xFF06B6D4),
                                          checkColor: const Color(0xFF14141E),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              isAgreed = value ?? false;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: isSmallDevice ? 11 : 12,
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontWeight: FontWeight.w500,
                                            height: 1.4,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: 'I agree to the ',
                                            ),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: const TextStyle(
                                                color: Color(0xFF06B6D4),
                                                fontWeight: FontWeight.bold,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          const PrivacyPage(),
                                                    ),
                                                  );
                                                },
                                            ),
                                            const TextSpan(text: ' and '),
                                            TextSpan(
                                              text: 'Terms of Service',
                                              style: const TextStyle(
                                                color: Color(0xFF06B6D4),
                                                fontWeight: FontWeight.bold,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          const Terms_Page(),
                                                    ),
                                                  );
                                                },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Language Selector (Top Right)
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.language_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 22,
                  ),
                  tooltip: 'Language',
                  offset: const Offset(0, 45),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  onSelected: (String languageCode) {
                    setState(() => _currentLocale = Locale(languageCode, ''));
                  },
                  itemBuilder: (BuildContext context) => const [
                    PopupMenuItem(
                      value: 'en',
                      child: Text(
                        'English',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'hi',
                      child: Text(
                        'हिंदी (Hindi)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ta',
                      child: Text(
                        'தமிழ் (Tamil)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _buildFloatingElement(double size, Color color, double blurRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: blurRadius,
            spreadRadius: blurRadius / 2,
          ),
        ],
      ),
    );
  }

  void _handleGoogleSignIn() async {
    if (!isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Privacy Policy and Terms of Service',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Step 1: Sign in with Google
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate(scopeHint: ['email']);

      final String email = googleUser.email;

      // Step 2: Get Google authentication credentials
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final GoogleSignInClientAuthorization? authz = await googleUser
          .authorizationClient
          .authorizationForScopes(['email']);

      // Step 3: Create Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase with Google credentials
      final UserCredential firebaseUserCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? firebaseUser = firebaseUserCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase authentication failed');
      }

      debugPrint('🔐 Firebase User authenticated: ${firebaseUser.uid}');
      debugPrint('📧 Email from Google: $email');

      // 🎁 Award 1000 coins for specific email
      if (email.toLowerCase() == 'inflyratechnew@gmail.com') {
        await HttpService().updateLocalCoins(1000, isDeduction: false);
        debugPrint('✅ Awarded 1000 bonus coins to $email');
      }

      // Step 5: Check if user profile exists in Firestore
      final userData = await _AuthenticationService.getUserData();

      if (mounted) {
        if (userData != null &&
            userData.containsKey('username') &&
            userData['username'] != null) {
          // ✅ Existing user - Update email in Firestore and local cache
          debugPrint('👤 Existing user detected. Updating email...');

          try {
            // Update Firestore using set with merge to handle missing fields
            await FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .set({
                  'email': email,
                  'Email': email,
                  'uid': firebaseUser.uid,
                }, SetOptions(merge: true));

            debugPrint('✅ Email saved to Firestore: $email');

            // Update local cache
            await _AuthenticationService.updateLocalData({
              'email': email,
              'Email': email,
            });

            debugPrint('✅ Email saved to local cache: $email');
          } catch (e) {
            debugPrint('❌ Error saving email: $e');
            // Don't block navigation even if save fails
          }

          // 📊 Track Login Event to Facebook
          await _facebookTracking.trackLogin(
            method: 'google',
            userId: firebaseUser.uid,
          );

          // 📊 Track Login Event to Firebase Analytics (for Google Ads)
          await _analyticsService.trackLogin(
            method: 'google',
            userId: firebaseUser.uid,
          );

          // Set user properties for audience targeting
          if (userData['gender'] != null) {
            await _analyticsService.setUserProperty(
              name: 'gender',
              value: userData['gender'],
            );
          }
          if (userData['language'] != null) {
            await _analyticsService.setUserProperty(
              name: 'language',
              value: userData['language'],
            );
          }

          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else {
          // New user - Navigate to profile setup
          debugPrint('✨ New user detected. Navigating to profile setup...');

          // 📊 Track Signup Event to Facebook
          await _facebookTracking.trackSignup(
            method: 'google',
            userId: firebaseUser.uid,
          );

          // 📊 Track Signup Event to Firebase Analytics (for Google Ads)
          await _analyticsService.trackSignup(
            method: 'google',
            userId: firebaseUser.uid,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserDetailsPage()),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
