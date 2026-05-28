import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import 'package:chilli/theme/palette.dart';
import 'package:chilli/widgets/user_tile.dart';
import 'package:chilli/screens/call_log_screen.dart';
import 'package:chilli/screens/wallet_screen.dart';
import 'package:chilli/screens/profile_screen.dart';
import 'package:chilli/services/firestore_repo.dart';
import 'package:chilli/models/profile.dart';
import 'package:chilli/services/push_receiver.dart';
import 'package:chilli/screens/chilli_call_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chilli/widgets/inbound_call.dart';
import 'package:chilli/widgets/funds_sheet.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/services/presence_repo.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chilli/services/build_validator.dart'; // ✅ Added BuildValidator
import 'package:chilli/services/review_manager.dart'; // ✅ Added ReviewManager
import 'package:chilli/utils/avatar_store.dart'; // ✅ Added AvatarStore
import 'package:chilli/utils/role_picker.dart'; // ✅ Added RolePicker

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 1; // Default to Home
  final FirestoreRepo _CloudDatabaseService = FirestoreRepo();
  final PresenceRepo _rtdbService = PresenceRepo();
  final PushReceiver _PushNotificationService =
      PushReceiver();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final IdentityManager _AuthenticationService = IdentityManager();
  final DataBridge _HttpService =
      DataBridge(); // ✅ Added DataBridge instance
  final _db = FirebaseDatabase.instance.ref();
  StreamSubscription? _callSubscription;
  StreamSubscription<num>? _tokenSubscription; // ✅ Added subscription
  Timer? _lastActiveTimer; // ✅ Added for periodic lastActive updates
  String? _currentUserGender;
  String? _currentUserLanguage; // ✅ Track current user's language
  DateTime? _lastProfileSyncTime; // ✅ Throttle profile syncs
  DateTime? _lastPresenceUpdateTime; // ✅ Throttle status/presence updates

  String? _targetGender;
  String? _currentUserAvatar;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription?
  _connectionSubscription; // ✅ Added for Connection monitoring
  Stream<List<Profile>>? _usersStream;
  bool _isCheckingCoins = false;
  num _currentCoins = 0;
  final Set<String> _visibleIncomingCallRooms =
      {}; // ✅ Track active dialogs to prevent duplicates
  final Map<String, DateTime> _processedCallTimestamps =
      {}; // ✅ Track when calls were last processed to prevent FCM+RTDB duplicates
  final Set<String> _handledCallRooms =
      {}; // ✅ Track calls that have been accepted/declined to prevent re-showing
  bool _isShowingCallDialog =
      false; // ✅ Global flag to prevent any duplicate dialogs
  bool _isShowingLowBalanceDialog =
      false; // ✅ Flag to prevent multiple low balance dialogs
  int _missedCallsDueToLowBalance = 0; // ✅ Track missed calls count

  final List<String> filters = [
    'All',
    'English',
    'Hindi', // हिंदी
    'Tamil', // தமிழ்
    'Telugu', // తెలుగు
    'Marathi', // मराठी
    'Bengali', // বাংলা
    'Gujarati', // ગુજરાતી
    'Kannada', // ಕನ್ನಡ
    'Malayalam', // മലയാളം
    'Punjabi', // ਪੰਜਾਬੀ
    'Odia', // ଓଡ଼ିଆ
    'Assamese', // অসমীয়া
  ];
  String selectedFilter = 'All';

  // ✅ Search functionality
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Check for App Updates
    BuildValidator.checkVersion(context);

    // ✅ Check for App Rating
    ReviewManager.checkAndShowRating(context);

    // ✅ SYNC PROFILE TO RTDB ON LOGIN/HOME
    _setupConnectionListener(); // ✅ Listen for connection status
    _syncProfileToRTDB();

    // ✅ FETCH USERS FROM RTDB
    _usersStream = _rtdbService.getAllUsers();
    _PushNotificationService.initialize().then((_) async {
      final token = await _PushNotificationService.getToken();
      if (token != null) {
        await _CloudDatabaseService.updateFCMToken(token);
      }
    });

    _PushNotificationService.onIncomingCall = (data) {
      print('🔔 FCM onIncomingCall triggered for: ${data['roomId']}');
      // Add small delay to let any RTDB listener fire first, then deduplication will catch it
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _handleIncomingCall(data);
        }
      });
    };

    _setupRealtimeCallListener();
    _setupUserListener();

    // ✅ Sync any offline changes when home loads
    _HttpService.syncCoinsWithServer();
    _HttpService.fetchAppConfig().then((_) {
      if (mounted) setState(() {});
    }); // ✅ Load dynamic config
    // ✅ Initial status update
    _updateStatusWithThrottle('online');

    // Listen for real-time coin updates
    _tokenSubscription = DataBridge.tokenStream.listen((coins) {
      if (mounted) {
        setState(() {
          _currentCoins = coins;
        });
      }
    });

    // ✅ HEARTBEAT: Unified throttled update (Every 1 minute)
    _lastActiveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && _auth.currentUser != null) {
        _updateStatusWithThrottle('online');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App Resumed: Checking for throttled status/profile sync');
      _syncProfileToRTDB();
      _updateStatusWithThrottle('online');
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      print('📱 App ${state.name}: Keeping status ONLINE');
    }
  }

  // ✅ Throttled status update helper
  Future<void> _updateStatusWithThrottle(String status) async {
    final now = DateTime.now();
    if (_lastPresenceUpdateTime != null &&
        now.difference(_lastPresenceUpdateTime!).inSeconds < 60) {
      debugPrint(
        '⏳ Status update skipped (Throttled: ${now.difference(_lastPresenceUpdateTime!).inSeconds}s ago)',
      );
      return;
    }

    _lastPresenceUpdateTime = now;
    await _HttpService.updateUserStatus(status);
    debugPrint('✅ Throttled Status Update: $status');
  }

  /// ✅ Sync local coins to RTDB (Handled by DataBridge)

  // ✅ Re-sync profile when connection restores (handling disconnect removal)
  void _setupConnectionListener() {
    _connectionSubscription = _db.child('.info/connected').onValue.listen((
      event,
    ) {
      final connected = event.snapshot.value as bool? ?? false;
      if (connected && mounted) {
        debugPrint('🔌 Connected to RTDB - Ensuring Profile Exists...');
        _syncProfileToRTDB();
      }
    });
  }

  void _setupUserListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // ✅ FIRST: Load coins from LOCAL storage (not Firebase!)
    _loadLocalCoins();

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newGender = data['gender']?.toString().toLowerCase().trim();
            final newLanguage = data['language']
                ?.toString(); // ✅ Get user's language

            if (newGender != _currentUserGender) {
              debugPrint(
                '🏠 Gender changed from $_currentUserGender to $newGender. Re-initializing _usersStream...',
              );
              final targetGender = newGender == 'male' ? 'female' : 'male';
              debugPrint(
                '🎯 Current user gender: $newGender, Target gender to show: $targetGender',
              );
              _usersStream = _rtdbService.getAllUsers(
                targetGender: targetGender,
              );
            }

            setState(() {
              _currentUserGender = newGender;
              _currentUserLanguage = newLanguage; // ✅ Store user's language
              _targetGender = _currentUserGender == 'male' ? 'female' : 'male';
              // Only update avatar from Firestore if it exists (otherwise keep local generated one)
              if (data['avatarUrl'] != null) {
                _currentUserAvatar = data['avatarUrl'].toString();
              }
            });
            // ❌ Don't save coins from Firebase to cache
            // _saveToCache(data);
            print(
              '💎 Firebase Update: Gender=$_currentUserGender, Language=$_currentUserLanguage (Local Coins: $_currentCoins)',
            );
          }
        });
  }

  /// ✅ Load coins ONLY from local SharedPreferences
  Future<void> _loadLocalCoins() async {
    try {
      final localCoins = await _HttpService.getLocalCoins();
      if (mounted) {
        setState(() {
          _currentCoins = localCoins;
        });
      }
      print('💰 Loaded LOCAL coins: $_currentCoins');
    } catch (e) {
      print('❌ Error loading local coins: $e');
    }
  }

  // ✅ Sync user profile from Cache to RTDB (Local-First)
  Future<void> _syncProfileToRTDB() async {
    // ✅ THROTTLE: Only sync profile every 1 minute to save bandwidth
    final now = DateTime.now();
    if (_lastProfileSyncTime != null &&
        now.difference(_lastProfileSyncTime!).inSeconds < 60) {
      debugPrint(
        '🔄 Profile sync throttled (last sync: ${now.difference(_lastProfileSyncTime!).inSeconds}s ago)',
      );
      return;
    }

    debugPrint('🔄 Starting profile sync to RTDB (Local-First)...');
    _lastProfileSyncTime = now;
    try {
      // ✅ Force Refresh from Firestore to get latest Language/Gender
      await _AuthenticationService.updateData();

      // 1. Get Local Data (Robust against Firestore Deletion)
      final localData = await _AuthenticationService.getUserData();

      if (localData != null) {
        debugPrint('🔄 Loaded User from Cache: ${localData['username']}');

        // 2. Update Local State (Gender, etc) for UI/Logic
        if (mounted) {
          final gender = localData['gender']?.toString().toLowerCase();
          final lang = localData['language']?.toString();
          final avatar = localData['avatarUrl']?.toString();

          if (gender != _currentUserGender) {
            setState(() {
              _currentUserGender = gender;
              _currentUserLanguage = lang;
              _currentUserAvatar = avatar;
              _targetGender = gender == 'male' ? 'female' : 'male';
              // Refresh stream
              _usersStream = _rtdbService.getAllUsers(
                targetGender: _targetGender,
              );
            });
          }
        }

        // 3. Get Fresh Tokens & Coins
        final fcmToken = await _PushNotificationService.getToken();
        final localCoins = await _HttpService.getLocalCoins();

        // ✅ Auto-Generate Avatar if missing (for legacy or minimal-firestore users)
        String? avatar = localData['avatarUrl']?.toString();
        final gender = localData['gender']?.toString().toLowerCase() ?? 'male';
        final username = localData['username']?.toString() ?? 'User';

        if (avatar == null || avatar.isEmpty) {
          debugPrint('🎨 Generating random avatar for $username...');
          avatar = AvatarStore.getRandomAvatar(gender);

          // Update UI immediately
          if (mounted) {
            setState(() {
              _currentUserAvatar = avatar;
            });
          }
        }

        // ✅ Save generated Avatar & FCM Token to LOCAL Cache
        await _AuthenticationService.updateLocalData({
          'avatarUrl': avatar,
          'fcmToken': fcmToken,
        });

        // ✅ Auto-Generate Career if missing
        String? career = localData['career']?.toString();
        if (career == null || career.isEmpty || career == 'Professional') {
          debugPrint('💼 Generating career for $username...');
          career = RolePicker.getCareerForUser(localData['uid'] ?? '');

          // Save to local cache
          await _AuthenticationService.updateLocalData({'career': career});
        }

        // 4. Construct Full Model (Injecting missing pieces)
        final userData = Profile.fromMap(localData).copyWith(
          coins: localCoins,
          status: 'online', // Derived from active session
          lastActive: DateTime.now(),
          fcmToken: fcmToken, // CRITICAL: Restore FCM Token
          avatarUrl: avatar, // ✅ Ensure new avatar is used
          career: career, // ✅ Ensure career is set
        );

        // 5. Sync to RTDB
        await _rtdbService.syncUserProfile(userData);
        debugPrint('✅ Profile successfully synced to RTDB');
      } else {
        debugPrint('⚠️ No local user data found to sync');
      }
    } catch (e) {
      debugPrint('❌ Error syncing profile to RTDB: $e');
    }
  }

  void _setupRealtimeCallListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final pendingRef = _db.child('pending_calls').child(currentUser.uid);

    // Listen for new calls - only use onChildAdded to prevent duplicates
    _callSubscription = pendingRef.onChildAdded.listen((event) {
      _processIncomingCallEvent(event);
    });

    // ✅ REMOVED onChildChanged listener to prevent duplicate dialogs
    // The onChildAdded listener is sufficient for detecting incoming calls
  }

  void _processIncomingCallEvent(DatabaseEvent event) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (event.snapshot.value != null) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      data['roomId'] = event.snapshot.key;

      print('📞 RTDB Event: Processing incoming call: ${data['roomId']}');
      print('📞 RTDB Event: Call status: ${data['status']}');

      // ✅ ONLY process calls that are pending/ringing/calling
      // Ignore answered, declined, ended calls
      final status = data['status']?.toString().toLowerCase();
      if (status != null &&
          status != 'pending' &&
          status != 'ringing' &&
          status != 'calling') {
        print('⛔ RTDB Event: Ignoring call with status: $status');
        return;
      }

      if (_PushNotificationService.isInCall) {
        print('📞 RTDB Event: Ignoring - User already in call');
        return;
      }

      _handleIncomingCall(data);
    }
  }

  @override
  void dispose() {
    debugPrint('🔄 HomeScreen disposing...');
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    _tokenSubscription?.cancel(); // ✅ Cancel token subscription
    _lastActiveTimer?.cancel(); // ✅ Cancel timer
    _userSubscription?.cancel();
    _connectionSubscription?.cancel(); // ✅ Cancel connection subscription
    _searchController.dispose(); // ✅ Dispose search controller
    debugPrint('🔄 HomeScreen disposed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14141E), // Dark GenZ background
      appBar: _selectedIndex == 1 ? _buildAppBar() : null,
      body: _buildBody(),
      extendBody: true, // Needed for floating nav bar so body flows under it
      // Custom Floating Bottom Navigation - Modern GenZ design
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.history_rounded, 'History', 0),
                    _buildNavItem(Icons.home_rounded, 'Home', 1),
                    _buildNavItem(Icons.account_balance_wallet_rounded, 'Wallet', 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const CallLogScreen();
      case 2:
        return const WalletScreen();
      case 1:
      default:
        return Column(
          children: [
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 20,
                  bottom: 100,
                ), // Padding for bottom nav
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter by Language Title
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filters.length,
                        itemBuilder: (context, index) {
                          final filter = filters[index];
                          final isSelected = selectedFilter == filter;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedFilter = filter;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF06B6D4) // GenZ cyan
                                    : const Color(0xFF1E293B), // Dark inactive
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF06B6D4)
                                      : Colors.white.withOpacity(0.1),
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF06B6D4,
                                          ).withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (filter == 'All') ...[
                                    Icon(
                                      Icons.language,
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[400],
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    filter,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[300],
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Match Section - Premium GenZ Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF1E293B,
                        ).withOpacity(0.6), // Dark glass
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Title & Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF06B6D4),
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'QUICK MATCH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFF8B5CF6),
                                size: 24,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Find your next connection instantly',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Action Buttons
                          Row(
                            children: [
                              // Video Call Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _startRandomCall(true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8B5CF6),
                                          Color(0xFF6D28D9),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF8B5CF6,
                                          ).withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.videocam_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Video',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Audio Call Button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _startRandomCall(false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF06B6D4),
                                          Color(0xFF0369A1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF06B6D4,
                                          ).withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.call_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Audio',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // User List - Real Data from Firestore
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StreamBuilder<List<Profile>>(
                        stream: _usersStream,
                        builder: (context, snapshot) {
                          if (_usersStream == null) {
                            debugPrint('🏠 User List Stream is NULL!');
                          }
                          debugPrint(
                            '🏠 User List StreamBuilder state: ${snapshot.connectionState}',
                          );

                          // Loading state
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            debugPrint('🏠 User List is WAITING for data...');
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: CircularProgressIndicator(
                                  color: Palette.primary,
                                ),
                              ),
                            );
                          }

                          // Error state
                          if (snapshot.hasError) {
                            print('❌ User List Error: ${snapshot.error}');
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading users',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      snapshot.error.toString(),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Get users and apply filter
                          List<Profile> users = snapshot.data ?? [];
                          print(
                            '👥 Found ${users.length} raw users (target: $_targetGender)',
                          );
                          if (users.isNotEmpty) {
                            print(
                              '💰 Debug Coins (User ${users[0].username}): ${users[0].coins} (${users[0].coins.runtimeType})',
                            );
                            print(
                              '🎤 Debug Audio (User ${users[0].username}): ${users[0].audioUrl}',
                            );
                          }

                          // ✅ Requirement: Don't show inactive users? SKIPPED for now to populate list.
                          /*
                          final now = DateTime.now();
                          users = users.where((user) {
                            if (user.lastActive == null)
                              return true; // Keep safe if unknown
                            return now.difference(user.lastActive!).inMinutes <=
                                30;
                          }).toList();
                          */

                          // ✅ Apply language filter if selected
                          if (selectedFilter != 'All') {
                            users = users
                                .where(
                                  (user) =>
                                      user.language.toLowerCase() ==
                                      selectedFilter.toLowerCase(),
                                )
                                .toList();
                          }

                          // ✅ Apply search filter
                          if (_searchQuery.isNotEmpty) {
                            users = users
                                .where(
                                  (user) => user.username
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase()),
                                )
                                .toList();
                          }

                          // ✅ Sort users: status -> language -> lastActive
                          users.sort((a, b) {
                            // Priority 1: Status (Online/Active > Busy > Offline)
                            int getStatusPriority(String status) {
                              final s = status.toLowerCase();
                              if (s == 'online' || s == 'active') return 1;
                              if (s == 'busy') return 2;
                              return 3;
                            }

                            final aPriority = getStatusPriority(a.status);
                            final bPriority = getStatusPriority(b.status);

                            if (aPriority != bPriority) {
                              return aPriority.compareTo(bPriority);
                            }

                            // Priority 2: Same language as current user
                            final aMatchesLanguage =
                                _currentUserLanguage != null &&
                                a.language.toLowerCase() ==
                                    _currentUserLanguage!.toLowerCase();
                            final bMatchesLanguage =
                                _currentUserLanguage != null &&
                                b.language.toLowerCase() ==
                                    _currentUserLanguage!.toLowerCase();

                            if (aMatchesLanguage && !bMatchesLanguage) {
                              return -1;
                            }
                            if (!aMatchesLanguage && bMatchesLanguage) {
                              return 1;
                            }

                            // Priority 3: Most recently active (lastActive)
                            if (a.lastActive != null && b.lastActive != null) {
                              return b.lastActive!.compareTo(a.lastActive!);
                            } else if (a.lastActive != null) {
                              return -1;
                            } else if (b.lastActive != null) {
                              return 1;
                            }

                            // Fallback: createdAt
                            return b.createdAt.compareTo(a.createdAt);
                          });

                          // Empty state
                          if (users.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      color: Colors.grey[400],
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      selectedFilter == 'All'
                                          ? 'No users available yet'
                                          : 'No users speak $selectedFilter',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Be the first to create an account!',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Display users
                          return Column(
                            children: users.map((user) {
                              return UserTile(
                                name: user.username,
                                imageUrl:
                                    user.avatarUrl ??
                                    'https://i.pravatar.cc/150?u=${user.uid}',
                                language: user.language,
                                gender: user.gender,
                                rating: 5.0, // Default rating
                                interests: const ['Chat', 'Connect'],
                                audioPrice:
                                    '${(DataBridge.appConfig['male_audio_cost'] ?? 2.5) * 2}',
                                videoPrice:
                                    '${(DataBridge.appConfig['male_video_cost'] ?? 2.5) * 2}',
                                isOnline:
                                    user.status.toLowerCase() == 'online' ||
                                    user.status.toLowerCase() ==
                                        'active', // ✅ Fix: Use status string
                                audioUrl: user.audioUrl,
                                coins: user.coins
                                    .toDouble(), // ✅ Pass coins (converted to double)
                                currentUserGender:
                                    _currentUserGender, // ✅ Pass current user gender
                                lastActive:
                                    user.lastActive, // ✅ Pass lastActive
                                status: user.status, // ✅ Pass status
                                career: user.career, // ✅ Pass user's career
                                onAudioCall: () => _startCall(user, false),
                                onVideoCall: () => _startCall(user, true),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data) async {
    if (!mounted) return;

    final roomId = data['roomId']?.toString();
    if (roomId == null) return;

    print('📞 ========================================');
    print('📞 _handleIncomingCall CALLED for room: $roomId');
    print('📞 Current time: ${DateTime.now()}');

    // ✅ CHECK IF USER IS ALREADY IN A CALL (on video call page)
    if (_PushNotificationService.isInCall) {
      print(
        '⛔ BLOCKED: User is already in a call, ignoring incoming call popup',
      );
      print('📞 ========================================');
      return;
    }

    // ✅ CHECK IF CALL WAS ALREADY HANDLED (accepted/declined)
    if (_handledCallRooms.contains(roomId)) {
      print('⛔ BLOCKED: Room $roomId was already handled (accepted/declined)!');
      print('📞 ========================================');
      return;
    }

    // ✅ TIMESTAMP-BASED DEDUPLICATION: Prevent FCM + RTDB from both triggering
    final now = DateTime.now();
    if (_processedCallTimestamps.containsKey(roomId)) {
      final lastProcessed = _processedCallTimestamps[roomId]!;
      final timeSinceLastProcess = now.difference(lastProcessed).inMilliseconds;

      print('📞 Room $roomId was last processed at: $lastProcessed');
      print('📞 Time since last process: ${timeSinceLastProcess}ms');

      if (timeSinceLastProcess < 3000) {
        // 3 seconds instead of 2
        print(
          '⛔ BLOCKED: Room $roomId was processed ${timeSinceLastProcess}ms ago (< 3000ms), ignoring duplicate!',
        );
        print('📞 ========================================');
        return;
      } else {
        print(
          '✅ Allowing: ${timeSinceLastProcess}ms has passed, processing call',
        );
      }
    } else {
      print('✅ First time seeing room $roomId, processing...');
    }

    // Mark this call as processed
    _processedCallTimestamps[roomId] = now;
    print('📞 Marked room $roomId as processed at: $now');

    // Cleanup old timestamps (older than 30 seconds)
    final beforeCleanup = _processedCallTimestamps.length;
    _processedCallTimestamps.removeWhere((key, value) {
      return now.difference(value).inSeconds > 30;
    });
    final afterCleanup = _processedCallTimestamps.length;
    if (beforeCleanup != afterCleanup) {
      print('🧹 Cleaned up ${beforeCleanup - afterCleanup} old timestamps');
    }

    // ✅ PREVENT DUPLICATE DIALOGS (FCM + RTDB Race)
    if (_visibleIncomingCallRooms.contains(roomId)) {
      print('⛔ BLOCKED: Room $roomId already has a visible dialog!');
      print('📞 ========================================');
      return;
    }

    print('✅ Proceeding to show dialog for room: $roomId');
    print('📞 ========================================');

    // ✅ STRICT GENDER CHECK: Only allow M-F and F-M calls
    final callerGender = (data['callerGender'] as String?)?.toLowerCase();
    print('📞 My Gender: $_currentUserGender, Caller Gender: $callerGender');

    if (_currentUserGender != null &&
        callerGender != null &&
        _currentUserGender == callerGender) {
      print(
        '🚫 BLOCKING same-gender call: MyGender=$_currentUserGender, CallerGender=$callerGender',
      );
      _declineCall(data); // Auto-decline if possible
      return;
    }

    // ✅ CHECK FOR AUTO-ACCEPT (From Notification Action or SharedPreferences)
    bool shouldAutoAccept = data['accepted'] == true;

    // Fallback: Check SharedPreferences for very fast cold start signal
    if (!shouldAutoAccept && data['roomId'] != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastAnswered = prefs.getString('last_answered_roomId');
        if (lastAnswered == data['roomId'].toString()) {
          print('✅ Auto-Accepting via SharedPreferences signal!');
          shouldAutoAccept = true;
          // Clear it after use
          await prefs.remove('last_answered_roomId');
        }
      } catch (e) {
        print('⚠️ Error checking auto-accept prefs: $e');
      }
    }

    if (shouldAutoAccept) {
      print('✅ Call already accepted. Joining immediately...');

      // ✅ Track this room to prevent it from showing a dialog if RTDB fires again
      setState(() {
        _visibleIncomingCallRooms.add(roomId);
      });

      // ✅ Remove the node from pending_calls now that we are joining
      if (data['roomId'] != null) {
        _db
            .child('pending_calls')
            .child(_auth.currentUser!.uid)
            .child(data['roomId'])
            .remove();
      }

      _acceptCall(data);
      return;
    }

    // ✅ MALE COIN CHECK: Don't allow accepting if balance is low
    final isVideoCall =
        data['isVideoCall'] == true || data['isVideoCall'] == 'true';

    // ✅ Robust Coin Check for Incoming
    if (_currentUserGender != 'female') {
      if (_currentCoins < 5) {
        print(
          '💰 Restricted user has low balance ($_currentCoins), declining call',
        );
        _declineCall(data);

        // ✅ Increment missed calls counter
        _missedCallsDueToLowBalance++;

        // ✅ Only show dialog if not already showing
        if (mounted && !_isShowingLowBalanceDialog) {
          setState(() => _isShowingLowBalanceDialog = true);

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => FundsSheet(
              currentBalance: _currentCoins,
              missedCallsCount: _missedCallsDueToLowBalance,
            ),
          ).then((_) {
            // Reset flags when dialog closes
            if (mounted) {
              setState(() {
                _isShowingLowBalanceDialog = false;
                _missedCallsDueToLowBalance = 0;
              });
            }
          });
        }
        return;
      }
      // If balance is okay, show the dialog
      _showCallRequestDialog(data, isVideoCall);
    } else {
      // Females can always accept
      _showCallRequestDialog(data, isVideoCall);
    }
  }

  void _showCallRequestDialog(Map<String, dynamic> data, bool isVideoCall) {
    if (!mounted) return;
    final roomId = data['roomId']?.toString();
    if (roomId == null) return;

    print('🎯 _showCallRequestDialog called for room: $roomId');
    print('🎯 _isShowingCallDialog: $_isShowingCallDialog');
    print('🎯 _visibleIncomingCallRooms: $_visibleIncomingCallRooms');

    // ✅ GLOBAL FLAG CHECK: Prevent ANY dialog if one is already showing
    if (_isShowingCallDialog) {
      print(
        '⛔ BLOCKED: A call dialog is already showing! Ignoring room: $roomId',
      );
      return;
    }

    // Double check to be super safe
    if (_visibleIncomingCallRooms.contains(roomId)) {
      print('⛔ BLOCKED: Room $roomId already in visible set!');
      return;
    }

    print('✅ Showing dialog for room: $roomId');

    setState(() {
      _visibleIncomingCallRooms.add(roomId);
      _isShowingCallDialog = true; // ✅ Set global flag
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => InboundCall(
        callerName: data['callerName'] ?? 'Unknown',
        callerAvatar:
            data['callerAvatar'] ?? 'https://i.pravatar.cc/150?u=unknown',
        isVideoCall: isVideoCall,
        onAccept: () {
          setState(() {
            _visibleIncomingCallRooms.remove(roomId);
            _isShowingCallDialog = false; // ✅ Clear global flag
            _handledCallRooms.add(roomId); // ✅ Mark as handled
          });
          Navigator.pop(dialogContext); // Close dialog
          _acceptCall(data);
        },
        onDecline: () {
          setState(() {
            _visibleIncomingCallRooms.remove(roomId);
            _isShowingCallDialog = false; // ✅ Clear global flag
            _handledCallRooms.add(roomId); // ✅ Mark as handled
          });
          Navigator.pop(dialogContext); // Close dialog
          _declineCall(data);
        },
      ),
    ).then((_) {
      // Ensure it's removed if dialog closes for any other reason
      setState(() {
        _visibleIncomingCallRooms.remove(roomId);
        _isShowingCallDialog = false; // ✅ Clear global flag
        _handledCallRooms.add(roomId); // ✅ Mark as handled
      });
    });
  }

  void _declineCall(Map<String, dynamic> data) async {
    final roomId = data['roomId']?.toString();
    final currentUser = _auth.currentUser;

    if (currentUser != null && roomId != null) {
      // ✅ Remove from pending_calls immediately so it doesn't stay in RTDB
      _db.child('pending_calls').child(currentUser.uid).child(roomId).remove();

      // ✅ Cleanup timestamp tracking
      _processedCallTimestamps.remove(roomId);
    }

    await _db.child('calls').child(data['roomId']).update({
      'status': 'declined',
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call declined')));
    }
    if (roomId != null) {
      _visibleIncomingCallRooms.remove(roomId);
    }
  }

  void _acceptCall(Map<String, dynamic> data) async {
    final roomId = data['roomId']?.toString();
    final currentUser = _auth.currentUser;

    if (currentUser != null && roomId != null) {
      // ✅ Remove from pending_calls immediately
      _db.child('pending_calls').child(currentUser.uid).child(roomId).remove();

      // ✅ Cleanup timestamp tracking
      _processedCallTimestamps.remove(roomId);
    }

    // ✅ Update status to busy when accepting call
    await _HttpService.updateUserStatus('busy');

    await _db.child('calls').child(data['roomId']).update({
      'status': 'answered',
    });

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChilliCallView(
            roomId: data['roomId'],
            callerName: data['callerName'] ?? 'Unknown',
            callerAvatar: data['callerAvatar'] ?? '',
            isOutgoing: false,
            isVideoCall:
                data['isVideoCall'] == true || data['isVideoCall'] == 'true',
            pushNotificationService: _PushNotificationService,
            targetId: data['callerId'], // ✅ Pass caller's ID for GiftModeling
            remoteUid: data['callerId'], // ✅ Pass for History Logic
            receiverToken:
                data['callerToken'] ??
                data['token'], // ✅ Prefer callerToken from RTDB
          ),
        ),
      );

      // ✅ Restore status to online when call ends
      await _HttpService.updateUserStatus('online');

      // ✅ Cleanup set
      _visibleIncomingCallRooms.remove(data['roomId']?.toString());
    }
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Future<bool> _checkCoinsAndShowDialog() async {
    print(
      '💰 Performing Coin Check: Gender=$_currentUserGender, Coins=$_currentCoins',
    );

    if (_currentUserGender != 'female') {
      if (_currentCoins < 5) {
        print('🚫 BLOCKING: Coins < 5');
        if (mounted) {
          _showToast(
            'Insufficient coins. Please add coins to your balance.',
            Colors.orange,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WalletScreen()),
          );
        }
        return false;
      }
    }
    return true;
  }

  String _formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return 'a while ago';
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _startCall(Profile targetUser, bool isVideoCall) async {
    if (_isCheckingCoins) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isCheckingCoins = true);

    try {
      // ✅ Robust Coin Check with Dialog
      final hasEnough = await _checkCoinsAndShowDialog();
      if (!hasEnough) return;

      if (currentUser.uid == targetUser.uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You cannot call yourself")),
          );
        }
        return;
      }

      final status = targetUser.status.toLowerCase();

      // ✅ Block calling users who are busy
      if (status == 'busy') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${targetUser.username} is currently busy on another call",
              ),
            ),
          );
        }
        return;
      }

      // ✅ Warn if user hasn't been active recently (over 60 minutes)
      // But still allow the call attempt
      if (status != 'online' &&
          status != 'active' &&
          targetUser.lastActive != null) {
        final inactiveDuration = DateTime.now().difference(
          targetUser.lastActive!,
        );
        if (inactiveDuration.inMinutes > 60) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "${targetUser.username} was last active ${_formatLastActive(targetUser.lastActive)}. They may not answer.",
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }

      // ✅ Update status to busy when starting call
      await _HttpService.updateUserStatus('busy');

      // Create a unique room ID
      final roomId =
          'room_${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid.substring(0, 5)}';

      // ✅ Fetch FCM token if missing (Compact Mode Support)
      String? receiverToken = targetUser.fcmToken;
      if (receiverToken == null || receiverToken.isEmpty) {
        debugPrint(
          '🔍 Fetching FCM token for ${targetUser.uid} from Firestore...',
        );
        try {
          final fullProfile = await _CloudDatabaseService.getUserById(
            targetUser.uid,
          );
          receiverToken = fullProfile?.fcmToken;
        } catch (e) {
          debugPrint('❌ Failed to fetch token: $e');
        }
      }

      // ✅ Fetch alternative users for auto-retry if manual call fails
      List<Map<String, dynamic>> candidateUsers = [];
      try {
        print('🔍 Fetching alternative users for fallback...');
        final users = await _rtdbService.getUsersList(
          targetGender: _targetGender,
        );

        final now = DateTime.now();

        // Filter quality candidates (same criteria as random calling)
        final alternatives = users.where((u) {
          final isNotMe = u.uid != currentUser.uid;
          final isNotTarget =
              u.uid != targetUser.uid; // Exclude the primary target
          final isOnline =
              u.status.toLowerCase() == 'online' ||
              u.status.toLowerCase() == 'active';
          final isNotBusy = u.status.toLowerCase() != 'busy';
          final hasValidToken = u.fcmToken != null && u.fcmToken!.isNotEmpty;

          bool isRecentlyActive = false;
          if (u.lastActive != null) {
            final diff = now.difference(u.lastActive!);
            isRecentlyActive = diff.inMinutes <= 10;
          }

          return isNotMe &&
              isNotTarget &&
              isOnline &&
              isNotBusy &&
              hasValidToken &&
              isRecentlyActive;
        }).toList();

        // Sort by language match and recency
        alternatives.sort((a, b) {
          final aMatchesLanguage =
              _currentUserLanguage != null &&
              a.language.toLowerCase() == _currentUserLanguage!.toLowerCase();
          final bMatchesLanguage =
              _currentUserLanguage != null &&
              b.language.toLowerCase() == _currentUserLanguage!.toLowerCase();

          if (aMatchesLanguage && !bMatchesLanguage) return -1;
          if (!aMatchesLanguage && bMatchesLanguage) return 1;

          final laA = a.lastActive?.millisecondsSinceEpoch ?? 0;
          final laB = b.lastActive?.millisecondsSinceEpoch ?? 0;
          return laB.compareTo(laA);
        });

        // Take top 20 alternatives
        final alternativesList = alternatives
            .take(20)
            .map(
              (u) => {
                'uid': u.uid,
                'Name': u.username,
                'Avatar': u.avatarUrl ?? 'https://i.pravatar.cc/150?u=${u.uid}',
                'Token': u.fcmToken,
              },
            )
            .toList();

        // ✅ CRITICAL: Prepend the primary target user as first candidate
        // This ensures the selected user is ALWAYS tried first
        candidateUsers = [
          {
            'uid': targetUser.uid,
            'Name': targetUser.username,
            'Avatar':
                targetUser.avatarUrl ??
                'https://i.pravatar.cc/150?u=${targetUser.uid}',
            'Token': receiverToken,
          },
          ...alternativesList, // Then add alternatives
        ];

        print(
          '✅ Prepared ${candidateUsers.length} users: ${targetUser.username} (primary) + ${alternativesList.length} alternatives',
        );
      } catch (e) {
        debugPrint(
          '⚠️ Failed to fetch alternative users: $e (will try selected user only)',
        );
      }

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChilliCallView(
              roomId: roomId,
              callerName: targetUser.username,
              callerAvatar:
                  targetUser.avatarUrl ??
                  'https://i.pravatar.cc/150?u=${targetUser.uid}',
              isOutgoing: true,
              isVideoCall: isVideoCall,
              receiverToken: receiverToken, // ✅ Use fetched token
              targetId: targetUser.uid,
              pushNotificationService: _PushNotificationService,
              candidateUsers: candidateUsers.isNotEmpty
                  ? candidateUsers
                  : null, // ✅ Fallback users
            ),
          ),
        );

        // ✅ Restore status to online when call ends
        await _HttpService.updateUserStatus('online');
        // ✅ Refresh coins
        _loadLocalCoins();
      }
    } catch (e) {
      print('❌ Error starting call: $e');
    } finally {
      if (mounted) setState(() => _isCheckingCoins = false);
    }
  }

  void _startRandomCall(bool isVideoCall) async {
    if (_isCheckingCoins) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isCheckingCoins = true);

    try {
      // 0. Initial coin check with Dialog
      final hasEnough = await _checkCoinsAndShowDialog();
      if (!hasEnough) return;

      // 1. Fetch available online users - Filtered by target gender
      final users = await _rtdbService.getUsersList(
        targetGender: _targetGender,
      );

      // 2. ✅ ENHANCED FILTERING: Stricter criteria for better quality matches
      final now = DateTime.now();
      final List<Profile> candidates = users.where((u) {
        // Basic checks
        final isNotMe = u.uid != currentUser.uid;
        final isOnline =
            u.status.toLowerCase() == 'online' ||
            u.status.toLowerCase() == 'active';

        // ✅ Not busy (don't call users already in a call)
        final isNotBusy = u.status.toLowerCase() != 'busy';

        // ✅ Has valid FCM token (critical for call notifications)
        final hasValidToken = u.fcmToken != null && u.fcmToken!.isNotEmpty;

        // ✅ Recently active (within 10 minutes for better success rate)
        bool isRecentlyActive = false;
        if (u.lastActive != null) {
          final diff = now.difference(u.lastActive!);
          isRecentlyActive =
              diff.inMinutes <= 10; // Stricter: 10 mins instead of 30
        }

        return isNotMe &&
            isOnline &&
            isNotBusy &&
            hasValidToken &&
            isRecentlyActive;
      }).toList();

      if (candidates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "No available users found right now. Please try again!",
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // print('🎲 Found ${candidates.length} quality candidates for random call');

      // 3. ✅ SMART MULTI-CRITERIA SORTING for best matches
      candidates.sort((a, b) {
        // Priority 1: Language match (same language users first)
        final aMatchesLanguage =
            _currentUserLanguage != null &&
            a.language.toLowerCase() == _currentUserLanguage!.toLowerCase();
        final bMatchesLanguage =
            _currentUserLanguage != null &&
            b.language.toLowerCase() == _currentUserLanguage!.toLowerCase();

        if (aMatchesLanguage && !bMatchesLanguage) return -1;
        if (!aMatchesLanguage && bMatchesLanguage) return 1;

        // Priority 2: Most recently active (within same language group)
        final laA = a.lastActive?.millisecondsSinceEpoch ?? 0;
        final laB = b.lastActive?.millisecondsSinceEpoch ?? 0;

        if (laA != laB) {
          return laB.compareTo(laA); // Most recent first
        }

        // Priority 3: Random (for variety among equally good matches)
        return 0;
      });

      // ✅ Take more candidates for better retry success (20 instead of all)
      final topCandidates = candidates.take(20).toList();

      // ✅ Add some randomness within top candidates for variety
      if (topCandidates.length > 3) {
        // Keep first 3 (best matches), shuffle the rest
        final bestThree = topCandidates.sublist(0, 3);
        final others = topCandidates.sublist(3);
        others.shuffle();
        topCandidates.clear();
        topCandidates.addAll([...bestThree, ...others]);
      }

      // 4. Convert to Map list for ChilliCallView
      final List<Map<String, dynamic>> candidateData = topCandidates
          .map(
            (u) => {
              'uid': u.uid,
              'Name': u.username,
              'Avatar': u.avatarUrl ?? 'https://i.pravatar.cc/150?u=${u.uid}',
              'Token': u.fcmToken,
            },
          )
          .toList();

      // print(
      //   '🎯 Prepared ${candidateData.length} candidates (Language: ${topCandidates.first.language})',
      // );

      // 5. Start call with the first candidate and pass the whole list
      final targetUser = topCandidates.first;
      final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}_random';

      if (mounted) {
        // ✅ Update status to busy when starting random call
        await _HttpService.updateUserStatus('busy');
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChilliCallView(
              roomId: roomId,
              callerName: targetUser.username,
              callerAvatar:
                  targetUser.avatarUrl ??
                  'https://i.pravatar.cc/150?u=${targetUser.uid}',
              isOutgoing: true,
              isVideoCall: isVideoCall,
              receiverToken: targetUser.fcmToken,
              targetId: targetUser.uid,
              pushNotificationService: _PushNotificationService,
              candidateUsers: candidateData, // ✅ Pass via constructor
            ),
          ),
        );

        // ✅ Restore status to online when call ends
        await _HttpService.updateUserStatus('online');
        // ✅ Refresh coins
        _loadLocalCoins();
      }
    } catch (e) {
      // print('❌ Error in random call: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCheckingCoins = false);
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          if (index == 1) {
            _usersStream = _rtdbService.getAllUsers(
              targetGender: _targetGender,
            );
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF06B6D4).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.5),
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF14141E),
      elevation: 0,
      centerTitle: true,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 16, color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            )
          : const Text(
              'chilli',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF0F172A),
              backgroundImage: _currentUserAvatar != null && _currentUserAvatar!.isNotEmpty
                  ? NetworkImage(_currentUserAvatar!)
                  : null,
              child: _currentUserAvatar == null || _currentUserAvatar!.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF8B5CF6), size: 20)
                  : null,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 10.0, bottom: 10.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    _currentCoins.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


