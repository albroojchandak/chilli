import 'package:flutter/material.dart';
import 'dart:math' as math;

class InboundCallOverlay extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final bool isVideoCall;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const InboundCallOverlay({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    required this.isVideoCall,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<InboundCallOverlay> createState() => _InboundCallOverlayState();
}

class _InboundCallOverlayState extends State<InboundCallOverlay>
    with TickerProviderStateMixin {
  late AnimationController _beatController;
  late AnimationController _waveController;
  late AnimationController _entryController;
  late Animation<double> _beatAnimation;
  late Animation<double> _waveAnimation;
  late Animation<Offset> _entryAnimation;

  @override
  void initState() {
    super.initState();

    _beatController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _beatAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _beatController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    _entryAnimation =
        Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
        );

    _entryController.forward();
  }

  @override
  void dispose() {
    _beatController.dispose();
    _waveController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F0A1E).withOpacity(0.85),
                  const Color(0xFF3B0764).withOpacity(0.97),
                ],
              ),
            ),
          ),
          SlideTransition(
            position: _entryAnimation,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1030), Color(0xFF2D1B5E)],
                  ),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.5),
                      blurRadius: 50,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 36),
                    _buildCallTypeBadge(),
                    const SizedBox(height: 28),
                    _buildAvatarRipple(),
                    const SizedBox(height: 28),
                    Text(
                      widget.callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Incoming call...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 44),
                    _buildActions(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF7C3AED).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isVideoCall ? Icons.videocam_rounded : Icons.call_rounded,
            color: const Color(0xFFA78BFA),
            size: 17,
          ),
          const SizedBox(width: 7),
          Text(
            widget.isVideoCall ? 'Video Call' : 'Voice Call',
            style: const TextStyle(
              color: Color(0xFFA78BFA),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarRipple() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              final delay = index * 0.33;
              final v = (_waveAnimation.value - delay).clamp(0.0, 1.0);
              return Container(
                width: 130 + (v * 70),
                height: 130 + (v * 70),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity((1 - v) * 0.35),
                    width: 2,
                  ),
                ),
              );
            },
          );
        }),
        AnimatedBuilder(
          animation: _beatAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _beatAnimation.value,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF7C3AED), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    widget.callerAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2D1B5E),
                      child: const Icon(
                        Icons.person,
                        size: 56,
                        color: Color(0xFFA78BFA),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildRoundButton(
            icon: Icons.call_end_rounded,
            label: 'Decline',
            color: const Color(0xFFEF4444),
            onTap: widget.onDecline,
          ),
          const SizedBox(width: 40),
          _buildRoundButton(
            icon: Icons.call_rounded,
            label: 'Accept',
            color: const Color(0xFF10B981),
            onTap: widget.onAccept,
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
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
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.75)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
