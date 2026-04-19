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
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const String _email = 'info@inflyratech.site';
  static const String _phone = '7889694112';
  static const String _whatsappNumber =
      '917889694112';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=Support%20Request%20-%20Knect%20App',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showSnackBar('Could not open email client', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error opening email: $e', Colors.red);
    }
  }

  Future<void> _launchPhone() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: _phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar('Could not open phone dialer', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error opening phone: $e', Colors.red);
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
      'https://via.placeholder.com/150',
    );
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('WhatsApp not installed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error opening WhatsApp: $e', Colors.red);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied!', const Color(0xFF10B981));
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == const Color(0xFF10B981)
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: CustomScrollView(
        slivers: [

          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF667EEA),
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'Contact Us',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              background: _buildAppBarBackground(),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _buildHeroCard(),
                      const SizedBox(height: 28),

                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 14),
                        child: Text(
                          'Reach Us On',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),

                      _buildContactTile(
                        icon: Icons.email_rounded,
                        gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                        title: 'Email Support',
                        subtitle: _email,
                        badge: 'SUPPORT',
                        badgeColor: const Color(0xFF667EEA),
                        description: 'Send us an email anytime',
                        primaryAction: _ContactAction(
                          label: 'Send Email',
                          icon: Icons.send_rounded,
                          onTap: _launchEmail,
                          gradient: const [
                            Color(0xFF667EEA),
                            Color(0xFF764BA2),
                          ],
                        ),
                        secondaryAction: _ContactAction(
                          label: 'Copy',
                          icon: Icons.copy_rounded,
                          onTap: () => _copyToClipboard(_email, 'Email'),
                          gradient: const [
                            Color(0xFFE0E7FF),
                            Color(0xFFEDE9FE),
                          ],
                          isOutlined: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildContactTile(
                        icon: Icons.phone_rounded,
                        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                        title: 'Phone Support',
                        subtitle: '+91 $_phone',
                        badge: 'CALL',
                        badgeColor: const Color(0xFF10B981),
                        description: 'Available Mon–Sat, 10 AM – 7 PM',
                        primaryAction: _ContactAction(
                          label: 'Call Now',
                          icon: Icons.call_rounded,
                          onTap: _launchPhone,
                          gradient: const [
                            Color(0xFF10B981),
                            Color(0xFF059669),
                          ],
                        ),
                        secondaryAction: _ContactAction(
                          label: 'Copy',
                          icon: Icons.copy_rounded,
                          onTap: () => _copyToClipboard(_phone, 'Phone number'),
                          gradient: const [
                            Color(0xFFD1FAE5),
                            Color(0xFFA7F3D0),
                          ],
                          isOutlined: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildContactTile(
                        icon: Icons.chat_rounded,
                        gradient: const [Color(0xFF25D366), Color(0xFF128C7E)],
                        title: 'WhatsApp',
                        subtitle: '+91 $_phone',
                        badge: 'CHAT',
                        badgeColor: const Color(0xFF25D366),
                        description: 'Chat with us instantly',
                        primaryAction: _ContactAction(
                          label: 'Open WhatsApp',
                          icon: Icons.open_in_new_rounded,
                          onTap: _launchWhatsApp,
                          gradient: const [
                            Color(0xFF25D366),
                            Color(0xFF128C7E),
                          ],
                        ),
                        secondaryAction: _ContactAction(
                          label: 'Copy',
                          icon: Icons.copy_rounded,
                          onTap: () =>
                              _copyToClipboard(_phone, 'WhatsApp number'),
                          gradient: const [
                            Color(0xFFDCFCE7),
                            Color(0xFFBBF7D0),
                          ],
                          isOutlined: true,
                        ),
                      ),

                      const SizedBox(height: 32),

                      _buildResponseInfo(),

                      const SizedBox(height: 16),
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

  Widget _buildAppBarBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFF6B48C4)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 60,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We\'re Here to Help!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Knect Support Team',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 18),
          const Text(
            'Have a question, issue, or feedback? Reach us via email, phone, or WhatsApp. We usually respond within a few hours.',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required String description,
    required _ContactAction primaryAction,
    required _ContactAction secondaryAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [

                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: gradient.first,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [

                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      primaryAction.onTap();
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: primaryAction.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryAction.gradient.first.withOpacity(
                              0.35,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            primaryAction.icon,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            primaryAction.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    secondaryAction.onTap();
                  },
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: secondaryAction.gradient.first.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: secondaryAction.gradient.first.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      secondaryAction.icon,
                      color: primaryAction.gradient.first,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseInfo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFCD34D).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Response Time',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'We typically respond within 2–4 hours on business days.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB45309),
                    height: 1.4,
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

class _ContactAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final List<Color> gradient;
  final bool isOutlined;

  const _ContactAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.gradient,
    this.isOutlined = false,
  });
}

