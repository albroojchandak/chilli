import 'dart:ui';
import 'package:flutter/material.dart';

class RestrictionPage extends StatelessWidget {
  const RestrictionPage({super.key});

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
                'RESTRICTION PROTOCOL',
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
            child: _buildGlow(_neonViolet.withOpacity(0.1), 400),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 100, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                _buildRestrictionSection(
                  '01',
                  'HARASSMENT ZERO-TOLERANCE',
                  'Any form of abuse, cyberbullying, or harassment is strictly prohibited on the network. Users found engaging in such activities will face immediate blacklisting.',
                ),
                _buildRestrictionSection(
                  '02',
                  'ILLEGAL CONTENT PURGE',
                  'Sharing or distributing illegal, explicit, or unauthorized material will result in an immediate ban and potential reporting to cyber authorities.',
                ),
                _buildRestrictionSection(
                  '03',
                  'UNDERAGE RESTRICTIONS',
                  'The Chilli platform is strictly engineered for users aged 18 and above. Access by minors is a violation of our protocol and will lead to an unrecoverable account wipe.',
                ),
                const SizedBox(height: 40),
                _buildWarningBox(),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCOUNT RESTRICTIONS',
          style: TextStyle(color: _neonViolet, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        const Text(
          'Network Conduct\n& Safety Standards.',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1),
        ),
        const SizedBox(height: 16),
        Text(
          'To ensure the integrity of the ecosystem, all users must adhere to strict behavioral protocols. Violations are absolute.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildRestrictionSection(String index, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _neonViolet.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(index, style: const TextStyle(color: _neonViolet, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
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

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _neonPink.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _neonPink.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _neonPink, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Repeated offenses or severe violations bypass the warning phase and proceed directly to a permanent IP and device ban.',
              style: TextStyle(color: _neonPink.withOpacity(0.8), fontSize: 12, height: 1.6, fontWeight: FontWeight.w600),
            ),
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
            'CHILLI OS | SECURITY CORE',
            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          Text(
            'NURXIAN ENFORCEMENT NODE',
            style: TextStyle(color: Colors.white.withOpacity(0.05), fontSize: 9, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
