import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

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
        title: const Text('Terms of Service', style: TextStyle(color: _textBright, fontWeight: FontWeight.w700, fontSize: 18)),
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
            _buildInfoCard('1. Acceptance of Terms', _buildText('By accessing or using Chilli, you agree to be bound by these Terms of Service. If you do not agree to all of the terms and conditions, you may not access or use our services.')),
            _buildInfoCard('2. Age Requirements', _buildText('You must be at least 18 years of age to use this application. By using Chilli, you represent and warrant that you meet this age requirement.')),
            _buildInfoCard('3. Account Responsibilities', _buildBulletList([
              'You are responsible for maintaining the confidentiality of your account',
              'You are responsible for all activities that occur under your account',
              'You must provide accurate and complete registration information',
              'You must notify us immediately of any unauthorized use of your account',
            ])),
            _buildInfoCard('4. Content & Conduct', _buildBulletList([
              'Users must not post inappropriate or illegal content',
              'Users must respect the privacy and rights of others',
              'Harassment or abuse of other users will result in account termination',
              'We reserve the right to remove content at our discretion',
            ])),
            _buildInfoCard('5. Intellectual Property', _buildText('All content and materials provided on the platform are the property of Inflyratech and are protected by applicable intellectual property laws.')),
            _buildInfoCard('6. Limitation of Liability', _buildText('Chilli and Inflyratech shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use of the services.')),
            _buildInfoCard('7. Termination', _buildText('We reserve the right to suspend or terminate your access to the platform at any time for any reason, including violation of these Terms.')),
            _buildInfoCard('8. Governing Law', _buildText('These Terms shall be governed by and construed in accordance with the laws of India.')),
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
        gradient: LinearGradient(colors: [_accent, _accent.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _accent.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terms of Use', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Agreement for platform use', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
            decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
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

  Widget _buildText(String text) {
    return Text(text, style: const TextStyle(color: _textMuted, fontSize: 14, height: 1.6));
  }

  Widget _buildBulletList(List<String> points) {
    return Column(
      children: points.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(margin: const EdgeInsets.only(top: 7), width: 5, height: 5, decoration: const BoxDecoration(color: _accentLight, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(p, style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.5))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _accent.withOpacity(0.15))),
      child: const Column(
        children: [
          Text('© Inflyratech. All rights reserved.', style: TextStyle(color: _textBright, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
