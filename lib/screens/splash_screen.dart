import 'package:flutter/material.dart';
import 'package:chilli/theme/palette.dart';
import 'dart:math' as math;
import 'dart:ui';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _glowController;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _logoRotate;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scale = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    );

    _logoRotate = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutBack),
      ),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Stack(
        children: [
          // Animated Mesh Gradient Background
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) => CustomPaint(
              painter: _MeshPainter(_glowController.value),
              size: size,
            ),
          ),
          
          // Noise/Grain Overlay
          Opacity(
            opacity: 0.05,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://www.transparenttextures.com/patterns/p6.png'),
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with complex entrance
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: AnimatedBuilder(
                      animation: _logoRotate,
                      builder: (context, child) => Transform.rotate(
                        angle: _logoRotate.value * math.pi * 0.1,
                        child: child,
                      ),
                      child: Container(
                        width: 160,
                        height: 160,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.primary.withOpacity(0.4),
                              blurRadius: 50,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Neon Ring
                            AnimatedBuilder(
                              animation: _glowController,
                              builder: (context, _) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Color.lerp(
                                      AppPalette.primary,
                                      AppPalette.secondary,
                                      _glowController.value,
                                    )!.withOpacity(0.8),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                            // The actual Logo
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Animated Text
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      Text(
                        'CHILLI',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 12,
                          shadows: [
                            Shadow(
                              color: AppPalette.primary.withOpacity(0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.01),
                            ],
                          ),
                        ),
                        child: Text(
                          'PREMIUM SOCIAL NETWORK',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Interactive Particle Layer or simple loading
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation(
                            Color.lerp(AppPalette.primary, AppPalette.secondary, 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ESTABLISHING SECURE CONNECTION',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
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
}

class _MeshPainter extends CustomPainter {
  final double progress;
  _MeshPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Dynamic Blob 1
    final p1 = Offset(
      size.width * 0.2 + math.sin(progress * math.pi) * 50,
      size.height * 0.3 + math.cos(progress * math.pi) * 30,
    );
    canvas.drawCircle(p1, 200, paint..color = AppPalette.primary.withOpacity(0.15));

    // Dynamic Blob 2
    final p2 = Offset(
      size.width * 0.8 - math.cos(progress * math.pi) * 40,
      size.height * 0.7 + math.sin(progress * math.pi) * 60,
    );
    canvas.drawCircle(p2, 250, paint..color = AppPalette.secondary.withOpacity(0.1));

    // Accent Bloom
    final p3 = Offset(
      size.width * 0.5,
      size.height * 0.5 + math.sin(progress * math.pi * 2) * 20,
    );
    canvas.drawCircle(p3, 150, paint..color = const Color(0xFF7000FF).withOpacity(0.08));
  }

  @override
  bool shouldRepaint(_MeshPainter old) => true;
}
