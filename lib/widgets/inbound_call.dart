import 'dart:ui';
import 'package:flutter/material.dart';

class InboundCall extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final bool isVideoCall;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const InboundCall({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.isVideoCall,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<InboundCall> createState() => _InboundCallState();
}

class _InboundCallState extends State<InboundCall> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color _neonCyan = Color(0xFF00F5FF);
  static const Color _neonPink = Color(0xFFFF2D78);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark blurred overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),

          // Main dialog
          SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151525).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _neonCyan.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: _neonCyan.withOpacity(0.1),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),

                        // Call type indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _neonCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _neonCyan.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isVideoCall ? Icons.videocam_rounded : Icons.call_rounded,
                                color: _neonCyan,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isVideoCall ? 'SECURE VIDEO NODE' : 'SECURE VOICE NODE',
                                style: const TextStyle(
                                  color: _neonCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Avatar with GenZ neon ripples
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ripple circles
                            ...List.generate(3, (index) {
                              return AnimatedBuilder(
                                animation: _rippleAnimation,
                                builder: (context, child) {
                                  final delay = index * 0.33;
                                  final animValue = (_rippleAnimation.value - delay).clamp(0.0, 1.0);
                                  return Container(
                                    width: 130 + (animValue * 80),
                                    height: 130 + (animValue * 80),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _neonCyan.withOpacity((1 - animValue) * 0.5),
                                        width: 2,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),

                            // Avatar
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _neonCyan,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _neonCyan.withOpacity(0.5),
                                          blurRadius: 30,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        widget.callerAvatar,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.white.withOpacity(0.1),
                                            child: const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Caller name
                        Text(
                          widget.callerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        // Calling text
                        Text(
                          'INCOMING TRANSMISSION...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Decline button
                              _buildActionButton(
                                icon: Icons.call_end_rounded,
                                label: 'DECLINE',
                                color: _neonPink,
                                onTap: widget.onDecline,
                              ),

                              const SizedBox(width: 40),

                              // Accept button
                              _buildActionButton(
                                icon: Icons.call_rounded,
                                label: 'ACCEPT',
                                color: const Color(0xFF10B981), // Emerald/Neon Green
                                onTap: widget.onAccept,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

