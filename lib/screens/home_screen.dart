import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chilli/theme/palette.dart';
import 'dart:ui';
import 'package:chilli/widgets/user_tile.dart';
import 'package:chilli/screens/call_log_screen.dart';
import 'package:chilli/screens/wallet_screen.dart';
import 'package:chilli/screens/profile_screen.dart';
import 'package:chilli/screens/chilli_call_view.dart';
import 'package:chilli/screens/chat_screen.dart';
import 'package:chilli/services/firestore_repo.dart';
import 'package:chilli/services/push_receiver.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/services/presence_repo.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/services/build_validator.dart';
import 'package:chilli/services/review_manager.dart';
import 'package:chilli/models/profile.dart';
import 'package:chilli/utils/avatar_store.dart';
import 'package:chilli/utils/role_picker.dart';
import 'package:chilli/widgets/inbound_call.dart';
import 'package:chilli/widgets/funds_sheet.dart';

class ChilliHomeScreen extends StatefulWidget {
  const ChilliHomeScreen({super.key});

  @override
  State<ChilliHomeScreen> createState() => _ChilliHomeScreenState();
}

class _ChilliHomeScreenState extends State<ChilliHomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentTabIndex = 1;
  final _firestore = FirestoreRepository();
  final _presence = PresenceRepository();
  final _push = PushReceiver();
  final _auth = FirebaseAuth.instance;
  final _identity = IdentityManager();
  final _bridge = DataBridge();
  final _db = FirebaseDatabase.instance.ref();

  StreamSubscription? _callSub;
  StreamSubscription<num>? _coinSub;
  StreamSubscription<DocumentSnapshot>? _userSub;
  Timer? _statusTimer;

  String? _gender;
  String? _lang;
  String? _avatar;
  String? _target;
  num _coins = 0;
  bool _isActionLock = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);

  final List<String> _filters = ['All', 'English', 'Hindi', 'Tamil', 'Telugu', 'Marathi', 'Bengali'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeIn);
    
    _initApp();
    _entranceCtrl.forward();
  }

  void _initApp() async {
    BuildValidator.runVersionCheck(context);
    StoreReviewManager.evaluateAndPrompt(context);
    _setupListeners();
    _syncProfile();
    _bridge.syncCoinsWithServer();
    
    // Auto-recharge dummy balance for testing
    await _bridge.updateLocalCoins(100, isDeduction: false);
    debugPrint('HomeScreen: 100 dummy coins added for testing');
  }

  void _setupListeners() {
    _push.initialize();
    _push.onIncomingCall = (d) => Future.delayed(const Duration(milliseconds: 200), () => _handleIncomingCall(d));
    _push.onIncomingChat = (d) => Future.delayed(const Duration(milliseconds: 200), () => _handleIncomingChat(d));

    _coinSub = DataBridge.balanceStream.listen((c) => setState(() => _coins = c));
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateOnlineStatus());

    final user = _auth.currentUser;
    if (user != null) {
      _userSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snap) {
        if (snap.exists && mounted) {
          final d = snap.data()!;
          final g = d['gender']?.toString().toLowerCase();
          if (g != _gender) {
            _gender = g;
            _target = g == 'male' ? 'female' : 'male';
            setState(() {});
          }
          _lang = d['language']?.toString();
          _avatar = d['avatarUrl']?.toString();
        }
      });
    }

    _db.child('pending_calls').child(_auth.currentUser?.uid ?? '').onChildAdded.listen((e) {
      if (e.snapshot.value != null && mounted) {
        final d = Map<String, dynamic>.from(e.snapshot.value as Map);
        d['roomId'] = e.snapshot.key;
        
        final createTime = d['createdAt'] as int?;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        if (createTime != null && (now - createTime) < 60000) {
          _handleIncomingCall(d);
        } else {
          // Cleanup stale signals
          _db.child('pending_calls').child(_auth.currentUser?.uid ?? '').child(e.snapshot.key!).remove();
        }
      }
    });
  }

  Future<void> _syncProfile() async {
    await _identity.refreshFromRemote();
    final local = await _identity.loadProfile();
    if (local != null) {
      final g = local['gender']?.toString().toLowerCase() ?? 'male';
      _gender = g;
      _target = g == 'male' ? 'female' : 'male';
      _lang = local['language']?.toString();
      _avatar = local['avatarUrl']?.toString() ?? AvatarVault.resolveRandom(g);
      
      final record = ChilliProfile.fromMap(local).copyWith(
        status: 'online',
        lastActive: DateTime.now(),
        fcmToken: await _push.readToken(),
        avatarUrl: _avatar,
        career: local['career'] ?? RoleProvider.pickForUser(local['uid']),
      );
      await _presence.pushProfileData(record);
      if (mounted) setState(() {});
    }
  }

  void _updateOnlineStatus() async {
    await _bridge.updateUserStatus('online');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceCtrl.dispose();
    _callSub?.cancel();
    _coinSub?.cancel();
    _userSub?.cancel();
    _statusTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateOnlineStatus();
  }

  void _handleIncomingCall(Map<String, dynamic> data) async {
    if (!mounted || _push.isInCall) return;
    final roomId = data['roomId']?.toString();
    if (roomId == null) return;

    final isVideo = data['isVideoCall'] == true || data['isVideoCall'] == 'true';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => InboundCallOverlay(
        callerName: data['callerName'] ?? 'Chilli User',
        callerAvatar: data['callerAvatar'] ?? '',
        isVideoCall: isVideo,
        onAccept: () {
          Navigator.pop(c);
          _acceptCall(data);
        },
        onDecline: () {
          Navigator.pop(c);
          _declineCall(data);
        },
      ),
    );
  }

  void _acceptCall(Map<String, dynamic> data) async {
    await _bridge.updateUserStatus('busy');
    await _db.child('calls').child(data['roomId']).update({'status': 'answered'});
    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChilliCallView(
        roomId: data['roomId'],
        callerName: data['callerName'] ?? 'User',
        callerAvatar: data['callerAvatar'] ?? '',
        isOutgoing: false,
        isVideoCall: data['isVideoCall'] == true || data['isVideoCall'] == 'true',
        pushReceiver: _push,
        targetId: data['callerId'],
        remoteUid: data['callerId'],
        receiverToken: data['callerToken'] ?? data['token'],
      )));
      _updateOnlineStatus();
    }
  }

  void _declineCall(Map<String, dynamic> data) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) _db.child('pending_calls').child(uid).child(data['roomId']).remove();
    await _db.child('calls').child(data['roomId']).update({'status': 'declined'});
  }

  void _handleIncomingChat(Map<String, dynamic> data) async {
    if (!mounted || _push.isInCall) return;
    final roomId = data['roomId']?.toString();
    if (roomId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => InboundCallOverlay(
        callerName: data['senderName'] ?? 'Chilli User',
        callerAvatar: data['senderAvatar'] ?? '',
        isVideoCall: false,
        onAccept: () {
          Navigator.pop(c);
          _acceptChat(data);
        },
        onDecline: () {
          Navigator.pop(c);
          _declineChat(data);
        },
      ),
    );
  }

  void _acceptChat(Map<String, dynamic> data) async {
    await _bridge.updateUserStatus('busy');
    await _db.child('chats').child(data['roomId']).update({'status': 'connected'});
    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChilliChatScreen(
        roomId: data['roomId'],
        partnerName: data['senderName'] ?? 'User',
        partnerAvatar: data['senderAvatar'] ?? '',
        isOutgoing: false,
        pushReceiver: _push,
        partnerUid: data['senderUid'],
      )));
      _updateOnlineStatus();
    }
  }

  void _declineChat(Map<String, dynamic> data) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) _db.child('pending_chats').child(uid).child(data['roomId']).remove();
    await _db.child('chats').child(data['roomId']).update({'status': 'declined'});
  }

  void _startChat(ChilliProfile target) async {
    if (_isActionLock) return;
    if (_gender != 'female' && _coins < 2) {
      _showWalletHint();
      return;
    }

    setState(() => _isActionLock = true);
    try {
      await _bridge.updateUserStatus('busy');
      final roomId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
      
      if (mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ChilliChatScreen(
          roomId: roomId,
          partnerName: target.name,
          partnerAvatar: target.avatarUrl ?? '',
          isOutgoing: true,
          partnerUid: target.uid,
          pushReceiver: _push,
        )));
        _updateOnlineStatus();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isActionLock = false);
    }
  }

  void _startCall(ChilliProfile target, bool isVideo) async {
    if (_isActionLock) return;
    if (_gender != 'female' && _coins < 5) {
      _showWalletHint();
      return;
    }

    setState(() => _isActionLock = true);
    try {
      if (target.status == 'busy') throw 'User is busy';
      
      await _bridge.updateUserStatus('busy');
      final roomId = 'chilli_${DateTime.now().millisecondsSinceEpoch}';
      
      if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChilliCallView(
                roomId: roomId,
                callerName: target.name,
                callerAvatar: target.avatarUrl ?? '',
                isOutgoing: true,
                isVideoCall: isVideo,
                pushReceiver: _push,
                targetId: target.uid,
                receiverToken: target.fcmToken,
              ),
        ),
      );
      _updateOnlineStatus();
        _bridge.syncCoinsWithServer();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isActionLock = false);
    }
  }

  void _showWalletHint() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance')));
    setState(() => _currentTabIndex = 2);
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: _buildPageContent(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildPageContent() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: IndexedStack(
        index: _currentTabIndex,
        children: [
          const CallLogScreen(),
          _buildHomeFeed(),
          const ChilliWalletScreen(),
        ],
      ),
    );
  }

  Widget _buildHomeFeed() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _syncProfile(),
            color: _neonCyan,
            backgroundColor: _bg,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildFilterRail()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                _buildUserGrid(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
          decoration: BoxDecoration(
            color: _bg.withOpacity(0.7),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _neonCyan.withOpacity(0.5), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: (_avatar != null && _avatar!.isNotEmpty) ? NetworkImage(_avatar!) : null,
                    backgroundColor: Colors.white10,
                    child: (_avatar == null || _avatar!.isEmpty) ? const Icon(Icons.person, size: 16, color: Colors.white54) : null,
                  ),
                ),
              ),
              const Spacer(),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(text: 'CHILLI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
                    TextSpan(text: '•', style: TextStyle(color: _neonPink, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentTabIndex = 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _neonViolet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _neonViolet.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.toll_rounded, color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text('$_coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildFilterRail() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final filterName = _filters[i];
          final isSelected = _selectedFilter == filterName;
          final isAll = filterName == 'All';

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filterName),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected ? _neonCyan.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _neonCyan.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: _neonCyan.withOpacity(0.2), blurRadius: 10, spreadRadius: -2)]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: _neonCyan, shape: BoxShape.circle),
                    ),
                  if (isAll && !isSelected)
                    const Icon(Icons.language_rounded, size: 14, color: Colors.white24),
                  if (isAll && !isSelected) const SizedBox(width: 6),
                  Text(
                    filterName.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? _neonCyan : Colors.white60,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserGrid() {
    debugPrint('HomeScreen: searching profiles for target gender: $_target');
    return StreamBuilder<List<ChilliProfile>>(
      stream: _presence.watchUsers(targetGender: _target),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _neonCyan)));
        }
        
        var users = snap.data ?? [];
        if (_selectedFilter != 'All') {
          users = users.where((u) => u.language.toLowerCase() == _selectedFilter.toLowerCase()).toList();
        }

        if (users.isEmpty) {
          debugPrint('HomeScreen: RTDB empty, falling back to Firestore');
          return StreamBuilder<List<ChilliProfile>>(
            stream: _firestore.watchAllUsers(targetGender: _target),
            builder: (context, fSnap) {
              if (fSnap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _neonCyan)));
              }
              
              var fUsers = fSnap.data ?? [];
              if (_selectedFilter != 'All') {
                fUsers = fUsers.where((u) => u.language.toLowerCase() == _selectedFilter.toLowerCase()).toList();
              }

              if (fUsers.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, color: Colors.white.withOpacity(0.1), size: 64),
                        const SizedBox(height: 16),
                        Text('No users found nearby', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                      ],
                    ),
                  ),
                );
              }

              return _buildGrid(fUsers);
            },
          );
        }

        return _buildGrid(users);
      },
    );
  }

  Widget _buildGrid(List<ChilliProfile> users) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => UserTile(
            name: users[i].name,
            imageUrl: users[i].avatarUrl ?? '',
            language: users[i].language,
            gender: users[i].gender,
            isOnline: users[i].status == 'online',
            onAudioCall: () => _startCall(users[i], false),
            onVideoCall: () => _startCall(users[i], true),
            onChat: () => _startChat(users[i]),
            rating: 5.0,
            interests: const ['Chat', 'Connect'],
            audioPrice: '10',
            videoPrice: '20',
            audioUrl: users[i].audioUrl,
            coins: users[i].coins.toDouble(),
            currentUserGender: _gender,
            lastActive: users[i].lastActive,
            status: users[i].status,
            career: users[i].career,
            uid: users[i].uid,
          ),
          childCount: users.length,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151525).withOpacity(0.8),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.grid_view_rounded, 'EXPLORE'),
                _buildNavItem(1, Icons.history_toggle_off_rounded, 'HISTORY'),
                _buildNavItem(2, Icons.toll_rounded, 'WALLET'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 300),
            scale: isSelected ? 1.2 : 1.0,
            curve: Curves.easeOutBack,
            child: Icon(
              icon,
              color: isSelected ? _neonCyan : Colors.white24,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isSelected ? 12 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: _neonCyan,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                if (isSelected) BoxShadow(color: _neonCyan.withOpacity(0.5), blurRadius: 8, spreadRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
