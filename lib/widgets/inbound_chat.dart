import 'package:flutter/material.dart';

class InboundChatOverlay extends StatefulWidget {
  final String senderName;
  final String senderAvatar;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const InboundChatOverlay({
    super.key,
    required this.senderName,
    required this.senderAvatar,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<InboundChatOverlay> createState() => _InboundChatOverlayState();
}

class _InboundChatOverlayState extends State<InboundChatOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _entryController;
  late AnimationController _msgController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<Offset> _entryAnimation;
  late Animation<double> _msgAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );

    _msgController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );

    _entryAnimation =
        Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
        );

    _msgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _msgController, curve: Curves.easeOut),
    );

    _entryController.forward();

    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _msgController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _entryController.dispose();
    _msgController.dispose();
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
                  const Color(0xFF1E1050).withOpacity(0.97),
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
                    colors: [
                      Color(0xFF1A1030),
                      Color(0xFF231842),
                      Color(0xFF2D1B5E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.25),
                      blurRadius: 50,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 36),
                    _buildChatBadge(),
                    const SizedBox(height: 28),
                    _buildAvatarSection(),
                    const SizedBox(height: 26),
                    Text(
                      widget.senderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _msgAnimation,
                      child: _buildMessagePreview(),
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

  Widget _buildChatBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Color(0xFF34D399),
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Chat Request',
            style: TextStyle(
              color: Color(0xFF34D399),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
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
                    color: const Color(0xFF10B981).withOpacity((1 - v) * 0.3),
                    width: 2,
                  ),
                ),
              );
            },
          );
        }),
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
                    color: const Color(0xFF10B981),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    widget.senderAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF064E3B),
                      child: const Icon(
                        Icons.person,
                        size: 56,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1A1030), width: 3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.message_rounded,
            color: Color(0xFF34D399),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            'Wants to start a conversation',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildRoundButton(
            icon: Icons.close_rounded,
            label: 'Decline',
            color: const Color(0xFFEF4444),
            onTap: widget.onDecline,
          ),
          const SizedBox(width: 40),
          _buildRoundButton(
            icon: Icons.check_rounded,
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
