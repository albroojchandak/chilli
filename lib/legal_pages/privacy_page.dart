import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({Key? key}) : super(key: key);

  // App theme colors - updated to blue palette
  static const Color primaryColor = Color(0xFF4285F4);
  static const Color accentColor = Color(0xFF1A73E8);
  static const Color textPrimaryColor = Color(0xFF424242);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color cardColor = Color(0xFFF0F8FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildParagraph(
              'Inflyratech ("we," "our," or "us") is committed to protecting your privacy and ensuring the security of your personal information when using chilli. This Privacy Policy explains our practices regarding the collection, use, and safeguarding of your data when you use our mobile application chilli (the "App" or "Platform"). This policy is designed to comply with all applicable data protection and privacy laws. Your use of chilli signifies your acceptance of this Privacy Policy.',
            ),

            _buildSectionCard(
              '1. Information Collection',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubsection('1.1 Personal Information', [
                    'Primary Data: Name, contact information, and authentication details for chilli account',
                    'Account Data: User credentials, profile information, and chilli app settings',
                    'Usage Data: Interaction patterns, preferences, and chilli platform activity',
                  ]),
                ],
              ),
            ),

            _buildSectionCard(
              '2. Data Usage and Processing',
              content: _buildBulletPoints([
                'Service Delivery: chilli account management and platform functionality',
                'Security Measures: Fraud prevention and chilli platform protection',
                'Experience Enhancement: chilli service improvement and personalization',
                'Communication: chilli updates, support, and essential notifications',
                'Analytics: chilli platform performance and user experience optimization',
                'Compliance: Legal and regulatory requirements adherence',
              ]),
            ),

            _buildSectionCard(
              '3. Data Protection',
              content: _buildSubsection('Security Measures for chilli', [
                'Industry-standard encryption protocols for chilli data',
                'Regular security audits and updates for chilli platform',
                'Strict access controls and authentication for chilli accounts',
                'Continuous monitoring and threat detection for chilli services',
              ]),
            ),

            _buildSectionCard(
              '4. User Rights',
              content: _buildBulletPoints([
                'Access your personal data stored in chilli',
                'Request data correction or deletion from chilli',
                'Withdraw consent for chilli data processing',
                'Export your chilli data in a portable format',
                'Lodge privacy-related complaints regarding chilli',
              ]),
            ),

            _buildSectionCard(
              '5. Data Sharing',
              content: _buildSubsection('Third-Party Disclosure', [
                'Service Providers: Essential chilli platform operations',
                'Legal Requirements: Compliance with applicable laws regarding chilli',
                'Business Transfers: Corporate restructuring or acquisition affecting chilli',
              ]),
            ),

            _buildSectionCard(
              '6. Data Retention',
              content: _buildParagraph(
                'We retain your chilli information for as long as necessary to provide our services and comply with legal obligations. Upon chilli account deletion, we follow a secure data disposal protocol.',
                bottomPadding: 0,
              ),
            ),

            _buildSectionCard(
              '7. Children\'s Privacy',
              content: _buildParagraph(
                'chilli is not intended for users under the age of 18. We do not knowingly collect or maintain information from children through the chilli platform.',
                bottomPadding: 0,
              ),
            ),

            _buildSectionCard(
              '8. Updates to Privacy Policy',
              content: _buildParagraph(
                'We may update this Privacy Policy for chilli periodically. Users will be notified of significant changes through the chilli platform or via email.',
                bottomPadding: 0,
              ),
            ),

            _buildSectionCard(
              '9. Contact Information',
              content: _buildParagraph('''
Privacy Officer - chilli App
Inflyratech
88, Kehnu, PO + PS Mandi
Fatehpur, Poonch
Jammu & Kashmir, India - 185102

Email: info@inflyratech.site

For chilli privacy-related inquiries or concerns, please contact us using the above information.
              ''', bottomPadding: 0),
            ),

            const SizedBox(height: 20),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.privacy_tip_rounded, size: 32, color: accentColor),
              const SizedBox(width: 12),
              Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 60,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, {required Widget content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 24,
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16.0), child: content),
        ],
      ),
    );
  }

  Widget _buildSubsection(String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...points.map(
          (point) => Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  height: 6,
                  width: 6,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondaryColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParagraph(String text, {double bottomPadding = 16.0}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: textSecondaryColor, height: 1.5),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _buildBulletPoints(List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: points
          .map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondaryColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Divider(color: primaryColor),
          const SizedBox(height: 12),
          Text(
            'Last updated: 2025',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '© Inflyratech - chilli App. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This app is owned and operated by INFLYRATECH PRIVATE LIMITED.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
