import 'dart:ui';
import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
                'NETWORK GOVERNANCE',
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
            left: -100,
            child: _buildGlow(_neonPink.withOpacity(0.05), 400),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 100, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDynamicHeader(),
                const SizedBox(height: 48),
                _buildTermSection(
                  '01',
                  'PLATFORM ACCESS',
                  'By entering the Chilli network, you enter into a binding agreement with Nurxian. You are granted a limited, non-exclusive license to use our P2P communication nodes strictly for personal, non-commercial interaction.',
                ),
                _buildTermSection(
                  '02',
                  'IDENTITY ELIGIBILITY',
                  'You must be at least 18 years of age. Nurxian reserves the right to request proof of age and will immediately terminate any identity node found to be operated by a minor.',
                ),
                _buildTermSection(
                  '03',
                  'CODE OF CONDUCT',
                  'Users must refrain from harassment, hate speech, or the dissemination of explicit illegal material. Any attempt to reverse-engineer the Chilli OS or bypass regional restrictions is a violation of this protocol.',
                ),
                _buildTermSection(
                  '04',
                  'VIRTUAL ASSETS (COINS)',
                  'Virtual coins are internal utilities used to facilitate network handshakes. They have no real-world monetary value outside the Chilli environment, are non-transferable, and non-refundable under any circumstances.',
                ),
                _buildTermSection(
                  '05',
                  'INTELLECTUAL PROPERTY',
                  'The Chilli UI, brand identity, and underlying source code are the sole proprietary assets of Nurxian. You may not reproduce or mirror our mainframe architecture without explicit written authorization.',
                ),
                _buildTermSection(
                  '06',
                  'NETWORK RELIABILITY',
                  'While we strive for 99.9% uptime, Nurxian is not liable for data packet loss, connection drops, or server outages caused by third-party ISP failures or global network anomalies.',
                ),
                _buildTermSection(
                  '07',
                  'ACCOUNT TERMINATION',
                  'Nurxian maintains absolute discretion to blacklist or permanently delete any user account that violates these governance terms without prior warning or compensation for remaining virtual assets.',
                ),
                _buildTermSection(
                  '08',
                  'GOVERNING LAW',
                  'This agreement is governed by the laws of India. Any disputes arising from the usage of the Chilli network shall be subject to the exclusive jurisdiction of the courts in Poonch, J&K.',
                ),
                const SizedBox(height: 48),
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
        const Text(
          'TERMS OF SERVICE',
          style: TextStyle(color: _neonPink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        const Text(
          'Legal Framework\nof the Nurxian Ecosystem.',
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
        ),
        const SizedBox(height: 20),
        Text(
          'Version 2.0 | Last Revised: April 2026',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Please review these terms carefully before establishing your identity node on our network.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildTermSection(String index, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _neonPink.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(index, style: const TextStyle(color: _neonPink, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              description,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.6),
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
          const Text('CONTACT ADDRESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 12),
          Text(
            'Nurxian Core Legal Team\nPoonch, Jammu & Kashmir\nIndia - 185102',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'CHILLI OS | NURXIAN LEGAL',
            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          Text(
            'ESTABLISHED DEC 2025 | ALL RIGHTS RESERVED.',
            style: TextStyle(color: Colors.white.withOpacity(0.05), fontSize: 9, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
