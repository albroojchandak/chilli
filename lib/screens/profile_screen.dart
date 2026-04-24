import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/services/firestore_repo.dart';
import 'package:chilli/services/media_uploader.dart';
import 'package:chilli/services/presence_repo.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/utils/avatar_store.dart';
import 'package:chilli/screens/auth_screen.dart';
import 'package:chilli/legal/privacy_screen.dart';
import 'package:chilli/legal/terms_screen.dart';
import 'package:chilli/legal/refund_screen.dart';
import 'package:chilli/screens/support_screen.dart';
import 'package:chilli/models/profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _identity = IdentityManager();
  final _firestore = FirestoreRepository();
  final _media = MediaUploader();
  final _presence = PresenceRepository();

  Map<String, dynamic>? _profile;
  num _coins = 0;
  bool _isLoading = true;
  bool _isUpdating = false;

  late final AnimationController _meshController;
  late final AnimationController _floatController;

  static const Color _bgDark = Color(0xFF090412);
  static const Color _primaryNeon = Color(0xFF00E5FF);
  static const Color _secondaryNeon = Color(0xFFFF007F);
  static const Color _accentViolet = Color(0xFF7000FF);
  static const Color _surfaceGlass = Color(0x0FBAAFFF);

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _meshController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final c = await DataBridge().getLocalCoins();
    await _identity.refreshFromRemote();
    final p = await _identity.loadProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _coins = c;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAvatar() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Avatar Vault...')));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAvatarSelectionSheet(),
    );
  }

  Future<void> _pickFromGallery() async {
    Navigator.pop(context);
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isUpdating = true);
    try {
      final url = await _media.uploadAvatar(_profile?['uid'] ?? '', File(image.path));
      if (url != null) {
        await _firestore.patchProfile(avatarUrl: url);
        if (_profile?['uid'] != null) {
          await _presence.patchFields(_profile!['uid'], {'avatarUrl': url});
        }
        await _identity.patchLocalProfile({'avatarUrl': url, 'a': url});
        _loadData();
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _selectPredefined(String url) async {
    Navigator.pop(context);
    setState(() => _isUpdating = true);
    try {
      await _firestore.patchProfile(avatarUrl: url);
      if (_profile?['uid'] != null) {
        await _presence.patchFields(_profile!['uid'], {'avatarUrl': url});
      }
      await _identity.patchLocalProfile({'avatarUrl': url, 'a': url});
      _loadData();
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Widget _buildAvatarSelectionSheet() {
    final gender = (_profile?['gender'] ?? 'female').toString().toLowerCase();
    final avatars = gender == 'male' ? AvatarVault.maleAvatars : AvatarVault.femaleAvatars;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryNeon.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Text(
                      'CHOOSE IDENTITY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildUploadOption(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'PRESET PROTOCOLS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryNeon.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        gender.toUpperCase(),
                        style: const TextStyle(color: _primaryNeon, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: avatars.length,
                  itemBuilder: (context, index) {
                    final url = avatars[index];
                    final isSelected = _profile?['avatarUrl'] == url;
                    return GestureDetector(
                      onTap: () => _selectPredefined(url),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? _primaryNeon : Colors.white.withOpacity(0.05),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              Image.network(
                                url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.white.withOpacity(0.02),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value: progress.expectedTotalBytes != null 
                                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! 
                                            : null,
                                          color: _primaryNeon.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (isSelected)
                                Container(
                                  color: _primaryNeon.withOpacity(0.3),
                                  child: const Center(
                                    child: Icon(Icons.check_circle, color: Colors.white, size: 32),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: _pickFromGallery,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _primaryNeon.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _primaryNeon.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded, color: _primaryNeon, size: 24),
              ),
              const SizedBox(width: 20),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UPLOAD CUSTOM',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                  ),
                  Text(
                    'Pick from your local storage',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.1), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _profile?['username'] ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF15082E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: _primaryNeon.withOpacity(0.2))),
          title: const Text('RENAME PROFILE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Username',
              labelStyle: const TextStyle(color: _primaryNeon),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _primaryNeon.withOpacity(0.3))),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _primaryNeon)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
            TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('SAVE', style: TextStyle(color: _primaryNeon, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _profile?['username']) {
      setState(() => _isUpdating = true);
      try {
        await _firestore.patchProfile(username: newName);
        if (_profile?['uid'] != null) {
          await _presence.patchFields(_profile!['uid'], {'username': newName});
        }
        await _identity.patchLocalProfile({'username': newName, 'Name': newName});
        _loadData();
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF15082E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: _secondaryNeon, width: 0.5)),
          title: const Text('LOGOUT?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
          content: const Text('Are you sure you want to disconnect?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('LOGOUT', style: TextStyle(color: _secondaryNeon, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await _identity.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (r) => false,
        );
      }
    }
  }

  Future<void> _openBlockedManagement() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBlockedSheet(),
    );
  }

  Widget _buildBlockedSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'BLOCKED PROTOCOLS',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChilliProfile>>(
              stream: _firestore.watchBlockedUsers(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primaryNeon));
                }
                final users = snap.data ?? [];
                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.white10, size: 64),
                        const SizedBox(height: 16),
                        Text('No blocked identities found', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: users.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(users[i].avatarUrl ?? ''),
                          backgroundColor: Colors.white10,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            users[i].name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _firestore.unblockUser(users[i].uid),
                          child: const Text('UNBLOCK', style: TextStyle(color: _primaryNeon, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Ambient Background
          AnimatedBuilder(
            animation: _meshController,
            builder: (context, _) => CustomPaint(
              painter: _ProfileMeshPainter(_meshController.value),
              size: Size.infinite,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: _primaryNeon)) 
            : _buildContent(),
          if (_isUpdating)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator(color: _primaryNeon)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildImmersiveAppBar(),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildStatsCard(),
              const SizedBox(height: 48),
              _buildSectionLabel('SYSTEM PREFERENCES'),
              _buildMenuCard([
                _buildMenuItem(Icons.manage_accounts_rounded, 'Edit Profile Identity', _primaryNeon, _editName, true),
                _buildMenuItem(Icons.shield_moon_rounded, 'Privacy & Encryption', _accentViolet, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())), true),
                _buildMenuItem(Icons.block_rounded, 'Blocked Protocols', Colors.redAccent, _openBlockedManagement, true),
                _buildMenuItem(Icons.receipt_long_rounded, 'Transaction Refund Protocol', Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundScreen())), true),
                _buildMenuItem(Icons.assignment_rounded, 'Cloud Terms of Service', _secondaryNeon, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())), false),
              ]),
              const SizedBox(height: 32),
              _buildSectionLabel('NETWORK SUPPORT'),
              _buildMenuCard([
                _buildMenuItem(Icons.support_agent_rounded, 'Mainframe Help Center', _primaryNeon, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())), true),
                _buildMenuItem(Icons.delete_forever_rounded, 'Deactivate Identity', _secondaryNeon, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())), true),
                _buildMenuItem(Icons.share_rounded, 'Synchronize Friends', Colors.orangeAccent, () => Share.share('Join the network on Chilli!'), false),
              ]),
              const SizedBox(height: 64),
              _buildModernLogoutButton(),
              const SizedBox(height: 80),
              _buildVersionInfo(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildImmersiveAppBar() {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                _buildAvatarHexagon(),
                const SizedBox(height: 24),
                Text(
                  _profile?['username'] ?? 'UNIDENTIFIED',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryNeon.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: _primaryNeon.withOpacity(0.2)),
                  ),
                  child: Text(
                    (_profile?['email'] ?? 'Spice Link Established').toUpperCase(),
                    style: const TextStyle(color: _primaryNeon, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarHexagon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing Ring
        AnimatedBuilder(
          animation: _floatController,
          builder: (context, _) => Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _primaryNeon.withOpacity(0.3 * (1.1 - _floatController.value)),
                width: 2,
              ),
            ),
          ),
        ),
        // Secondary Inner Ring
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_primaryNeon.withOpacity(0.5), _accentViolet.withOpacity(0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _bgDark),
            padding: const EdgeInsets.all(4),
            child: CircleAvatar(
              radius: 65,
              backgroundColor: const Color(0xFF1A1A2E),
              child: ClipOval(
                child: (_profile?['avatarUrl'] == null || _profile!['avatarUrl'].toString().isEmpty)
                ? const Icon(Icons.person_rounded, size: 60, color: _primaryNeon)
                : Image.network(
                    _profile!['avatarUrl'],
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_rounded, size: 60, color: _primaryNeon),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null 
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! 
                            : null,
                          color: _primaryNeon.withOpacity(0.5),
                        ),
                      );
                    },
                  ),
              ),
            ),
          ),
        ),
        // Edit Badge
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: _updateAvatar,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryNeon,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _primaryNeon.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)],
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.black, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('REPUTATION', 'EXPLORER', Icons.verified_user_rounded, _primaryNeon),
                _buildStatDivider(),
                _buildStatItem('COINS', _coins.toStringAsFixed(0), Icons.toll_rounded, Colors.amberAccent),
                _buildStatDivider(),
                _buildStatItem('NETWORK', 'LVL 12', Icons.hub_rounded, _accentViolet),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 40, width: 1, color: Colors.white.withOpacity(0.08));
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color color, VoidCallback onTap, bool showBorder) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            border: showBorder ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2))),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.15), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: _secondaryNeon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _secondaryNeon.withOpacity(0.2)),
        ),
        child: const Center(
          child: Text(
            'DISCONNECT IDENTITY',
            style: TextStyle(color: _secondaryNeon, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Column(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/logo.png',
              height: 20,
              width: 20,
              color: Colors.white.withOpacity(0.1),
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'CHILLI OS v2.4.0-STABLE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMeshPainter extends CustomPainter {
  final double progress;
  _ProfileMeshPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    void drawGlow(Offset center, Color color, double radius) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final ox1 = cx + math.cos(progress * math.pi * 2) * 120;
    final oy1 = cy - 200 + math.sin(progress * math.pi * 2) * 100;

    final ox2 = cx + math.cos((progress + 0.5) * math.pi * 2) * -140;
    final oy2 = cy + 100 + math.sin((progress + 0.5) * math.pi * 2) * 150;

    drawGlow(Offset(ox1, oy1), const Color(0xFF00E5FF), 350);
    drawGlow(Offset(ox2, oy2), const Color(0xFFFF007F), 400);
  }

  @override
  bool shouldRepaint(_ProfileMeshPainter old) => true;
}
