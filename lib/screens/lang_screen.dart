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
    {'id': 'en', 'name': 'English', 'native': 'English', 'flag': '🇬🇧'},
    {'id': 'hi', 'name': 'Hindi', 'native': 'हिंदी', 'flag': '🇮🇳'},
    {'id': 'te', 'name': 'Telugu', 'native': 'తెలుగు', 'flag': '🇮🇳'},
    {'id': 'ta', 'name': 'Tamil', 'native': 'தமிழ்', 'flag': '🇮🇳'},
    {'id': 'mr', 'name': 'Marathi', 'native': 'मరాఠీ', 'flag': '🇮🇳'},
    {'id': 'bn', 'name': 'Bengali', 'native': 'বাংলা', 'flag': '🇮🇳'},
  ];

  String? _selectedId = 'en';
  bool _isFinalizing = false;

  double _angle = 0.0;

  late final AnimationController _entranceController;
  late final AnimationController _ringController;
  late final AnimationController _shimmerController;
  late final AnimationController _floatController;
  late final AnimationController _snapController;

  late final Animation<double> _shimmer;
  late final Animation<double> _float;
  late Animation<double> _snapAnimation;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);
  static const _softGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _floatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _snapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _shimmer = CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut);
    _float = Tween<double>(begin: -8.0, end: 8.0).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    
    _snapAnimation = Tween<double>(begin: 0, end: 0).animate(_snapController);
    _snapController.addListener(() {
      setState(() {
        _angle = _snapAnimation.value;
        _updateSelectionPreview();
      });
    });

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ringController.dispose();
    _shimmerController.dispose();
    _floatController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  Future<void> _handleFinalize() async {
    if (_selectedId == null || _isFinalizing) return;
    HapticFeedback.heavyImpact();
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

  void _onPanUpdate(DragUpdateDetails details, Size dialSize) {
    final center = Offset(dialSize.width / 2, dialSize.height / 2);
    final pos = details.localPosition;
    final posPrev = pos - details.delta;

    final a1 = math.atan2(posPrev.dy - center.dy, posPrev.dx - center.dx);
    final a2 = math.atan2(pos.dy - center.dy, pos.dx - center.dx);
    
    var delta = a2 - a1;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    setState(() {
      _angle += delta;
      _updateSelectionPreview();
    });
  }

  void _updateSelectionPreview() {
    final itemAngle = (2 * math.pi) / _languages.length;
    int nearestIndex = (-_angle / itemAngle).round();
    int normalizedIndex = nearestIndex % _languages.length;
    if (normalizedIndex < 0) normalizedIndex += _languages.length;
    
    final newId = _languages[normalizedIndex]['id'];
    if (_selectedId != newId) {
      _selectedId = newId;
      HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final itemAngle = (2 * math.pi) / _languages.length;
    int nearestIndex = (-_angle / itemAngle).round();
    double targetAngle = -nearestIndex * itemAngle;
    
    _snapAnimation = Tween<double>(begin: _angle, end: targetAngle).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
    );
    _snapController.forward(from: 0.0);
  }

  void _selectLanguage(int index) {
    final itemAngle = (2 * math.pi) / _languages.length;
    double targetAngle = -(index * itemAngle);
    
    double current = _angle % (2 * math.pi);
    if (current > math.pi) current -= 2 * math.pi;
    if (current < -math.pi) current += 2 * math.pi;
    
    double target = targetAngle % (2 * math.pi);
    if (target > math.pi) target -= 2 * math.pi;
    if (target < -math.pi) target += 2 * math.pi;
    
    double diff = target - current;
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;
    
    _snapAnimation = Tween<double>(begin: _angle, end: _angle + diff).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
    );
    _snapController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 680;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomPaint(
            size: size,
            painter: _ParticleFieldPainter(),
          ),
          _buildDiagonalAccent(size),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: isSmall ? 10 : 30),
                _buildTopHeader(),
                Expanded(child: Center(child: _buildInteractiveDial(size))),
                _buildSelectedDetails(isSmall),
                _buildActionButton(isSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
      child: Column(
        children: [
          const Text(
            'IDENTITY',
            style: TextStyle(
              color: _neonCyan,
              fontSize: 13,
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aural Imprint',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Calibrate your frequency to match others.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
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
                Color.lerp(_neonViolet.withOpacity(0.9), _neonPink.withOpacity(0.8), _shimmer.value)!,
                const Color(0xFF1A0533),
              ],
              stops: const [0.0, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(_neonViolet, _neonPink, _shimmer.value)!.withOpacity(0.6),
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
              color: Color.lerp(_neonPink.withOpacity(0.5), _neonCyan.withOpacity(0.5), _shimmer.value)!,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.whatshot_rounded,
            size: size * 0.48,
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildInteractiveDial(Size size) {
    // Determine responsive sizes
    final dialWidth = math.min(size.width * 0.75, 340.0);
    final radius = dialWidth / 2;
    final outerSize = dialWidth + 120; // Extra padding for bounds

    return FadeTransition(
      opacity: CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.7, curve: Curves.easeOut)),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 0.7, curve: Curves.easeOutBack)),
        child: SizedBox(
          width: outerSize,
          height: outerSize,
          child: GestureDetector(
            onPanUpdate: (details) => _onPanUpdate(details, Size(outerSize, outerSize)),
            onPanEnd: _onPanEnd,
            child: Container(
              color: Colors.transparent, // Capture taps
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outer passive rotating orbits mapped from AuthScreen
                  AnimatedBuilder(
                    animation: Listenable.merge([_ringController, _float]),
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: Transform.rotate(
                        angle: _ringController.value * 2 * math.pi,
                        child: CustomPaint(
                          size: Size(dialWidth * 0.85, dialWidth * 0.85),
                          painter: _OrbitRingPainter(
                            rotation: 0,
                            color1: _neonPink,
                            color2: _neonCyan,
                          ),
                        ),
                      ),
                    ),
                  ),

                  AnimatedBuilder(
                    animation: Listenable.merge([_ringController, _float]),
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: Transform.rotate(
                        angle: -_ringController.value * 1.5 * math.pi,
                        child: CustomPaint(
                          size: Size(dialWidth * 0.65, dialWidth * 0.65),
                          painter: _OrbitRingPainter(
                            rotation: 0,
                            color1: _neonViolet,
                            color2: _softGold,
                            dashCount: 14,
                            strokeWidth: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Interactive Radar Lines and Sweep matching custom angle
                  AnimatedBuilder(
                    animation: Listenable.merge([_float]),
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: CustomPaint(
                        size: Size(dialWidth, dialWidth),
                        painter: _RadarConnectionsPainter(
                          angleOffset: _angle,
                          count: _languages.length,
                          color1: _neonCyan,
                          color2: _neonViolet,
                        ),
                      ),
                    ),
                  ),
                  
                  // Central Logo matching auth screen
                  AnimatedBuilder(
                    animation: _float,
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: _buildLogoCore(dialWidth * 0.35),
                    )
                  ),

                  // Floating UI Nodes
                  ...List.generate(_languages.length, (i) {
                     final itemAngle = (2 * math.pi) / _languages.length;
                     final a = -math.pi / 2 + i * itemAngle + _angle;
                     final dx = radius * math.cos(a);
                     final dy = radius * math.sin(a);
                     
                     final lang = _languages[i];
                     final isTop = _selectedId == lang['id'];

                     return AnimatedBuilder(
                        animation: _float,
                        builder: (context, _) => Transform.translate(
                          offset: Offset(dx, dy + _float.value),
                          child: GestureDetector(
                            onTap: () => _selectLanguage(i),
                            child: _buildOrbitalNode(lang, isTop),
                          ),
                        )
                     );
                  }),
                  
                  // Fixed HUD Reticle
                  AnimatedBuilder(
                    animation: _float,
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: CustomPaint(
                        size: Size(dialWidth, dialWidth),
                        painter: _ReticlePainter(color: _neonCyan),
                      ),
                    )
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitalNode(Map<String, String> lang, bool isTop) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isTop ? 64 : 48,
      height: isTop ? 64 : 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bg,
        border: Border.all(
          color: isTop ? _neonCyan : Colors.white.withOpacity(0.2),
          width: isTop ? 2.5 : 1.0,
        ),
        boxShadow: isTop ? [BoxShadow(color: _neonCyan.withOpacity(0.5), blurRadius: 20)] : [],
      ),
      child: Center(
        child: Text(
          lang['flag']!,
          style: TextStyle(fontSize: isTop ? 32 : 18),
        ),
      ),
    );
  }

  Widget _buildSelectedDetails(bool isSmall) {
    final lang = _languages.firstWhere((l) => l['id'] == _selectedId);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entranceController, curve: const Interval(0.5, 0.9, curve: Curves.easeOut)),
      child: Container(
        constraints: BoxConstraints(minHeight: isSmall ? 80 : 100),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              lang['native']!,
              key: ValueKey(lang['id']),
              style: TextStyle(
                 color: Colors.white,
                 fontSize: isSmall ? 32 : 46,
                 fontWeight: FontWeight.w900,
                 letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
               decoration: BoxDecoration(
                 color: _neonViolet.withOpacity(0.15),
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: _neonViolet.withOpacity(0.5)),
               ),
               child: Text(
                 lang['name']!.toUpperCase(),
                 style: const TextStyle(color: _neonCyan, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
               ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isSmall) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entranceController, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)),
      child: GestureDetector(
        onTap: _handleFinalize,
        child: Container(
          height: isSmall ? 56 : 64,
          margin: EdgeInsets.symmetric(horizontal: 32, vertical: isSmall ? 10 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [_neonCyan.withOpacity(0.15), _neonViolet.withOpacity(0.15)],
            ),
            border: Border.all(color: _neonCyan.withOpacity(0.5), width: 1.5),
            boxShadow: [
               BoxShadow(color: _neonCyan.withOpacity(0.2), blurRadius: 20),
            ]
          ),
          child: Center(
            child: _isFinalizing 
              ? const CircularProgressIndicator(color: _neonCyan) 
              : const Text('INITIALIZE', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 3)),
          ),
        )
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Custom Painters matching the "Auth Design"
// ----------------------------------------------------------------------------

class _RadarConnectionsPainter extends CustomPainter {
  final double angleOffset;
  final int count;
  final Color color1;
  final Color color2;

  _RadarConnectionsPainter({
    required this.angleOffset,
    required this.count,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final itemAngle = (2 * math.pi) / count;
    
    // Sweep Radar mapped specifically to the top
    final sweepGradient = SweepGradient(
      center: FractionalOffset.center,
      startAngle: -0.6,
      endAngle: 0.6,
      colors: [Colors.transparent, color1.withOpacity(0.4), Colors.transparent],
      transform: const GradientRotation(-math.pi / 2),
    );
    
    final arcPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, arcPaint);
    
    // Outer dial dashes
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final dashCount = 60;
    final dashAngle = (2 * math.pi) / (dashCount * 2);
    for (int i = 0; i < dashCount; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * 2 * dashAngle,
          dashAngle,
          false,
          dashPaint,
        );
    }

    // Interactive connection lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0;
      
    for (int i = 0; i < count; i++) {
       final a = -math.pi / 2 + i * itemAngle + angleOffset;
       final dx = center.dx + radius * math.cos(a);
       final dy = center.dy + radius * math.sin(a);
       
       canvas.drawLine(center, Offset(dx, dy), linePaint);
       
       // Nodes
       canvas.drawCircle(Offset(dx, dy), 3, Paint()..color=color1);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarConnectionsPainter old) => old.angleOffset != angleOffset;
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    
    final p = Path()
      ..moveTo(center.dx, center.dy - r - 8)
      ..lineTo(center.dx - 12, center.dy - r - 24)
      ..lineTo(center.dx + 12, center.dy - r - 24)
      ..close();
      
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      
    canvas.drawPath(p, paint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
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
      final color = Color.lerp(color1.withOpacity(0.8), color2.withOpacity(0.4), t)!;

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
