import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chilli/theme/palette.dart';
import 'package:chilli/widgets/user_tile.dart';
import 'package:chilli/screens/call_log_screen.dart';
import 'package:chilli/screens/wallet_screen.dart';
import 'package:chilli/screens/profile_screen.dart';
import 'package:chilli/screens/call_screen.dart';
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
      if (e.snapshot.value != null) {
        final d = Map<String, dynamic>.from(e.snapshot.value as Map);
        d['roomId'] = e.snapshot.key;
        _handleIncomingCall(d);
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
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
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
        await Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
          roomId: roomId,
          callerName: target.name,
          callerAvatar: target.avatarUrl ?? '',
          isOutgoing: true,
          isVideoCall: isVideo,
          receiverToken: target.fcmToken,
          targetId: target.uid,
          pushReceiver: _push,
        )));
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
                SliverToBoxAdapter(child: _buildQuickActionCard()),
                SliverToBoxAdapter(child: _buildFilterRail()),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
      decoration: BoxDecoration(
        color: _bg.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _neonViolet.withOpacity(0.5), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: _neonViolet.withOpacity(0.1),
                    backgroundImage: _avatar != null ? NetworkImage(_avatar!) : null,
                    child: _avatar == null ? const Icon(Icons.person_rounded, color: _neonViolet, size: 20) : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: _neonViolet, shape: BoxShape.circle),
                    child: const Icon(Icons.tune_rounded, color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: const Row(
              children: [
                Icon(Icons.whatshot_rounded, color: _neonPink, size: 28),
                SizedBox(width: 8),
                Text(
                  'CHILLI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          _buildCoinPill(),
        ],
      ),
    );
  }

  Widget _buildCoinPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _neonViolet.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonViolet.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.toll_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(
            _coins.toStringAsFixed(0),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_neonViolet.withOpacity(0.2), _neonPink.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _neonViolet.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Match', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('Start a random spicy chat', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
            ],
          ),
          const Spacer(),
          _buildActionButton(Icons.videocam_rounded, _neonCyan, () {}),
          const SizedBox(width: 12),
          _buildActionButton(Icons.mic_rounded, _neonPink, () {}),
        ],
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
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final isSelected = _selectedFilter == _filters[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = _filters[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? _neonCyan.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? _neonCyan : Colors.white.withOpacity(0.1)),
              ),
              alignment: Alignment.center,
              child: Text(
                _filters[i],
                style: TextStyle(color: isSelected ? _neonCyan : Colors.white.withOpacity(0.5), fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserGrid() {
    return StreamBuilder<List<ChilliProfile>>(
      stream: _presence.watchUsers(targetGender: _target),
      builder: (context, snap) {
        if (!snap.hasData) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _neonCyan)));
        
        var users = snap.data!;
        if (_selectedFilter != 'All') {
          users = users.where((u) => u.language.toLowerCase() == _selectedFilter.toLowerCase()).toList();
        }

        if (users.isEmpty) return SliverFillRemaining(child: Center(child: Text('No users found', style: TextStyle(color: Colors.white.withOpacity(0.3)))));

        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
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
              ),
              childCount: users.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.schedule_rounded, 'HISTORY'),
          _buildNavItem(1, Icons.radar_rounded, 'EXPLORE'),
          _buildNavItem(2, Icons.account_balance_wallet_rounded, 'WALLET'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _neonCyan : Colors.white.withOpacity(0.2),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _neonCyan : Colors.white.withOpacity(0.2),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
