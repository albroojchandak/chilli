import 'dart:ui';
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const Color _bg = Color(0xFF06010F);
  static const Color _neonCyan = Color(0xFF00F5FF);
  static const Color _neonPink = Color(0xFFFF2D78);
  static const Color _neonViolet = Color(0xFFBF5AF2);
  static const Color _surface = Color(0xFF151525);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: _bg.withOpacity(0.7),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'PRIVACY PROTOCOL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: _buildGlow(_neonCyan.withOpacity(0.1), 400),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: _buildGlow(_neonViolet.withOpacity(0.1), 350),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 100, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDynamicHeader(),
                const SizedBox(height: 48),
                _buildProtocolSection(
                  '01',
                  'DATA COLLECTION',
                  'We collect personal identification information (email, username, phone number), profile media, and usage metadata. We also access device permissions for camera, microphone, and storage to facilitate P2P voice and video communication.',
                ),
                _buildProtocolSection(
                  '02',
                  'DATA PROCESSING & USAGE',
                  'Collected data is strictly used to maintain your identity node, provide secure communication handshakes, and manage virtual wallet balances. We use Firebase services to synchronize real-time data across the network.',
                ),
                _buildProtocolSection(
                  '03',
                  'SHARING & DISCLOSURE',
                  'Nurxian does not sell user data to third-party entities. We only disclose information to our core infrastructure providers (Firebase, Google Cloud) or when required by legal authorities under the laws of India.',
                ),
                _buildProtocolSection(
                  '04',
                  'CHILDREN’S PRIVACY',
                  'This application is not intended for users under the age of 18. We do not knowingly collect data from children. If we discover such data, it is immediately purged from our mainframe.',
                ),
                _buildProtocolSection(
                  '05',
                  'YOUR PRIVACY RIGHTS',
                  'You have the right to access, rectify, or delete your data at any time. You can initiate account deletion through the support node, which results in the permanent erasure of your identity from our systems.',
                ),
                const SizedBox(height: 40),
                _buildContactNode(),
                const SizedBox(height: 60),
                _buildLegalFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color, double radius) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: radius, spreadRadius: radius / 2),
        ],
      ),
    );
  }

  Widget _buildDynamicHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _neonCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _neonCyan.withOpacity(0.3)),
          ),
          child: const Text(
            'LAST UPDATED: APRIL 2026',
            style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Nurxian Privacy Policy\nData Sovereignty Protocol.',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
        ),
        const SizedBox(height: 16),
        Text(
          'At Chilli, operated by Nurxian, we ensure the absolute integrity of your digital footprint. This protocol outlines our commitment to transparency and play-console compliance.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildProtocolSection(String index, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                index,
                style: TextStyle(color: _neonPink.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              description,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactNode() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, color: _neonCyan, size: 20),
              SizedBox(width: 12),
              Text('NURXIAN HEADQUARTERS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          _contactItem(Icons.location_on_rounded, 'Poonch, J&K, India - 185102'),
          const SizedBox(height: 12),
          _contactItem(Icons.phone_android_rounded, '+91 8899841923'),
          const SizedBox(height: 12),
          _contactItem(Icons.alternate_email_rounded, 'info@nurxian.site'),
        ],
      ),
    );
  }

  Widget _contactItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.3)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
      ],
    );
  }

  Widget _buildLegalFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'CHILLI OS | NURXIAN CORE',
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          Text(
            '© ESTB DEC 2025 NURXIAN. ALL RIGHTS RESERVED.',
            style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 9, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
