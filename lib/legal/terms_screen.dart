import 'dart:ui';
import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  Widget _buildSection({
    required String number,
    required String title,
    String? content,
    List<String>? bulletPoints,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8B5CF6), // Purple accent
                  fontFamily: 'Courier',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (content != null || bulletPoints != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
          ],
          if (content != null)
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          if (bulletPoints != null)
            ...bulletPoints.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0, right: 12.0),
                        child: Icon(
                          Icons.arrow_right_alt_rounded,
                          color: Color(0xFFEC4899), // Pink accent
                          size: 16,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          point,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4F46E5), // Indigo
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE11D48), // Rose
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
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
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        const Text(
                          'The Rules 📜',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "By accessing or using the chilli app, you agree to be bound by these Terms of Use. If you do not agree, discontinue use of chilli immediately.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),

                        _buildSection(
                          number: '01',
                          title: 'PURPOSE OF chilli',
                          content:
                              "chilli is designed to facilitate meaningful social interactions through a secure and moderated environment. We provide a space where Users can engage with verified Hosts in constructive conversations while maintaining the highest standards of safety and professionalism on the chilli platform.",
                        ),

                        _buildSection(
                          number: '02',
                          title: 'ACCEPTABLE USER CONDUCT',
                          bulletPoints: [
                            "Users must maintain professional decorum and exhibit courteous behavior at all times on chilli",
                            "Respect intellectual property rights and confidentiality obligations within chilli",
                            "Adhere to chilli platform guidelines and community standards",
                          ],
                        ),

                        _buildSection(
                          number: '03',
                          title: 'PROHIBITED CONDUCT',
                          bulletPoints: [
                            "Any form of harassment, intimidation, or threatening behavior on chilli",
                            "Hate speech, discrimination, or content that promotes prejudice within chilli",
                            "Unauthorized commercial solicitation or promotional activities on chilli",
                            "Distribution of malicious content or attempts to compromise chilli platform security",
                          ],
                        ),

                        _buildSection(
                          number: '04',
                          title: 'PRIVACY & DATA PROTECTION',
                          bulletPoints: [
                            "Strict adherence to data protection regulations and privacy laws for chilli users",
                            "Prohibition of unauthorized recording, sharing, or distribution of chilli content",
                            "Mandatory compliance with chilli's privacy policy and security protocols",
                          ],
                        ),

                        _buildSection(
                          number: '05',
                          title: 'PLATFORM SAFETY',
                          bulletPoints: [
                            "Zero-tolerance policy for exploitation or harmful content on chilli",
                            "Advanced monitoring systems for chilli user protection",
                            "Immediate action on safety violations and legal compliance within chilli",
                          ],
                        ),

                        _buildSection(
                          number: '06',
                          title: 'VIRTUAL CURRENCY',
                          bulletPoints: [
                            "All virtual currency transactions within chilli are final and non-refundable",
                            "Virtual currency in chilli holds no real-world monetary value",
                            "Compliance with applicable financial regulations and chilli policies",
                          ],
                        ),

                        _buildSection(
                          number: '07',
                          title: 'CONTENT GUIDELINES',
                          bulletPoints: [
                            "All content on chilli must comply with applicable laws and regulations",
                            "Strict adherence to intellectual property rights within chilli",
                            "Professional and constructive communication standards on chilli",
                          ],
                        ),

                        _buildSection(
                          number: '08',
                          title: 'MODERATION',
                          bulletPoints: [
                            "Systematic review and moderation of reported violations on chilli",
                            "Transparent investigation procedures for chilli violations",
                            "Graduated response system for chilli policy violations",
                          ],
                        ),

                        _buildSection(
                          number: '09',
                          title: 'USER ACCOUNTABILITY',
                          bulletPoints: [
                            "Users bear full responsibility for their activities on chilli",
                            "Compliance with terms is mandatory for continued chilli access",
                            "Legal liability for violation of chilli terms or applicable laws",
                          ],
                        ),

                        _buildSection(
                          number: '10',
                          title: 'LIABILITY LIMITATIONS',
                          bulletPoints: [
                            "chilli service provided on an 'as is' and 'as available' basis",
                            "No warranties regarding chilli service reliability or outcomes",
                            "Limited liability as permitted by applicable law for chilli services",
                          ],
                        ),

                        _buildSection(
                          number: '11',
                          title: 'TERMS MODIFICATION',
                          content:
                              "nurxian reserves the right to modify these chilli terms at its discretion. Users will be notified of significant changes, and continued use of the chilli platform constitutes acceptance of modified terms.",
                        ),

                        _buildSection(
                          number: '12',
                          title: 'GRIEVANCE REDRESSAL',
                          content:
                              "For grievances or concerns regarding chilli, please contact our designated Grievance Officer at:\n\nEmail: info@nurxian.site\n\nnurxian - chilli App\n88, Kehnu, PO + PS Mandi\nFatehpur, Poonch\nJammu & Kashmir, India - 185102\n\nAll chilli-related grievances will be addressed within 15 business days of receipt.",
                        ),

                        // Footer
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Note: These Terms of Use for chilli are guidelines and do not replace or supersede any legal obligations or requirements as outlined in relevant laws, including the Indian Penal Code.",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white.withOpacity(0.5),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white12),
                              const SizedBox(height: 16),
                              const Text(
                                '© nurxian - chilli App. All rights reserved.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This app is owned and operated by nurxian PRIVATE LIMITED.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
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

