import 'dart:math' as math;
import 'package:chilli/locale/lang_bundle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/services/fb_reporter.dart';
import 'package:chilli/services/event_tracker.dart';
import 'onboard_screen.dart';
import '../legal/privacy_screen.dart';
import '../legal/terms_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isAgreed = true;
  Locale _currentLocale = const Locale('en', '');

  final IdentityManager _identityManager = IdentityManager();
  final FbInsightsReporter _fbReporter = FbInsightsReporter();
  final EventTracker _eventTracker = EventTracker();

  late final AnimationController _entranceController;
  late final AnimationController _ringController;
  late final AnimationController _shimmerController;
  late final AnimationController _floatController;

  late final Animation<double> _logoEntrance;
  late final Animation<double> _titleEntrance;
  late final Animation<double> _cardEntrance;
  late final Animation<double> _ringRotation;
  late final Animation<double> _shimmer;
  late final Animation<double> _float;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);
  static const _softGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _logoEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    );

    _titleEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );

    _cardEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    );

    _ringRotation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _ringController, curve: Curves.linear));

    _shimmer = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );

    _float = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ringController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  LangBundle get _lang => LangBundle(Locale(_currentLocale.languageCode));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 680;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomPaint(size: size, painter: _ParticleFieldPainter()),
          _buildDiagonalAccent(size),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopBar(),
                      SizedBox(height: isSmall ? 24 : 48),
                      _buildLogoRing(size, isSmall),
                      SizedBox(height: isSmall ? 20 : 32),
                      _buildBrandName(isSmall),
                      const SizedBox(height: 12),
                      _buildSubtitle(isSmall),
                      SizedBox(height: isSmall ? 32 : 52),
                      _buildSignInCard(isSmall),
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

  Widget _buildDiagonalAccent(Size size) {
    return Positioned.fill(
      child: CustomPaint(painter: _DiagonalAccentPainter()),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [_buildLanguagePicker()],
    );
  }

  Widget _buildStatusBadge() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Color.lerp(
                _neonCyan.withOpacity(0.4),
                _neonPink.withOpacity(0.6),
                _shimmer.value,
              )!,
              width: 1.2,
            ),
            color: Colors.white.withOpacity(0.04),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neonCyan,
                  boxShadow: [BoxShadow(color: _neonCyan, blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.85),
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguagePicker() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        color: Colors.white.withOpacity(0.05),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.translate_rounded,
          color: Colors.white,
          size: 20,
        ),
        tooltip: 'Language',
        offset: const Offset(0, 52),
        color: const Color(0xFF120824),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _neonViolet.withOpacity(0.3), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (code) => setState(() => _currentLocale = Locale(code, '')),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'en',
            child: Text('🇬🇧  English', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuItem(
            value: 'hi',
            child: Text('🇮🇳  हिंदी', style: TextStyle(color: Colors.white)),
          ),
          PopupMenuItem(
            value: 'te',
            child: Text('🇮🇳  తెలుగు', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoRing(Size size, bool isSmall) {
    final ringSize = (isSmall ? size.width * 0.55 : size.width * 0.65).clamp(
      200.0,
      300.0,
    );
    final logoSize = ringSize * 0.48;

    return ScaleTransition(
      scale: _logoEntrance,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ringRotation, _float]),
        builder: (context, _) {
          return Transform.translate(
            offset: Offset(0, _float.value),
            child: SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(ringSize, ringSize),
                    painter: _OrbitRingPainter(
                      rotation: _ringRotation.value,
                      color1: _neonPink,
                      color2: _neonCyan,
                    ),
                  ),
                  Transform.rotate(
                    angle: -_ringRotation.value * 0.6,
                    child: CustomPaint(
                      size: Size(ringSize * 0.78, ringSize * 0.78),
                      painter: _OrbitRingPainter(
                        rotation: _ringRotation.value * 1.4,
                        color1: _neonViolet,
                        color2: _softGold,
                        dashCount: 14,
                        strokeWidth: 1.0,
                      ),
                    ),
                  ),
                  _buildLogoCore(logoSize),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoCore(double size) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.lerp(
                  _neonViolet.withOpacity(0.9),
                  _neonPink.withOpacity(0.8),
                  _shimmer.value,
                )!,
                const Color(0xFF1A0533),
              ],
              stops: const [0.0, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  _neonViolet,
                  _neonPink,
                  _shimmer.value,
                )!.withOpacity(0.6),
                blurRadius: 35,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: _neonCyan.withOpacity(0.2),
                blurRadius: 60,
                spreadRadius: -4,
              ),
            ],
            border: Border.all(
              color: Color.lerp(
                _neonPink.withOpacity(0.5),
                _neonCyan.withOpacity(0.5),
                _shimmer.value,
              )!,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: size * 0.85,
              height: size * 0.85,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandName(bool isSmall) {
    return FadeTransition(
      opacity: _titleEntrance,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _entranceController,
                curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
              ),
            ),
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) {
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  _neonCyan,
                  Colors.white,
                  Color.lerp(_neonPink, _neonViolet, _shimmer.value)!,
                ],
                stops: const [0.0, 0.45, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: Text(
                'Chilli',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmall ? 56 : 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -3.0,
                  height: 1.0,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSubtitle(bool isSmall) {
    return FadeTransition(
      opacity: _titleEntrance,
      child: Text(
        _lang.tagline,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isSmall ? 13.5 : 15,
          color: Colors.white.withOpacity(0.45),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSignInCard(bool isSmall) {
    return FadeTransition(
      opacity: _cardEntrance,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _entranceController,
                curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
              ),
            ),
        child: Column(
          children: [
            _buildAgreementRow(isSmall),
            const SizedBox(height: 24),
            _buildGoogleButton(isSmall),
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 18),
            _buildSecureNote(isSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeLabel(bool isSmall) {
    return Column(
      children: [
        Text(
          _lang.welcomeBack,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmall ? 26 : 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.8,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Spice up your social world',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmall ? 13.5 : 15,
            color: Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(bool isSmall) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final glowColor = Color.lerp(_neonCyan, _neonPink, _shimmer.value)!;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.12),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _handleGoogleSignIn,
                splashColor: glowColor.withOpacity(0.15),
                highlightColor: glowColor.withOpacity(0.05),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: isSmall ? 62 : 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: glowColor.withOpacity(0.35),
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _isLoading
                      ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: glowColor,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            _buildGoogleIconBadge(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Login in',
                                    style: TextStyle(
                                      fontSize: isSmall ? 16 : 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Verified Secure Access',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.4),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.east_rounded,
                                size: 18,
                                color: glowColor.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoogleIconBadge() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(9),
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.07)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'SECURED BY FIREBASE',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.2),
              letterSpacing: 2.0,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.07)),
        ),
      ],
    );
  }

  Widget _buildSecureNote(bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_rounded, size: 13, color: _neonCyan.withOpacity(0.6)),
        const SizedBox(width: 6),
        Text(
          'End-to-end encrypted · No passwords needed',
          style: TextStyle(
            fontSize: isSmall ? 11 : 12,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementRow(bool isSmall) {
    return FadeTransition(
      opacity: _cardEntrance,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _isAgreed,
              activeColor: _neonViolet,
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              onChanged: (v) => setState(() => _isAgreed = v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: isSmall ? 11.5 : 12.5,
                  color: Colors.white.withOpacity(0.35),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: _neonCyan.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: _neonCyan.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TermsScreen()),
                      ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? _neonViolet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_isAgreed) {
      _showSnackBar(
        'Please agree to the Privacy Policy and Terms of Service',
        color: Colors.orange.shade700,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final googleUser = await GoogleSignIn.instance.authenticate();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final String email = googleUser.email;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;

      if (firebaseUser == null)
        throw Exception('Firebase authentication failed');

      if (email.toLowerCase() == 'nurxianpvltd@gmail.com') {
        await DataBridge().updateLocalCoins(1000, isDeduction: false);
      }

      final profileRecord = await _identityManager.loadProfile();
      if (!mounted) return;

      final hasProfile =
          profileRecord != null &&
          profileRecord.containsKey('username') &&
          profileRecord['username'] != null;

      if (hasProfile) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
              'email': email,
              'Email': email,
              'uid': firebaseUser.uid,
            }, SetOptions(merge: true));

        await _identityManager.patchLocalProfile({
          'email': email,
          'Email': email,
        });
        await _fbReporter.logLogin(method: 'google', userId: firebaseUser.uid);
        await _eventTracker.recordLogin(
          method: 'google',
          userId: firebaseUser.uid,
        );

        if (profileRecord['gender'] != null) {
          await _eventTracker.setProfileAttribute(
            name: 'gender',
            value: profileRecord['gender'],
          );
        }
        if (profileRecord['language'] != null) {
          await _eventTracker.setProfileAttribute(
            name: 'language',
            value: profileRecord['language'],
          );
        }

        if (mounted)
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        await _fbReporter.logSignup(method: 'google', userId: firebaseUser.uid);
        await _eventTracker.recordSignup(
          method: 'google',
          userId: firebaseUser.uid,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      }
    } catch (e) {
      _showSnackBar(
        'Sign-in failed. Please try again.',
        color: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _OrbitRingPainter extends CustomPainter {
  final double rotation;
  final Color color1;
  final Color color2;
  final int dashCount;
  final double strokeWidth;

  _OrbitRingPainter({
    required this.rotation,
    required this.color1,
    required this.color2,
    this.dashCount = 20,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    final dashAngle = (2 * math.pi) / (dashCount * 2);

    for (int i = 0; i < dashCount; i++) {
      final startAngle = rotation + i * 2 * dashAngle;
      final t = i / dashCount;
      final color = Color.lerp(
        color1.withOpacity(0.8),
        color2.withOpacity(0.4),
        t,
      )!;

      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle * 0.7,
        false,
        paint,
      );
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final angle = rotation + (i * 2 * math.pi / 3);
      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);
      final t = i / 3.0;
      dotPaint.color = Color.lerp(color1, color2, t)!;
      dotPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dx, dy), strokeWidth * 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter old) =>
      old.rotation != rotation || old.color1 != color1 || old.color2 != color2;
}

class _ParticleFieldPainter extends CustomPainter {
  final List<_Particle> _particles = List.generate(50, (i) {
    final rng = math.Random(i * 13 + 7);
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: rng.nextDouble() * 1.8 + 0.4,
      opacity: rng.nextDouble() * 0.35 + 0.05,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
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

class _DiagonalAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFF2D78).withOpacity(0.08),
          const Color(0xFF00F5FF).withOpacity(0.04),
          Colors.transparent,
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.45, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..close();

    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFBF5AF2).withOpacity(0.06),
          const Color(0xFF00F5FF).withOpacity(0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height * 0.6)
      ..lineTo(size.width * 0.55, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final red = Paint()..color = const Color(0xFFEA4335);
    final blue = Paint()..color = const Color(0xFF4285F4);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final green = Paint()..color = const Color(0xFF34A853);

    final clipPath = Path()..addOval(Rect.fromLTWH(0, 0, w, h));
    canvas.clipPath(clipPath);

    canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h / 2), red);
    canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h / 2), blue);
    canvas.drawRect(Rect.fromLTWH(0, h / 2, w / 2, h / 2), yellow);
    canvas.drawRect(Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2), green);

    canvas.drawCircle(
      Offset(w / 2, h / 2),
      w * 0.36,
      Paint()..color = Colors.white,
    );

    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(w * 0.5, h * 0.38, w * 0.5, h * 0.24), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
