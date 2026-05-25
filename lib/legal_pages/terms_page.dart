import 'package:flutter/material.dart';

class Terms_Page extends StatelessWidget {
  const Terms_Page({Key? key}) : super(key: key);

  // App theme colors - blue theme
  static const Color primaryColor = Color(0xFF4285F4);
  static const Color accentColor = Color(0xFF1A73E8);
  static const Color textPrimaryColor = Color(0xFF424242);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color cardColor = Color(0xFFF0F8FF);

  Widget _buildSectionCard(
    String title, {
    String? content,
    List<Widget>? children,
  }) {
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (content != null)
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: textSecondaryColor,
                    ),
                  ),
                if (children != null) ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
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
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: textSecondaryColor,
              ),
            ),
          ),
        ],
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
              Icon(Icons.gavel_rounded, size: 32, color: accentColor),
              const SizedBox(width: 12),
              Text(
                'Terms of Use',
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
            "Note: These Terms of Use for chilli are guidelines and do not replace or supersede any legal obligations or requirements as outlined in relevant laws, including the Indian Penal Code.",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Terms of Use",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                "By accessing or using the chilli app, you agree to be bound by these Terms of Use. If you do not agree, discontinue use of chilli immediately.",
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                  height: 1.5,
                ),
              ),
            ),

            _buildSectionCard(
              "1. PURPOSE OF chilli",
              content:
                  "chilli is designed to facilitate meaningful social interactions through a secure and moderated environment. We provide a space where Users can engage with verified Hosts in constructive conversations while maintaining the highest standards of safety and professionalism on the chilli platform.",
            ),

            _buildSectionCard(
              "2. ACCEPTABLE USER CONDUCT ON chilli",
              children: [
                _buildBulletPoint(
                  "Users must maintain professional decorum and exhibit courteous behavior at all times on chilli",
                ),
                _buildBulletPoint(
                  "Respect intellectual property rights and confidentiality obligations within chilli",
                ),
                _buildBulletPoint(
                  "Adhere to chilli platform guidelines and community standards",
                ),
              ],
            ),

            _buildSectionCard(
              "3. PROHIBITED CONDUCT ON chilli",
              children: [
                _buildBulletPoint(
                  "Any form of harassment, intimidation, or threatening behavior on chilli",
                ),
                _buildBulletPoint(
                  "Hate speech, discrimination, or content that promotes prejudice within chilli",
                ),
                _buildBulletPoint(
                  "Unauthorized commercial solicitation or promotional activities on chilli",
                ),
                _buildBulletPoint(
                  "Distribution of malicious content or attempts to compromise chilli platform security",
                ),
              ],
            ),

            _buildSectionCard(
              "4. PRIVACY AND DATA PROTECTION IN chilli",
              children: [
                _buildBulletPoint(
                  "Strict adherence to data protection regulations and privacy laws for chilli users",
                ),
                _buildBulletPoint(
                  "Prohibition of unauthorized recording, sharing, or distribution of chilli content",
                ),
                _buildBulletPoint(
                  "Mandatory compliance with chilli's privacy policy and security protocols",
                ),
              ],
            ),

            _buildSectionCard(
              "5. chilli PLATFORM SAFETY",
              children: [
                _buildBulletPoint(
                  "Zero-tolerance policy for exploitation or harmful content on chilli",
                ),
                _buildBulletPoint(
                  "Advanced monitoring systems for chilli user protection",
                ),
                _buildBulletPoint(
                  "Immediate action on safety violations and legal compliance within chilli",
                ),
              ],
            ),

            _buildSectionCard(
              "6. VIRTUAL CURRENCY AND TRANSACTIONS IN chilli",
              children: [
                _buildBulletPoint(
                  "All virtual currency transactions within chilli are final and non-refundable",
                ),
                _buildBulletPoint(
                  "Virtual currency in chilli holds no real-world monetary value",
                ),
                _buildBulletPoint(
                  "Compliance with applicable financial regulations and chilli policies",
                ),
              ],
            ),

            _buildSectionCard(
              "7. chilli CONTENT GUIDELINES",
              children: [
                _buildBulletPoint(
                  "All content on chilli must comply with applicable laws and regulations",
                ),
                _buildBulletPoint(
                  "Strict adherence to intellectual property rights within chilli",
                ),
                _buildBulletPoint(
                  "Professional and constructive communication standards on chilli",
                ),
              ],
            ),

            _buildSectionCard(
              "8. chilli MODERATION AND ENFORCEMENT",
              children: [
                _buildBulletPoint(
                  "Systematic review and moderation of reported violations on chilli",
                ),
                _buildBulletPoint(
                  "Transparent investigation procedures for chilli violations",
                ),
                _buildBulletPoint(
                  "Graduated response system for chilli policy violations",
                ),
              ],
            ),

            _buildSectionCard(
              "9. chilli USER ACCOUNTABILITY",
              children: [
                _buildBulletPoint(
                  "Users bear full responsibility for their activities on chilli",
                ),
                _buildBulletPoint(
                  "Compliance with terms is mandatory for continued chilli access",
                ),
                _buildBulletPoint(
                  "Legal liability for violation of chilli terms or applicable laws",
                ),
              ],
            ),

            _buildSectionCard(
              "10. chilli LIABILITY LIMITATIONS",
              children: [
                _buildBulletPoint(
                  "chilli service provided on an 'as is' and 'as available' basis",
                ),
                _buildBulletPoint(
                  "No warranties regarding chilli service reliability or outcomes",
                ),
                _buildBulletPoint(
                  "Limited liability as permitted by applicable law for chilli services",
                ),
              ],
            ),

            _buildSectionCard(
              "11. chilli TERMS MODIFICATION",
              content:
                  "Inflyratech reserves the right to modify these chilli terms at its discretion. Users will be notified of significant changes, and continued use of the chilli platform constitutes acceptance of modified terms.",
            ),

            _buildSectionCard(
              "12. chilli GRIEVANCE REDRESSAL",
              content:
                  "For grievances or concerns regarding chilli, please contact our designated Grievance Officer at:\n\nEmail: info@inflyratech.site\n\nInflyratech - chilli App\n88, Kehnu, PO + PS Mandi\nFatehpur, Poonch\nJammu & Kashmir, India - 185102\n\nAll chilli-related grievances will be addressed within 15 business days of receipt.",
            ),

            const SizedBox(height: 20),
            _buildFooter(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
