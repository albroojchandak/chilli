import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with TickerProviderStateMixin {
  late AnimationController _appearController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const String _email = 'info@nurxian.site';
  static const String _phone = '8899841923';
  static const String _whatsappNumber =
      '918899841923'; // With country code for India

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutExpo,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _appearController, curve: Curves.easeOutBack),
        );

    _appearController.forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=Support%20Request%20-%20chilli%20App',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showSnackBar('Could not open email client', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('Error opening email: $e', Colors.redAccent);
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: _phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar('Could not open phone dialer', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('Error opening phone: $e', Colors.redAccent);
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=Hello%20chilli%20Support%2C%20I%20need%20help%20with...',
    );
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('WhatsApp not installed', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('Error opening WhatsApp: $e', Colors.redAccent);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied! ✨', const Color(0xFFC084FC));
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Glowing Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B).withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE11D48).withOpacity(0.1),
              ),
            ),
          ),
          // Blur filter for glassmorphism
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF1E293B).withOpacity(0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFF1E293B),
                        size: 18,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  centerTitle: true,
                  title: const Text(
                    'HIT US UP',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Got a vibe\ncheck? 🚀',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Don't ghost us. Drop a message, call, or whatever floats your boat.",
                              style: TextStyle(
                                fontSize: 16,
                                color: const Color(0xFF1E293B).withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Bento Box Layout
                            Row(
                              children: [
                                Expanded(
                                  child: _BentoCard(
                                    height: 180,
                                    color: const Color(0xFF25D366),
                                    icon: Icons.chat_bubble_rounded,
                                    title: 'WhatsApp',
                                    subtitle: 'Fastest reply',
                                    onTap: _launchWhatsApp,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _BentoCard(
                                        height: 82,
                                        color: const Color(0xFF8B5CF6),
                                        icon: Icons.mail_rounded,
                                        title: 'Email',
                                        subtitle: '',
                                        onTap: _launchEmail,
                                        horizontal: true,
                                      ),
                                      const SizedBox(height: 16),
                                      _BentoCard(
                                        height: 82,
                                        color: const Color(0xFFEC4899),
                                        icon: Icons.phone_rounded,
                                        title: 'Call',
                                        subtitle: '',
                                        onTap: _launchPhone,
                                        horizontal: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Info Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: const Color(
                                    0xFF1E293B,
                                  ).withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _InfoRow(
                                    icon: Icons.alternate_email,
                                    value: _email,
                                    onCopy: () =>
                                        _copyToClipboard(_email, 'Email'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Divider(
                                      color: const Color(
                                        0xFF1E293B,
                                      ).withOpacity(0.12),
                                    ),
                                  ),
                                  _InfoRow(
                                    icon: Icons.tag,
                                    value: '+91 $_phone',
                                    onCopy: () =>
                                        _copyToClipboard(_phone, 'Phone'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Footer vibe
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.bolt,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'We reply at lightning speed',
                                      style: TextStyle(
                                        color: const Color(
                                          0xFF1E293B,
                                        ).withOpacity(0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final double height;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool horizontal;

  const _BentoCard({
    required this.height,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: height,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: horizontal
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: const Color(0xFF1E293B).withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback onCopy;

  const _InfoRow({
    required this.icon,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E293B).withOpacity(0.5), size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onCopy();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Copy',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
