import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({Key? key}) : super(key: key);

  static const Color _bg = Color(0xFF0F0A1E);
  static const Color _surface = Color(0xFF1A1030);
  static const Color _card = Color(0xFF231842);
  static const Color _accent = Color(0xFF7C3AED);
  static const Color _accentLight = Color(0xFFA78BFA);
  static const Color _textBright = Color(0xFFF1F0F7);
  static const Color _textMuted = Color(0xFF9B93B8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _accentLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: _textBright,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _accent.withOpacity(0.2)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBanner(),
            const SizedBox(height: 24),
            _buildInfoCard('1. Information Collection', _buildBulletList([
              'Primary Data: Name, contact information, and authentication details',
              'Account Data: User credentials, profile information, and app settings',
              'Usage Data: Interaction patterns, preferences, and platform activity',
            ])),
            _buildInfoCard('2. Data Usage & Processing', _buildBulletList([
              'Service Delivery: Account management and platform functionality',
              'Security Measures: Fraud prevention and platform protection',
              'Experience Enhancement: Service improvement and personalization',
              'Communication: Updates, support, and essential notifications',
              'Analytics: Platform performance and user experience optimization',
              'Compliance: Legal and regulatory requirements adherence',
            ])),
            _buildInfoCard('3. Data Protection', _buildBulletList([
              'Industry-standard encryption protocols',
              'Regular security audits and updates',
              'Strict access controls and authentication',
              'Continuous monitoring and threat detection',
            ])),
            _buildInfoCard('4. User Rights', _buildBulletList([
              'Access your personal data stored in the app',
              'Request data correction or deletion',
              'Withdraw consent for data processing',
              'Export your data in a portable format',
              'Lodge privacy-related complaints',
            ])),
            _buildInfoCard('5. Data Sharing', _buildBulletList([
              'Service Providers: Essential platform operations',
              'Legal Requirements: Compliance with applicable laws',
              'Business Transfers: Corporate restructuring or acquisition',
            ])),
            _buildInfoCard('6. Data Retention',
              Text(
                'We retain your information for as long as necessary to provide our services and comply with legal obligations. Upon account deletion, we follow a secure data disposal protocol.',
                style: TextStyle(color: _textMuted, fontSize: 14, height: 1.6),
              ),
            ),
            _buildInfoCard('7. Children\'s Privacy',
              Text(
                'This app is not intended for users under the age of 18. We do not knowingly collect or maintain information from children.',
                style: TextStyle(color: _textMuted, fontSize: 14, height: 1.6),
              ),
            ),
            _buildInfoCard('8. Policy Updates',
              Text(
                'We may update this Privacy Policy periodically. Users will be notified of significant changes through the platform or via email.',
                style: TextStyle(color: _textMuted, fontSize: 14, height: 1.6),
              ),
            ),
            _buildInfoCard('9. Contact Information',
              Text(
                'Privacy Officer\nInflyratech\n88, Kehnu, PO + PS Mandi\nFatehpur, Poonch\nJammu & Kashmir, India - 185102\n\nEmail: info@inflyratech.site',
                style: TextStyle(color: _textMuted, fontSize: 14, height: 1.7),
              ),
            ),
            const SizedBox(height: 16),
            _buildFooter(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent, _accent.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('How we protect your data', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, Widget content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withOpacity(0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 18, decoration: BoxDecoration(color: _accentLight, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(color: _textBright, fontWeight: FontWeight.w700, fontSize: 15))),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: content),
        ],
      ),
    );
  }

  Widget _buildBulletList(List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: points.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(margin: const EdgeInsets.only(top: 7, right: 10), width: 5, height: 5, decoration: BoxDecoration(color: _accentLight, shape: BoxShape.circle)),
            Expanded(child: Text(p, style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.5))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Divider(color: _accent.withOpacity(0.3)),
          const SizedBox(height: 10),
          const Text('Last updated: 2025', style: TextStyle(color: _textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          const Text('© Inflyratech. All rights reserved.', style: TextStyle(color: _textBright, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Owned and operated by INFLYRATECH PRIVATE LIMITED.', style: TextStyle(color: _textMuted, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
