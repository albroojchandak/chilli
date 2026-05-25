import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chilli/pages/language_select_page.dart';

import 'dart:math';

class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({super.key});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  String? selectedGender;
  String? selectedAvatar;
  bool genderVerified = false; // ✅ Track verification status
  bool _isUploadingAudio = false; // Stub for removed upload logic

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Female Avatars - Real Images
  final List<String> femaleAvatars = [
    'https://i.pinimg.com/736x/20/d5/96/20d5961e97bf5cd9302f24f8ed02f9dd.jpg',
    'https://i.pinimg.com/736x/09/9d/56/099d5648fc30c473a2d01b93abc7852f.jpg',
    'https://i.pinimg.com/736x/74/21/65/7421654187e6c578a242b9489ebd2846.jpg',
    'https://i.pinimg.com/736x/00/43/fe/0043fec2b32e9fc5d3d074211e5b295b.jpg',
    'https://i.pinimg.com/736x/7c/c6/fa/7cc6fa9d0496cf66bb46ea1219a8ef34.jpg',
    'https://i.pinimg.com/736x/ce/70/98/ce709855596e0d769465d6432e123211.jpg',
    'https://i.pinimg.com/736x/70/18/3d/70183dd58c5d02108a91b752c0deb144.jpg',
    'https://i.pinimg.com/736x/0e/3b/5e/0e3b5e6499d0588443275c36b261b89f.jpg',
    'https://i.pinimg.com/736x/5f/95/32/5f9532d978e371c9435bf9e36eb69521.jpg',
    'https://i.pinimg.com/736x/cb/27/99/cb27994dec2da3297c3ff3612d0d113a.jpg',
    'https://i.pinimg.com/736x/1e/4c/d5/1e4cd5ee9b23b5de1621a63ef6b0a079.jpg',
    'https://i.pinimg.com/736x/56/c9/db/56c9db6cb079be4a3d6dce3f659e1f42.jpg',
    'https://i.pinimg.com/736x/17/71/47/177147f021ff3f2bb8cdbb1964141e81.jpg',
    'https://i.pinimg.com/736x/56/3e/dd/563eddb9ad70712e2750c21a71c581b3.jpg',
    'https://i.pinimg.com/736x/d7/09/9e/d7099e50a7fb17776c9fb6ce9e36f88c.jpg',
    'https://i.pinimg.com/736x/c4/8e/60/c48e6019d0a3202f371f8ea7db0894d1.jpg',
    'https://i.pinimg.com/736x/cb/19/d3/cb19d35b0b7d9449e88a13d389f8df4b.jpg',
    'https://i.pinimg.com/736x/8e/d3/29/8ed32941147163547b642c97fc258953.jpg',
    'https://i.pinimg.com/736x/5e/16/58/5e1658cd568eb89c0e70baa1a4e0374e.jpg',
    'https://i.pinimg.com/736x/59/59/f7/5959f7aa8834263ee2f90a772ba95a7d.jpg',
    'https://i.pinimg.com/736x/cd/bc/c0/cdbcc034eac2d6c1b833a38241f465d5.jpg',
    'https://i.pinimg.com/736x/94/7c/94/947c94886264255a4eb4920a69b5e216.jpg',
  ];

  // Male Avatars - Real Images
  final List<String> maleAvatars = [
    'https://i.pinimg.com/736x/9a/69/7b/9a697b75243f2e5b26249a186b6a7bba.jpg',
    'https://i.pinimg.com/736x/48/69/fe/4869fe89335aeb7c56ee584d9dcf71bc.jpg',
    'https://i.pinimg.com/736x/de/95/7c/de957cc48278b1232696cac393a7c82f.jpg',
    'https://i.pinimg.com/736x/b6/9b/62/b69b62ca92e54d5a78e22f774776226e.jpg',
    'https://i.pinimg.com/736x/9b/92/c9/9b92c9cbddb0a14b9988cd1146be2ed4.jpg',
    'https://i.pinimg.com/736x/aa/87/6e/aa876e4af34c75ffa37697f77e93ee1c.jpg',
    'https://i.pinimg.com/736x/e2/a9/17/e2a91713579274a0e593dafe93ae349e.jpg',
    'https://i.pinimg.com/736x/06/66/bf/0666bf9cb2f145b5883fb5d4cf14e772.jpg',
    'https://i.pinimg.com/736x/f9/58/74/f9587460511c012e184b2342b4addf33.jpg',
    'https://i.pinimg.com/736x/ef/48/3c/ef483c80c860c3709723ab09bb5de6d9.jpg',
    'https://i.pinimg.com/736x/61/73/63/61736376e4b951553d753dba03afca7d.jpg',
    'https://i.pinimg.com/736x/d3/9c/4a/d39c4a0bf5ffd678d642b07a6e26b4f8.jpg',
    'https://i.pinimg.com/736x/b6/c8/a8/b6c8a8e6115b1e2e57cf7201a4faf1bd.jpg',
    'https://i.pinimg.com/736x/a4/3c/b8/a43cb823c5b0a537eda9fd1c3879981f.jpg',
    'https://i.pinimg.com/736x/a5/9d/b7/a59db7742f98ddde83187ec1a4596054.jpg',
    'https://i.pinimg.com/736x/e6/b0/ca/e6b0cafae602bdddc2f29999474f4513.jpg',
    'https://i.pinimg.com/736x/1a/07/15/1a0715710055287d1cb7054b88fcc33f.jpg',
    'https://i.pinimg.com/736x/78/86/c1/7886c1775799af92aa652347413a4534.jpg',
    'https://i.pinimg.com/736x/5e/18/d8/5e18d8aea4a82866a3aad2d6bb0ed173.jpg',
  ];

  List<String> get currentAvatars {
    if (selectedGender == 'Male') return maleAvatars;
    if (selectedGender == 'Female') return femaleAvatars;
    return [...maleAvatars.take(5), ...femaleAvatars.take(5)];
  }

  // Avatars are selected automatically in the background when gender is selected

  String? _validateUsername(String text) {
    final String lowerText = text.toLowerCase().trim();

    // Check if username is empty
    if (lowerText.isEmpty) {
      return 'Username cannot be empty';
    }

    // Check if username is too short
    if (lowerText.length < 3) {
      return 'Username must be at least 3 characters';
    }

    // Check if username contains any numbers
    if (RegExp(r'[0-9]').hasMatch(text)) {
      return 'Username cannot contain numbers';
    }

    // Check for phone numbers (various formats)
    if (RegExp(
      r'\d{10}|\d{3}[-.\s]?\d{3}[-.\s]?\d{4}|\+\d{10,}',
    ).hasMatch(text)) {
      return 'Username cannot contain phone numbers';
    }

    // Check for WhatsApp mentions
    final List<String> whatsappKeywords = [
      'whatsapp',
      'whatsap',
      'watsapp',
      'watsap',
      'wa.me',
      'chat.whatsapp',
    ];
    for (String keyword in whatsappKeywords) {
      if (lowerText.contains(keyword)) {
        return 'Username cannot contain WhatsApp references';
      }
    }

    // Check for Instagram mentions
    final List<String> instagramKeywords = [
      'instagram',
      'insta',
      'ig:',
      '@',
      'follow me',
      'dm me',
    ];
    for (String keyword in instagramKeywords) {
      if (lowerText.contains(keyword)) {
        return 'Username cannot contain social media references';
      }
    }

    // Check for other social media/contact keywords
    final List<String> contactKeywords = [
      'telegram',
      'snapchat',
      'snap',
      'facebook',
      'twitter',
      'tiktok',
      'call me',
      'text me',
      'message me',
      'contact',
      'number',
    ];
    for (String keyword in contactKeywords) {
      if (lowerText.contains(keyword)) {
        return 'Username cannot contain contact information';
      }
    }

    // 🤬 Bad Words List
    final List<String> badWords = [
      'sex',
      'porn',
      'xxx',
      'nude',
      'naked',
      'fuck',
      'shit',
      'ass',
      'bitch',
      'bastard',
      'damn',
      'dick',
      'pussy',
      'whore',
      'slut',
      'cock',
      'cunt',
      'nigger',
      'nigga',
      'faggot',
      'rape',
      'kill',
      'death',
      'suicide',
    ];

    for (String word in badWords) {
      if (lowerText.contains(word)) {
        return 'Username contains inappropriate language';
      }
    }

    return null; // Valid username
  }

  // ❌ Removed _buildAudioRecorder and _buildProfileAvatar (now using _buildAvatarSection)

  Widget _buildGlowingOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size / 2, spreadRadius: size / 2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isSmallDevice = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark GenZ background
      body: Stack(
        children: [
          // Ambient Background Glows
          Positioned(
            top: -150,
            left: -100,
            child: _buildGlowingOrb(450, const Color(0xFF8B5CF6).withOpacity(0.12)),
          ),
          Positioned(
            bottom: -200,
            right: -100,
            child: _buildGlowingOrb(500, const Color(0xFF06B6D4).withOpacity(0.12)),
          ),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildModernHeader(isSmallDevice)),
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.6), // Dark Glass
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 10)),
                            BoxShadow(color: const Color(0xFF06B6D4).withOpacity(0.05), blurRadius: 30, spreadRadius: -5),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step 1: Gender Selection
                              _buildStepCard(
                                stepNumber: 1,
                                title: 'Select Gender',
                                isCompleted: genderVerified,
                                child: _buildGenderSection(),
                              ),
                              const SizedBox(height: 24),
                              // Step 2: Username
                              _buildStepCard(
                                stepNumber: 2,
                                title: 'Enter Username',
                                isCompleted: _nameController.text.isNotEmpty,
                                child: _buildUsernameSection(),
                              ),
                              const SizedBox(height: 40),
                              _buildContinueButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(bool isSmall) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                ),
                child: const Icon(Icons.person_add_rounded, color: Color(0xFF06B6D4), size: 28),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF8B5CF6), size: 18),
                    const SizedBox(width: 6),
                    Text('2 Steps', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'Create Your\nProfile',
              style: TextStyle(
                fontSize: isSmall ? 32 : 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s get to know you better.',
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({required int stepNumber, required String title, required bool isCompleted, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: isCompleted ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]) : null,
                color: isCompleted ? null : const Color(0xFF14141E),
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? Colors.transparent : Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text('$stepNumber', style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.white : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildGenderSection() {
    return Row(
      children: [
        Expanded(child: _buildModernGenderCard('Male', Icons.male_rounded)),
        const SizedBox(width: 16),
        Expanded(child: _buildModernGenderCard('Female', Icons.female_rounded)),
      ],
    );
  }

  Widget _buildModernGenderCard(String gender, IconData icon) {
    final isSelected = selectedGender == gender;
    final isMale = gender == 'Male';
    
    // GenZ vibrant gradient styles
    final activeGradient = isMale
        ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]) // Blue to Cyan
        : const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]); // Pink to Purple

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedGender = gender;
          genderVerified = true;
          final random = Random();
          final list = isMale ? maleAvatars : femaleAvatars;
          if (selectedAvatar == null || !list.contains(selectedAvatar)) {
            selectedAvatar = list[random.nextInt(list.length)];
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $gender selected'),
              backgroundColor: const Color(0xFF1E293B),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isMale ? const Color(0xFF06B6D4) : const Color(0xFF8B5CF6))),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.transparent : const Color(0xFF14141E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
          gradient: isSelected ? activeGradient : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isMale ? const Color(0xFF06B6D4) : const Color(0xFF8B5CF6)).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: isSelected ? Colors.white : Colors.white.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(
              gender,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Verified', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameSection() {
    final isNotEmpty = _nameController.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14141E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNotEmpty ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: isNotEmpty
                ? [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.2),
                      blurRadius: 15,
                    )
                  ]
                : null,
          ),
          child: TextField(
            controller: _nameController,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
            ],
            onChanged: (value) => setState(() {}),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your username',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16, fontWeight: FontWeight.normal),
              prefixIcon: Icon(
                Icons.alternate_email_rounded,
                color: isNotEmpty ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.3),
              ),
              suffixIcon: isNotEmpty ? const Icon(Icons.check_circle, color: Color(0xFF06B6D4)) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '• At least 3 characters\n• No phone numbers or social media',
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), height: 1.5),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    final allCompleted = selectedAvatar != null && genderVerified && _nameController.text.isNotEmpty;

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: allCompleted ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: allCompleted ? null : const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: allCompleted ? Colors.transparent : Colors.white.withOpacity(0.1)),
        boxShadow: allCompleted
            ? [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isUploadingAudio || !allCompleted
              ? null
              : () async {
                  final usernameError = _validateUsername(_nameController.text);
                  if (usernameError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ $usernameError'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  if (selectedGender == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please select your gender'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                    return;
                  }

                  String? audioUrl;
                  String? finalAvatar = selectedAvatar;
                  if (finalAvatar == null) {
                    final avatars = selectedGender?.toLowerCase() == 'male' ? maleAvatars : femaleAvatars;
                    finalAvatar = avatars[Random().nextInt(avatars.length)];
                  }

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LanguageSelectPage(
                          username: _nameController.text,
                          gender: selectedGender!,
                          avatar: finalAvatar,
                          audioUrl: audioUrl,
                        ),
                      ),
                    );
                  }
                },
          child: Center(
            child: _isUploadingAudio
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue to Next Step',
                        style: TextStyle(
                          color: allCompleted ? Colors.white : Colors.white.withOpacity(0.4),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: allCompleted ? Colors.white : Colors.white.withOpacity(0.4),
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}