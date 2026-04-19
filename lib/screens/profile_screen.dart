import 'dart:async';
import 'dart:io';
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
import 'package:chilli/services/presence_repo.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/screens/auth_screen.dart';
import 'package:chilli/legal/privacy_screen.dart';
import 'package:chilli/legal/terms_screen.dart';
import 'package:chilli/screens/support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _identity = IdentityManager();
  final _firestore = FirestoreRepository();
  final _media = MediaUploader();
  final _presence = PresenceRepository();

  Map<String, dynamic>? _profile;
  num _coins = 0;
  bool _isLoading = true;
  bool _isUpdating = false;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);
  static const _surface = Color(0xFF1A1030);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final c = await DataBridge().getLocalCoins();
    await _identity.refreshFromRemote();
    final p = await _identity.loadProfile();
    if (mounted) setState(() { _profile = p; _coins = c; _isLoading = false; });
  }

  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isUpdating = true);
    try {
      final url = await _media.uploadAvatar(_profile?['uid'] ?? '', File(image.path));
      if (url != null) {
        await _firestore.patchProfile(avatarUrl: url);
        _loadData();
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _profile?['username'] ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('RENAME PROFILE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: const TextStyle(color: _neonCyan),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _neonCyan.withOpacity(0.3))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _neonCyan)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: const Text('SAVE', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _profile?['username']) {
      setState(() => _isUpdating = true);
      try {
        await _firestore.patchProfile(username: newName);
        await _presence.patchFields(_profile!['uid'], {'username': newName});
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
      builder: (c) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('LOGOUT?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to spice out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('LOGOUT', style: TextStyle(color: _neonPink, fontWeight: FontWeight.w900))),
        ],
      ),
    );

    if (confirm == true) {
      await _identity.logout();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: _neonCyan)) : _buildBody(),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildStatsBar(),
                const SizedBox(height: 32),
                _buildMenuSection('ACCOUNT SETTINGS', [
                  _buildMenuItem(Icons.person_outline_rounded, 'Edit Profile', _neonCyan, _editName),
                  _buildMenuItem(Icons.security_rounded, 'Privacy Policy', _neonViolet, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
                  _buildMenuItem(Icons.description_outlined, 'Terms of Service', _neonPink, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()))),
                ]),
                const SizedBox(height: 24),
                _buildMenuSection('SUPPORT', [
                  _buildMenuItem(Icons.headset_mic_outlined, 'Help Center', _neonCyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()))),
                  _buildMenuItem(Icons.share_outlined, 'Invite Friends', Colors.amber, () => Share.share('Join me on Chilli!')),
                ]),
                const SizedBox(height: 40),
                _buildLogoutButton(),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: _bg,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_neonViolet.withOpacity(0.2), Colors.transparent]))),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAvatarStack(),
                const SizedBox(height: 16),
                Text(_profile?['username'] ?? 'CHILLI USER', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text(_profile?['email'] ?? 'Spice Explorer', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarStack() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonCyan.withOpacity(0.5), width: 2)),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: _surface,
            backgroundImage: _profile?['avatarUrl'] != null ? NetworkImage(_profile!['avatarUrl']) : null,
            child: _profile?['avatarUrl'] == null ? const Icon(Icons.person_rounded, size: 60, color: _neonCyan) : null,
          ),
        ),
        GestureDetector(
          onTap: _updateAvatar,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: _neonCyan, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('COINS', _coins.toStringAsFixed(0), Icons.toll_rounded, Colors.amber),
          _buildVerticalDivider(),
          _buildStatItem('LEVEL', '12', Icons.auto_awesome_rounded, _neonViolet),
          _buildVerticalDivider(),
          _buildStatItem('STREAK', '5d', Icons.whatshot_rounded, _neonPink),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.white.withOpacity(0.05));
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(title, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ),
        Container(
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: _neonPink.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: _neonPink.withOpacity(0.3))),
        child: const Center(child: Text('LOGOUT OF CHILLI', style: TextStyle(color: _neonPink, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
      ),
    );
  }
}
