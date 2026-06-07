import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chilli/theme/palette.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/services/firestore_repo.dart';
import 'package:chilli/services/media_uploader.dart';
import 'package:chilli/utils/avatar_store.dart';
import 'package:chilli/services/presence_repo.dart'; // ✅ Added Import
import 'package:chilli/screens/auth_screen.dart';
import 'package:chilli/screens/call_log_screen.dart';
import 'dart:async';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/models/profile.dart'; // ✅ Added Import
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:chilli/legal/privacy_screen.dart';
import 'package:chilli/legal/terms_screen.dart';
import 'package:chilli/legal/refund_screen.dart';
import 'package:chilli/widgets/genz_dialog.dart'; // ✅ Added GenZDialog
import 'package:chilli/legal/restrictions_screen.dart';
import 'package:chilli/screens/support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final IdentityManager _AuthenticationService = IdentityManager();
  final FirestoreRepo _CloudDatabaseService = FirestoreRepo();
  final MediaUploader _CloudStorageService = MediaUploader();
  final PresenceRepo _rtdbService = PresenceRepo(); // ✅ Added Service

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isLoggingOut = false;
  bool isUpdatingProfile = false;
  num localCoins = 0;
  StreamSubscription<num>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _setupTokenListener();
  }

  void _setupTokenListener() {
    _tokenSubscription = DataBridge.tokenStream.listen((coins) {
      if (mounted) {
        setState(() {
          localCoins = coins;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final coins = await DataBridge().getLocalCoins();

      // Refresh from Firestore
      await _AuthenticationService.updateData();
      final data = await _AuthenticationService.getUserData();

      if (mounted) {
        setState(() {
          userData = data;
          localCoins = coins;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateProfile({
    String? name,
    String? gender,
    String? avatarUrl,
  }) async {
    setState(() => isUpdatingProfile = true);
    try {
      await _CloudDatabaseService.updateUserProfile(
        username: name,
        gender: gender,
        avatarUrl: avatarUrl,
      );
      await _loadUserData();
      _showSnackBar('Profile updated!', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to update: $e', Colors.red);
    } finally {
      setState(() => isUpdatingProfile = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        // imageQuality: 70, // Replaced by manual compression
      );

      if (image != null) {
        final File rawFile = File(image.path);

        // 1. 🛡️ Check for Sexual/Inappropriate Content
        bool isSafe = await _checkImageSafety(rawFile);
        if (!isSafe) {
          if (mounted) {
            _showSnackBar(
              '⚠️ Image contains inappropriate content',
              Colors.red,
            );
          }
          return;
        }

        // 2. 👤 Check if image contains a face
        bool hasFace = await _checkForFace(rawFile);
        if (!hasFace) {
          if (mounted) {
            _showSnackBar(
              '⚠️ Please upload a photo with your face visible',
              Colors.orange,
            );
          }
          return;
        }

        setState(() => isUpdatingProfile = true);
        final uid = userData?['uid'] ?? _AuthenticationService.currentUser?.uid;
        if (uid == null) {
          debugPrint('❌ Error: User ID is null');
          _showSnackBar('Error: User not found', Colors.red);
          setState(() => isUpdatingProfile = false);
          return;
        }

        debugPrint('📤 Starting image upload for user: $uid');

        // 3. 📉 Compress Image (Low Quality)
        File? compressedFile = await _compressImage(rawFile);
        final File fileToUpload = compressedFile ?? rawFile;

        debugPrint('📤 Uploading image to Firebase Storage...');
        final url = await _CloudStorageService.uploadProfileImage(
          uid,
          fileToUpload,
        );

        if (url != null) {
          debugPrint('✅ Image uploaded successfully: $url');
          await _updateProfile(avatarUrl: url);
        } else {
          debugPrint('❌ Image upload failed - URL is null');
          _showSnackBar('Image upload failed', Colors.red);
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _pickAndUploadImage: $e');
      _showSnackBar('Error picking image: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => isUpdatingProfile = false);
      }
    }
  }

  // ✅ Generate Random Avatar (Virtual Image)
  Future<void> _generateRandomAvatar() async {
    setState(() => isUpdatingProfile = true);
    try {
      final gender = userData?['gender']?.toString().toLowerCase() ?? 'male';

      // Generate random Pinterest avatar
      final avatarUrl = AvatarStore.getRandomAvatar(gender);

      // 1. Update UI Local State
      setState(() {
        if (userData != null) {
          userData!['avatarUrl'] = avatarUrl;
        }
      });

      // 2. Update Local Cache
      await _AuthenticationService.updateLocalData({'avatarUrl': avatarUrl});

      // 3. Sync to RTDB
      if (userData != null) {
        // Create a temporary model to sync.
        // Pass explicit avatarUrl to ensure it overrides any map data.
        final updatedUserData = Profile.fromMap(
          userData!,
        ).copyWith(avatarUrl: avatarUrl);
        await _rtdbService.syncUserProfile(updatedUserData);
      }

      _showSnackBar('New avatar generated!', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to generate avatar: $e', Colors.red);
    } finally {
      setState(() => isUpdatingProfile = false);
    }
  }

  Future<bool> _checkImageSafety(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final ImageLabelerOptions options = ImageLabelerOptions(
        confidenceThreshold: 0.6,
      );
      final imageLabeler = ImageLabeler(options: options);
      final List<ImageLabel> labels = await imageLabeler.processImage(
        inputImage,
      );

      final List<String> restrictedLabels = [
        'Swimwear',
        'Undergarment',
        'Lingerie',
        'Bikini',
        'Bra',
        'Underwear',
        'Nude',
        'Nudity',
        'Pornography',
        'Erotic',
        'Sensual',
        'Intimate',
        'Buttocks',
        'Barechested',
      ];

      for (ImageLabel label in labels) {
        if (restrictedLabels.contains(label.label)) {
          imageLabeler.close();
          return false;
        }
      }
      imageLabeler.close();
      return true;
    } catch (e) {
      debugPrint('Error checking image safety: $e');
      return true;
    }
  }

  Future<bool> _checkForFace(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final FaceDetector faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableClassification: false,
          enableLandmarks: false,
          enableTracking: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      final List<Face> faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      // Return true if at least one face is detected
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Error detecting face: $e');
      return true; // Allow if check fails to avoid blocking users
    }
  }

  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${const Uuid().v4()}_compressed.jpg';

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 50,
        minWidth: 512,
        minHeight: 512,
      );

      if (result != null) {
        return File(result.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file;
    }
  }

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

    // Check if username contains only numbers
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
      return 'Username cannot contain only numbers';
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

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(
      text: userData?['username'] ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => GenZDialog(
        title: 'EDIT IDENTITY',
        message: 'Update your display name across the Nurxian network.',
        type: GenZDialogType.info,
        customContent: TextField(
          controller: nameController,
          style: const TextStyle(color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            labelText: 'New Name',
            labelStyle: TextStyle(color: const Color(0xFF1E293B).withOpacity(0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: const Color(0xFF1E293B).withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE11D48)),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
          ),
        ),
        primaryButtonText: 'SAVE CHANGES',
        secondaryButtonText: 'CANCEL',
        onSecondaryPressed: () => Navigator.pop(context),
        onPrimaryPressed: () {
          final newName = nameController.text.trim();
          Navigator.pop(context);

          // Validate username with comprehensive checks
          final usernameError = _validateUsername(newName);
          if (usernameError != null) {
            _showSnackBar('⚠️ $usernameError', Colors.red);
          } else {
            _updateProfile(name: newName);
          }
        },
      ),
    );
  }

  Future<void> _shareApp() async {
    try {
      HapticFeedback.mediumImpact();
      const String message = '''
🎥 Hey! Check out chilli - Video Chat App! 

📱 Connect with people through video & audio calls
💬 Meet new friends from around the world
🎁 Get FREE coins to start calling!

Download now: https://play.google.com/store/apps/details?id=com.nurxian.chilli

Join me on chilli! 🚀
''';
      await Share.share(message, subject: 'chilli - Talk with experts');
    } catch (e) {
      _showSnackBar('Could not share app', Colors.red);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GenZDialog(
        title: 'DISCONNECT NODE?',
        message:
            'Are you sure you want to log out and terminate your current session on this device?',
        type: GenZDialogType.error, // Red glow for destructive action
        primaryButtonText: 'LOGOUT',
        secondaryButtonText: 'CANCEL',
        onSecondaryPressed: () => Navigator.pop(context, false),
        onPrimaryPressed: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;
    setState(() => isLoggingOut = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _AuthenticationService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) setState(() => isLoggingOut = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white, // 70% White theme
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF1E293B),
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Color(0xFF1E293B),
                        size: 24,
                      ),
                      onPressed: _shareApp,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Profile Section
              _buildProfileSection(),

              const SizedBox(height: 32),

              // Settings / Preferences
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernMenuSection(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final avatarUrl = userData?['avatarUrl'];
    final name = userData?['username'] ?? 'User';
    final gender = userData?['gender'] ?? 'Not set';

    return Column(
      children: [
        // Avatar with concentric neon rings
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring (Accent)
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            // Inner Ring (Secondary)
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E293B), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            // Profile Image
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF8FAFC),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  (avatarUrl != null &&
                      avatarUrl.isNotEmpty &&
                      avatarUrl.startsWith('http'))
                  ? Image.network(avatarUrl, fit: BoxFit.cover)
                  : const Icon(
                      Icons.person,
                      size: 80,
                      color: Color(0xFF1E293B),
                    ),
            ),
            // Edit Button (Cyan glowing)
            Positioned(
              bottom: 0,
              right: 15,
              child: GestureDetector(
                onTap: isUpdatingProfile ? null : _pickAndUploadImage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48), // Accent
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),

        if (isUpdatingProfile)
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFFE11D48),
                strokeWidth: 2.5,
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: _showEditNameDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Stats Card (Unified)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white, // Light card color
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E293B).withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gender Stat
                _buildStatColumn(
                  icon: gender.toLowerCase() == 'male'
                      ? Icons.male
                      : Icons.female,
                  iconColor: const Color(0xFFE11D48), // Accent
                  title: gender.toUpperCase(),
                  subtitle: 'GENDER',
                ),
                // Divider
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                ),
                // Coins Stat
                _buildStatColumn(
                  icon: Icons.toll_rounded, // Better coin icon
                  iconColor: const Color(0xFFFBBF24), // Yellow/Gold
                  title: '$localCoins',
                  subtitle: 'COINS',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Secondary Action (Shuffle Avatar)
        // Adding it here as a small text button since it wasn't in the design, but we want to keep functionality.
        TextButton.icon(
          onPressed: isUpdatingProfile ? null : _generateRandomAvatar,
          icon: const Icon(
            Icons.shuffle_rounded,
            color: Color(0xFF1E293B),
            size: 18,
          ),
          label: const Text(
            'Shuffle Avatar',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildModernMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'SYSTEM PREFERENCES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: const Color(0xFF1E293B).withValues(alpha: 0.5),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1E293B).withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildModernMenuItem(
                icon: Icons.history_rounded,
                title: 'Call History',
                subtitle: 'View your call logs',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CallLogScreen()),
                  );
                },
              ),
              _buildDivider(),
              _buildModernMenuItem(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy terms',
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  );
                },
              ),
              _buildDivider(),
              _buildModernMenuItem(
                icon: Icons.description_rounded,
                title: 'Terms & Conditions',
                subtitle: 'View terms of service',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  );
                },
              ),
              _buildDivider(),
              _buildModernMenuItem(
                icon: Icons.money_off_rounded,
                title: 'Refund Policy',
                subtitle: 'View refund terms',
                color: const Color(0xFFA855F7),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RefundScreen(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildModernMenuItem(
                icon: Icons.security_rounded,
                title: 'App Restrictions',
                subtitle: 'Community guidelines',
                color: const Color(0xFFF43F5E),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RestrictionsScreen()),
                  );
                },
              ),
              _buildDivider(),
              _buildModernMenuItem(
                icon: Icons.star_rounded,
                title: 'Rate Us',
                subtitle: 'Share your feedback',
                color: const Color(0xFFFFD700),
                onTap: () => _launchURL(
                  'https://play.google.com/store/apps/details?id=com.nurxian.chilli',
                ),
              ),
              _buildDivider(),
              _buildModernMenuItem(
                icon: Icons.headset_mic_rounded,
                title: 'Contact Us',
                subtitle: 'Get help & support',
                color: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  );
                },
              ),
              _buildDivider(),
              _buildModernMenuItem(
                icon: Icons.share_rounded,
                title: 'Share App',
                subtitle: 'Invite your friends',
                color: const Color(0xFFEC4899),
                onTap: _shareApp,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isLast ? 16 : 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: const Color(0xFF1E293B).withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: const Color(0xFF1E293B).withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isLoggingOut ? null : _handleLogout,
        icon: const Icon(Icons.logout_rounded, color: Colors.white),
        label: Text(
          isLoggingOut ? 'Logging out...' : 'Logout',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}


