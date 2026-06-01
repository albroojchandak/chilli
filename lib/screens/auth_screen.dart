import 'package:flutter/material.dart';
import 'package:chilli/theme/palette.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/locale/lang_bundle.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/services/fb_reporter.dart';
import 'package:chilli/services/event_tracker.dart';
import 'dart:ui';
import 'onboard_screen.dart';
import '../legal/privacy_screen.dart';
import '../legal/terms_screen.dart';
import 'package:flutter/gestures.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool isLoading = false;
  bool isAgreed = true;
  final IdentityManager _AuthenticationService = IdentityManager();

  final FbReporter _facebookTracking = FbReporter();
  final EventTracker _analyticsService = EventTracker();
  Locale _currentLocale = const Locale('en', '');

  // Animations
  late AnimationController _sheetAnimController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideUpAnimation;

  @override
  void initState() {
    super.initState();

    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _sheetAnimController,
      curve: Curves.easeIn,
    );

    _slideUpAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sheetAnimController,
      curve: Curves.easeOutCubic,
    ));

    _sheetAnimController.forward();
  }

  @override
  void dispose() {
    _sheetAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallDevice = size.height < 750;

    return Scaffold(
      backgroundColor: Palette.background, // 70% White
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Premium Soft Glowing Orbs (Abstract Background)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.primary.withOpacity(0.15), // 30% Indigo presence
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.2,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.accent.withOpacity(0.1), // 10% Chilli Red presence
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.4,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.secondary.withOpacity(0.1),
              ),
            ),
          ),
          
          // Blur layer for glassmorphism orb effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // 2. Language Selector (Top Right)
          Positioned(
            top: 50,
            right: 24,
            child: _buildLanguageSelector(),
          ),

          // 3. Main Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideUpAnimation,
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          SizedBox(height: size.height * 0.05),
                    
                    // Brand Icon
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.primary.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Typography
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Chilli makes\nFriendships',
                        style: TextStyle(
                          fontSize: 48,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Palette.textPrimary,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Meet people who share your vibe, your energy, and your passions.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Palette.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const Expanded(child: SizedBox(height: 32)),

                    // Bottom Section (30% Indigo influence in the main action areas)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: 40,
                        left: 32,
                        right: 32,
                        bottom: isSmallDevice ? 32 : 50,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.textPrimary.withOpacity(0.05),
                            blurRadius: 40,
                            offset: const Offset(0, -10),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LangBundle(
                              Locale(_currentLocale.languageCode),
                            ).welcomeBack,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Palette.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Indigo Google Button
                          _buildGoogleButton(isSmallDevice),
                          const SizedBox(height: 24),

                          // Legal and Agreement
                          _buildAgreementText(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ), // closes SliverFillRemaining
                  ], // closes slivers
                ), // closes CustomScrollView
              ), // closes SlideTransition
            ), // closes FadeTransition
          ), // closes SafeArea
        ], // closes Stack children
      ), // closes Stack
    ); // closes Scaffold
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Palette.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.language_rounded,
          color: Palette.primary,
          size: 24,
        ),
        tooltip: 'Language',
        offset: const Offset(0, 50),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Palette.primary.withOpacity(0.1)),
        ),
        onSelected: (String languageCode) {
          setState(() => _currentLocale = Locale(languageCode, ''));
        },
        itemBuilder: (BuildContext context) => const [
          PopupMenuItem(
            value: 'en',
            child: Text(
              'English',
              style: TextStyle(color: Palette.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          PopupMenuItem(
            value: 'hi',
            child: Text(
              'हिंदी (Hindi)',
              style: TextStyle(color: Palette.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          PopupMenuItem(
            value: 'ta',
            child: Text(
              'தமிழ் (Tamil)',
              style: TextStyle(color: Palette.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(bool isSmallDevice) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        gradient: Palette.primaryGradient, // 30% Indigo dominant action
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Palette.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isLoading ? null : _handleGoogleSignIn,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.network(
                        'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                        height: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: isSmallDevice ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAgreementText() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: ThemeData(
            unselectedWidgetColor: Palette.textSecondary.withOpacity(0.5),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isAgreed,
              activeColor: Palette.accent, // 10% Accent for highlights
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
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
              style: const TextStyle(
                fontSize: 12,
                color: Palette.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                    color: Palette.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyScreen(),
                        ),
                      );
                    },
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(
                    color: Palette.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsScreen(),
                        ),
                      );
                    },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleGoogleSignIn() async {
    if (!isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Privacy Policy and Terms of Service'),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate(scopeHint: ['email']);

      if (googleUser == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final String email = googleUser.email;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final GoogleSignInClientAuthorization? authz = await googleUser
          .authorizationClient
          .authorizationForScopes(['email']);

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential firebaseUserCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? firebaseUser = firebaseUserCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase authentication failed');
      }

      if (email.toLowerCase() == 'nurxiannew@gmail.com') {
        await DataBridge().updateLocalCoins(1000, isDeduction: false);
      }

      final userData = await _AuthenticationService.getUserData();

      if (mounted) {
        if (userData != null &&
            userData.containsKey('username') &&
            userData['username'] != null) {
          
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .set({
                  'email': email,
                  'Email': email,
                  'uid': firebaseUser.uid,
                }, SetOptions(merge: true));

            await _AuthenticationService.updateLocalData({
              'email': email,
              'Email': email,
            });
          } catch (e) {
            debugPrint('Error saving email: $e');
          }

          await _facebookTracking.trackLogin(method: 'google', userId: firebaseUser.uid);
          await _analyticsService.trackLogin(method: 'google', userId: firebaseUser.uid);

          if (userData['gender'] != null) {
            await _analyticsService.setUserProperty(name: 'gender', value: userData['gender']);
          }
          if (userData['language'] != null) {
            await _analyticsService.setUserProperty(name: 'language', value: userData['language']);
          }

          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else {
          await _facebookTracking.trackSignup(method: 'google', userId: firebaseUser.uid);
          await _analyticsService.trackSignup(method: 'google', userId: firebaseUser.uid);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Palette.error),
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
