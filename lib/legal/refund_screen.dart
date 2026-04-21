import 'dart:ui';
import 'package:flutter/material.dart';

class RefundScreen extends StatelessWidget {
  const RefundScreen({super.key});

  static const Color _bg = Color(0xFF06010F);
  static const Color _neonCyan = Color(0xFF00F5FF);
  static const Color _neonPink = Color(0xFFFF2D78);
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
                'REFUND PROTOCOL',
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
            child: _buildGlow(_neonCyan.withOpacity(0.05), 400),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 100, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                _buildPolicySection(
                  '01',
                  'VIRTUAL ASSET POLICY',
                  'All coin purchases within the Chilli network are final. As virtual assets are consumed immediately upon credit to your wallet, Nurxian does not offer standard refunds for used or partially used assets.',
                ),
                _buildPolicySection(
                  '02',
                  'ELIGIBLE EXCEPTIONS',
                  'Refunds may be considered only in cases of documented technical failure where coins were not credited after a successful transaction, or in cases of unintentional double-billing within a 24-hour window.',
                ),
                _buildPolicySection(
                  '03',
                  'REFUND TIMELINE',
                  'Eligible refund requests must be filed within 48 hours of the transaction. Once approved by the Nurxian billing node, the reversal may take 5-7 business days to reflect in your original payment source.',
                ),
                _buildPolicySection(
                  '04',
                  'REQUEST PROCEDURE',
                  'To initiate a reversal, navigate to the Support Hub and provide your Transaction ID, date, and a brief description of the technical anomaly. Screenshots of the debit notification are required.',
                ),
                _buildPolicySection(
                  '05',
                  'DENIAL CRITERIA',
                  'Requests will be rejected if coins have already been consumed for services, if the account is currently blacklisted for conduct violations, or if the claim is made after the 48-hour mandatory window.',
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
          'TRANSACTION REVERSAL',
          style: TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        const Text(
          'Nurxian Billing\nStandard Protocols.',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1),
        ),
        const SizedBox(height: 16),
        Text(
          'Our billing node ensures fair transactions. This protocol outlines the conditions under which a reversal can be initiated.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildPolicySection(String index, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '[$index]',
                style: const TextStyle(color: _neonCyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              description,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.6),
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
          const Icon(Icons.info_outline_rounded, color: _neonPink, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'For Play Store / App Store billing, refunds must be requested directly through the respective platform vendor policy.',
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
            'CHILLI OS | BILLING CORE',
            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3),
          ),
          const SizedBox(height: 8),
          Text(
            'POONCH, J&K | NURXIAN PRIVATE LIMITED',
            style: TextStyle(color: Colors.white.withOpacity(0.05), fontSize: 9, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
