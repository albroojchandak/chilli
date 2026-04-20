import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

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

class _InboundCallOverlayState extends State<InboundCallOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  
  late Animation<double> _fadeHeader;
  late Animation<double> _scaleAvatar;
  late Animation<double> _fadeInfo;
  late Animation<double> _slideButtons;
  late Animation<double> _pulseGlow;

  static const _neonRose = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _bg = Color(0xFF050510);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _fadeHeader = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _scaleAvatar = CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack));
    _fadeInfo = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut));
    _slideButtons = CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOutQuart));
    
    _pulseGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.7, 1.0, curve: Curves.easeInOut)),
    );

    _ctrl.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Cinematic Background
          _buildBackdrop(),
          
          // 2. Glass Overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: _bg.withOpacity(0.6),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        clipBehavior: Clip.none,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                FadeTransition(opacity: _fadeHeader, child: _buildTypeBadge()),
                                const Spacer(flex: 3),
                                ScaleTransition(scale: _scaleAvatar, child: _buildAvatarCircle()),
                                const Spacer(flex: 2),
                                FadeTransition(opacity: _fadeInfo, child: _buildCallerDetails()),
                                const Spacer(flex: 4),
                                AnimatedBuilder(
                                  animation: _slideButtons,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 50 * (1 - _slideButtons.value)),
                                      child: Opacity(opacity: _slideButtons.value, child: child),
                                    );
                                  },
                                  child: _buildActions(),
                                ),
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    return Positioned.fill(
      child: widget.callerAvatar.isNotEmpty
          ? Image.network(widget.callerAvatar, fit: BoxFit.cover)
          : Container(color: _bg),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkingDot(color: widget.isVideoCall ? _neonCyan : Colors.orange),
          const SizedBox(width: 10),
          Text(
            widget.isVideoCall ? 'INCOMING VIDEO' : 'INCOMING AUDIO',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_neonCyan, Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipOval(
          child: SizedBox(
            width: 180,
            height: 180,
            child: widget.callerAvatar.isNotEmpty
                ? Image.network(widget.callerAvatar, fit: BoxFit.cover)
                : Container(color: _bg, child: const Icon(Icons.person, color: Colors.white24, size: 80)),
          ),
        ),
      ),
    );
  }

  Widget _buildCallerDetails() {
    return Column(
      children: [
        Text(
          widget.callerName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w100,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          width: 40,
          color: _neonCyan.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          widget.isVideoCall ? 'VIDEO CALL' : 'AUDIO CALL',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _roundAction(
          icon: Icons.close_rounded,
          color: _neonRose,
          label: 'DECLINE',
          onTap: widget.onDecline,
        ),
        _roundAction(
          icon: widget.isVideoCall ? Icons.videocam_rounded : Icons.call_rounded,
          color: _neonCyan,
          label: 'ACCEPT',
          onTap: widget.onAccept,
          hasGlow: true,
        ),
      ],
    );
  }

  Widget _roundAction({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool hasGlow = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasGlow)
                _GlowRing(color: color),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_c.value * 0.8 + 0.2),
          boxShadow: [BoxShadow(color: widget.color, blurRadius: 10 * _c.value)],
        ),
      ),
    );
  }
}

class _GlowRing extends StatefulWidget {
  final Color color;
  const _GlowRing({required this.color});

  @override
  State<_GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<_GlowRing> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: 80 + (_c.value * 40),
        height: 80 + (_c.value * 40),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color.withOpacity(1 - _c.value), width: 2),
        ),
      ),
    );
  }
}
