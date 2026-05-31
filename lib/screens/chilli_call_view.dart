import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart'; // ✅ Add audio player
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/push_receiver.dart';
import '../services/peer_session.dart';
import '../services/notif_transmitter.dart';
import '../services/data_bridge.dart'; // Add this
import '../services/biometric_scanner.dart';
import '../services/identity_manager.dart';
import '../models/virtual_item.dart'; // Gift system models

enum ConnectionQuality { excellent, good, poor, disconnected, failed }

enum VideoLayout { normal, fullscreen }

class ChilliCallView extends StatefulWidget {
  final String roomId;
  final String callerName;
  final String callerAvatar;
  final bool isOutgoing;
  final bool isVideoCall;
  final String? receiverToken;
  final String? targetId;
  final String? remoteUid; // ✅ Added to track other user ID
  final PushReceiver pushNotificationService;
  final List<Map<String, dynamic>>?
  candidateUsers; // ✅ Alternative users for auto-retry

  const ChilliCallView({
    super.key,
    required this.roomId,
    required this.callerName,
    required this.callerAvatar,
    this.isOutgoing = false,
    this.isVideoCall = true,
    this.receiverToken,
    this.targetId,
    this.remoteUid,
    required this.pushNotificationService,
    this.candidateUsers,
  });

  @override
  State<ChilliCallView> createState() => _ChilliCallViewState();
}

class _ChilliCallViewState extends State<ChilliCallView>
    with TickerProviderStateMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final PeerSession _VideoCallService = PeerSession();
  final NotifTransmitter _fcmSender = NotifTransmitter();
  final IdentityManager _AuthenticationService = IdentityManager();
  final DataBridge _HttpService =
      DataBridge(); // Add after IdentityManager
  final _db = FirebaseDatabase.instance.ref();
  final BiometricScanner _FaceRecognitionService =
      BiometricScanner();

  MediaStream? _localStream;
  bool _callEnded = false;
  bool _locallyEnded = false;
  bool _cleanupCalled = false;
  bool _isConnected = false;
  bool _hasInternet = true;
  bool _isDeleted = false;
  bool _roomDeletedByOptimization = false; // ✅ Optimization Flag

  Timer? _tokenTimer;
  num _currentTokens = 0;
  Timer? _coinDeductionTimer;
  // ✅ Add call timer variables
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  // ✅ Add calling tune player
  late AudioPlayer _callingTunePlayer;
  bool _isCallingTunePlaying = false;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isSpeakerOn =
      true; // Speaker mode: true = loudspeaker, false = earpiece

  bool _showFaceWarning = false;
  int _warningCountdown = 45;

  ConnectionQuality _connectionQuality = ConnectionQuality.good;
  VideoLayout _videoLayout = VideoLayout.normal;
  // ✅ Smart dial state
  String? _currentRoomId; // dynamic room id per attempt
  String? _currentReceiverToken; // dynamic token per attempt
  List<Map<String, dynamic>> _candidateUsers = const [];
  int _currentCandidateIndex = 0;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;
  static const int _firstAttemptTimeoutSeconds =
      16; // ✅ First attempt (manual call)
  static const int _subsequentAttemptTimeoutSeconds =
      16; // ✅ Subsequent attempts (random)
  Timer? _pickupTimer;
  // ✅ Dynamic callee display for smart dial
  String? _currentCalleeName;
  String? _currentCalleeAvatar;
  Timer? _countdownTimer;
  Timer? _connectionCheckTimer;
  StreamSubscription<DatabaseEvent>? _callEndListener;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  // late AnimationController _pulseController;
  // late AnimationController _rotationController;
  // late AnimationController _buttonScaleController;
  // late AnimationController _rippleController;
  late AnimationController _GiftModelAnimationController;
  // late Animation<double> _pulseAnimation;
  // late Animation<double> _rotationAnimation;
  // late Animation<double> _buttonScaleAnimation;
  // late Animation<double> _rippleAnimation;
  String? _currentUserName;
  String? _currentUserEmail;
  String? _currentUserAvatar;
  // Helpers to unify room/token for smart dial vs single-call flows
  String get _roomIdEffective => _currentRoomId ?? widget.roomId;
  String? get _receiverTokenEffective =>
      _currentReceiverToken ?? widget.receiverToken;
  String get _displayName => widget.isOutgoing
      ? (_currentCalleeName ?? widget.callerName)
      : widget.callerName;
  String get _displayAvatar => widget.isOutgoing
      ? (_currentCalleeAvatar ?? widget.callerAvatar)
      : widget.callerAvatar;

  // ✅ Add pricing data variables
  double _maleAudioCost = 5;
  double _maleVideoCost = 10;
  double _femaleAudioCost = 1;
  double _femaleVideoCost = 1;
  String? _currentUserGender;

  // VirtualItem system state
  bool _showGiftModelMenu = false;
  List<VirtualItem> _availableGiftModels = [];
  final List<Map<String, dynamic>> _GiftModelHistory = [];
  VirtualItem? _currentAnimatingGiftModel;
  String? _currentGiftModelSenderName;

  // 🎧 Audio routing – earphone/headset detection
  static const _audioMethodChannel = MethodChannel('audio_route/check');
  static const _audioEventChannel = EventChannel('audio_route/events');
  StreamSubscription<dynamic>? _headsetSubscription;

  @override
  void initState() {
    super.initState();
    widget.pushNotificationService.isInCall =
        true; // ✅ Mark as in call immediately
    _callingTunePlayer = AudioPlayer();

    // ✅ Listen for Call Ended via FCM (as RTDB room might be deleted)
    widget.pushNotificationService.onCallEnded = (roomId) {
      if (mounted && roomId == _roomIdEffective) {
        print('📞 FCM Call Ended received');
        _showLocalEndMessage(
          'Call Ended',
          'The other user ended the call.',
          Icons.call_end_rounded,
          Colors.red,
        );
      }
    };

    // ✅ Listen for WebRTC State Changes for Optimization Flag & Disconnects
    _VideoCallService.onConnectionStateChange = (state) async {
      if (!mounted || _callEnded) return;

      print('🔄 WebRTC State Change: $state');

      setState(() {
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
          case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            _isConnected = true;
            _roomDeletedByOptimization = true;
            _connectionQuality = ConnectionQuality.excellent;
            break;
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            _connectionQuality = ConnectionQuality.poor;
            // Fail-safe: Aggressive disconnect (1.5s) favored over reconnection
            Timer(const Duration(milliseconds: 1500), () {
              if (mounted &&
                  !_callEnded &&
                  _connectionQuality == ConnectionQuality.poor) {
                print('⏱️ Disconnect timeout (1.5s) - Ending call');
                _handleConnectionLost();
              }
            });
            break;
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            _connectionQuality = ConnectionQuality.failed;
            print('❄️ ICE Failed - Attempting manual ICE restart...');
            _VideoCallService.restartIce();
            // Give it 5 seconds to recover, otherwise end call
            Timer(const Duration(seconds: 5), () {
              if (_connectionQuality == ConnectionQuality.failed &&
                  !_callEnded) {
                _handleConnectionLost();
              }
            });
            break;
          case RTCIceConnectionState.RTCIceConnectionStateClosed:
            print('❄️ ICE Closed - Ending Call');
            _cleanup();
            if (mounted) Navigator.pop(context);
            break;
          default:
            break;
        }
      });

      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        await _stopCallingTune();
      }
    };

    WakelockPlus.enable(); // 💡 Prevent app from sleeping
    _initCallData();
  }

  Future<void> _deleteCallRoom() async {
    if (_isDeleted) return;
    _isDeleted = true;

    try {
      print('🗑️ Deleting call room in Realtime DB: ${_roomIdEffective}');

      await _db.child('calls').child(_roomIdEffective).remove();

      // Also remove from pending_calls if targetId is known
      final targetId = widget.isOutgoing
          ? (widget.targetId ??
                (_candidateUsers.isNotEmpty
                    ? _candidateUsers[_currentCandidateIndex]['uid']
                    : null))
          : FirebaseAuth.instance.currentUser?.uid;
      if (targetId != null) {
        await _db
            .child('pending_calls')
            .child(targetId)
            .child(_roomIdEffective)
            .remove();
      }

      print('✅ Call room deleted successfully from Realtime DB');
    } catch (e) {
      print('❌ Error deleting call room: $e');
    }
  }

  Future<void> _initCallData() async {
    await _loadTokensFromCache();
    await _loadCurrentUserName();
    await _loadPricingData();
    _loadAvailableGiftModels();

    // ✅ Set isInCall flag to prevent incoming calls
    PushReceiver().isInCall = true;
    print('🔒 isInCall flag set to TRUE');

    if (mounted) {
      if (widget.isOutgoing) {
        _initializeOutgoingFlow();
      } else {
        _initializeCall();
      }
    }
  }

  bool _depsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsInitialized) return;
    _depsInitialized = true;

    _initializeAnimations();

    // ✅ First check if candidateUsers was passed directly to widget
    if (widget.candidateUsers != null && widget.candidateUsers!.isNotEmpty) {
      _candidateUsers = widget.candidateUsers!;
    } else {
      // Fallback: Check route arguments (for backward compatibility)
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is Map && routeArgs['candidateUsers'] is List) {
        _candidateUsers = List<Map<String, dynamic>>.from(
          routeArgs['candidateUsers'] as List,
        );
      }
    }
  }

  // ✅ KEEP THIS
  Future<void> _loadCurrentUserName() async {
    try {
      // First try cache
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');
      if (userData != null) {
        final data = jsonDecode(userData);
        _currentUserName = data['name'] ?? data['username'] ?? 'User';
        _currentUserEmail = data['email'] ?? data['Email'] ?? '';
        _currentUserAvatar = data['Avatar'] ?? data['avatarUrl'] ?? '';
      }

      // Then try Firestore for fresher data
      final fsData = await _AuthenticationService.getUserData();
      if (fsData != null) {
        setState(() {
          _currentUserName =
              fsData['name'] ?? fsData['username'] ?? _currentUserName;
          _currentUserAvatar =
              fsData['avatarUrl'] ?? fsData['Avatar'] ?? _currentUserAvatar;
          _currentUserGender = fsData['gender']?.toString().toLowerCase();
        });
      }
    } catch (e) {
      _currentUserName ??= 'User';
    }
  }

  // ✅ Load pricing data from local cache
  Future<void> _loadPricingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final data = jsonDecode(userDataString) as Map<String, dynamic>;

        // Load user's gender
        _currentUserGender = data['Gender']?.toString().toLowerCase();

        // Load pricing data - use both regular and Tellme versions
        final maleAudio = data['MaleAudio'] ?? data['MaleAudioLiveGup'];
        final maleVideo = data['MaleVideo'] ?? data['MaleVideoLiveGup'];
        final femaleAudio = data['FemaleAudio'] ?? data['FemaleAudioTellme'];
        final femaleVideo = data['FemaleVideo'] ?? data['FemaleVideoTellme'];

        if (maleAudio != null) {
          _maleAudioCost = double.tryParse(maleAudio.toString()) ?? 10;
        }
        if (maleVideo != null) {
          _maleVideoCost = double.tryParse(maleVideo.toString()) ?? 20;
        }
        if (femaleAudio != null) {
          _femaleAudioCost = double.tryParse(femaleAudio.toString()) ?? 8;
        }
        if (femaleVideo != null) {
          _femaleVideoCost = double.tryParse(femaleVideo.toString()) ?? 12;
        }

        print('💰 Call Screen - Loaded pricing data:');
        print('   User Gender: $_currentUserGender');
        print('   Male Audio: $_maleAudioCost, Male Video: $_maleVideoCost');
        print(
          '   Female Audio: $_femaleAudioCost, Female Video: $_femaleVideoCost',
        );
      }
    } catch (e) {
      print('❌ Error loading pricing data: $e');
      // Keep default values if loading fails
    } finally {
      print('✅ _loadPricingData completed');
    }
  }

  void _initializeAnimations() {
    // _pulseController = AnimationController(
    //   duration: const Duration(milliseconds: 2000),
    //   vsync: this,
    // )..repeat(reverse: true);

    // _rotationController = AnimationController(
    //   duration: const Duration(seconds: 30),
    //   vsync: this,
    // )..repeat();

    // _buttonScaleController = AnimationController(
    //   duration: const Duration(milliseconds: 800),
    //   vsync: this,
    // )..repeat(reverse: true);

    // _rippleController = AnimationController(
    //   duration: const Duration(milliseconds: 1500),
    //   vsync: this,
    // )..repeat();

    _GiftModelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
    //   CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    // );

    // _rotationAnimation = Tween<double>(
    //   begin: 0.0,
    //   end: 2 * math.pi,
    // ).animate(_rotationController);

    // _buttonScaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
    //   CurvedAnimation(parent: _buttonScaleController, curve: Curves.easeInOut),
    // );

    // _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    // );
  }

  // ============ Smart Dial: Outgoing Flow ============
  Future<void> _initializeOutgoingFlow() async {
    try {
      // ✅ Check if user has minimum coins to start call
      if (_currentUserGender == null) {
        await _loadCurrentUserName();
      }

      final hasMinCoins = await _HttpService.hasMinimumCoinsForCall(
        widget.isVideoCall,
        _currentUserGender ?? 'male',
      );

      if (!hasMinCoins) {
        final minRequired = 5.0;

        _showLocalEndMessage(
          'Insufficient Coins',
          'You need at least $minRequired coins to start the call.',
          Icons.account_balance_wallet_rounded,
          Colors.orange,
        );
        return;
      }

      // Prepare local media and listeners once
      await Permission.camera.request();
      await Permission.microphone.request();

      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': widget.isVideoCall
            ? {
                'facingMode': _isFrontCamera ? 'user' : 'environment',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      if (widget.isVideoCall) {
        _localRenderer.srcObject = _localStream;
      }

      // 🎧 Route audio smartly: use earphone if connected, else loudspeaker
      await _initAudioRouting();
      _listenForHeadsetChanges();
      setState(() {});

      // Set listeners once
      _VideoCallService.onRemoteStream = (MediaStream stream) async {
        final hasMediaTracks =
            stream.getVideoTracks().isNotEmpty ||
            stream.getAudioTracks().isNotEmpty;

        if (hasMediaTracks) {
          print(
            '📺 Outgoing: Remote stream received with tracks: ${stream.id}',
          );

          // Ensure tracks are enabled
          for (var track in stream.getVideoTracks()) {
            track.enabled = true;
          }
          for (var track in stream.getAudioTracks()) {
            track.enabled = true;
          }

          _remoteRenderer.srcObject = stream;
          _isConnected = true;
          _pickupTimer?.cancel();
        } else {
          print('⚠️ Outgoing: Remote stream received but no tracks found!');
        }

        // ✅ Stop calling tune as soon as remote stream arrives
        await _stopCallingTune();

        setState(() {
          _isConnected = true;
          _roomDeletedByOptimization = true; // ✅ Force optimization flag
          _connectionQuality = ConnectionQuality.excellent;
        });

        // ✅ Update user status to busy when call connects
        await _HttpService.updateUserStatus('busy');

        _startTokenDeduction();
      };

      // Listener handled in initState

      // ✅ Setup VirtualItem listener for outgoing flow as well
      _setupGiftModelListener();

      // ✅ Re-enable face validation for outgoing video calls
      _initializeModeration();

      // Build candidate list: if none provided, use the single receiverToken or targetId
      if (_candidateUsers.isEmpty &&
          ((widget.receiverToken != null && widget.receiverToken!.isNotEmpty) ||
              (widget.targetId != null && widget.targetId!.isNotEmpty))) {
        _candidateUsers = [
          {
            'Name': widget.callerName,
            'Avatar': widget.callerAvatar,
            'Token': widget.receiverToken,
            'uid': widget.targetId,
          },
        ];
      }

      _currentCandidateIndex = 0;
      _attemptCount = 0;
      _startDialForCurrentCandidate();
    } catch (e) {
      _showLocalEndMessage(
        'Error',
        'Failed to initialize call: ${e.toString()}',
        Icons.error_rounded,
        Colors.red,
      );
    }
  }

  Future<void> _startDialForCurrentCandidate() async {
    // ✅ Check if we've exhausted candidates first
    if (_candidateUsers.isEmpty) {
      _showLocalEndMessage(
        'No Answer',
        'Seems like everyone is busy. Try after sometime.',
        Icons.schedule_rounded,
        Colors.orange,
      );
      return;
    }

    if (_currentCandidateIndex >= _candidateUsers.length) {
      _showLocalEndMessage(
        'No Answer',
        'Seems like everyone is busy. Try after sometime.',
        Icons.schedule_rounded,
        Colors.orange,
      );
      return;
    }

    if (_attemptCount >= _maxAttempts) {
      _showLocalEndMessage(
        'No Answer',
        'Seems like everyone is busy. Try after sometime.',
        Icons.schedule_rounded,
        Colors.orange,
      );
      return;
    }

    final candidate = _candidateUsers[_currentCandidateIndex];
    _currentReceiverToken = candidate['Token']?.toString();

    // Update display name/avatar for this attempt
    setState(() {
      _currentCalleeName = candidate['Name']?.toString() ?? widget.callerName;
      _currentCalleeAvatar =
          candidate['Avatar']?.toString() ?? widget.callerAvatar;
    });

    _currentRoomId =
        'room_${DateTime.now().millisecondsSinceEpoch}_${_currentCandidateIndex + 1}';
    _attemptCount++;

    final targetUid =
        candidate['uid']?.toString() ??
        candidate['Uid']?.toString() ??
        widget.targetId ??
        '';

    print(
      '📞 Attempt $_attemptCount/$_maxAttempts: Dialing ${_currentCalleeName} (UID: $targetUid)',
    );

    // Create offer for this room
    if (_localStream != null) {
      await _VideoCallService.createOffer(
        roomId: _currentRoomId!,
        localStream: _localStream!,
        callerId: _AuthenticationService.currentUser?.uid ?? '',
        callerName: _currentUserName ?? 'User',
        callerAvatar: _currentUserAvatar ?? '',
        targetId: targetUid,
        isVideoCall: widget.isVideoCall,
        callerGender: _currentUserGender ?? 'male',
      );
    }

    // Ensure listeners follow the active room (AFTER creation to avoid null snapshot)
    _attachRoomListeners();

    // Play calling tune
    // await _playCallingTune(); // Temporarily disabled due to invalid asset

    // ✅ Dynamic timeout: 15s for first attempt (manual), 14s for subsequent (random)
    final timeoutSeconds = _currentCandidateIndex == 0
        ? _firstAttemptTimeoutSeconds // 15s for manual call
        : _subsequentAttemptTimeoutSeconds; // 14s for random attempts

    _pickupTimer?.cancel();
    _pickupTimer = Timer(Duration(seconds: timeoutSeconds), () {
      print('⏱️ $timeoutSeconds second timeout fired');
      print(
        '   Connected: $_isConnected, CallEnded: $_callEnded, Mounted: $mounted',
      );

      // ✅ CRITICAL: Check all conditions
      if (!_isConnected && !_callEnded && mounted) {
        print(
          '⏱️ $timeoutSeconds second timeout - No connection from ${_currentCalleeName}, advancing...',
        );
        _advanceToNextCandidate(reason: 'timeout');
      }
    });

    print(
      '⏳ Started $timeoutSeconds second timeout for ${_currentCalleeName} (Attempt ${_currentCandidateIndex + 1})',
    );

    // Send FCM to candidate
    try {
      print('🔍 DEBUG: About to send FCM...');
      final callerData = await _AuthenticationService.getUserData();
      print(
        '🔍 DEBUG: callerData = ${callerData != null ? "NOT NULL" : "NULL"}',
      );
      print('🔍 DEBUG: _currentReceiverToken = $_currentReceiverToken');

      if (_currentReceiverToken != null &&
          _currentReceiverToken!.isNotEmpty &&
          callerData != null) {
        print('📱 Initiating FCM Send to ${_currentCalleeName}...');
        await _fcmSender.sendCallNotification(
          targetToken: _currentReceiverToken!,
          callerData: callerData,
          roomId: _currentRoomId!,
          isVideoCall: widget.isVideoCall,
          targetId: targetUid, // ✅ Pass receiver UID for background handling
        );
        print('📱 FCM sent to ${_currentCalleeName}');
      } else {
        print(
          '❌ FCM NOT SENT - token: $_currentReceiverToken, callerData: ${callerData != null}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error sending FCM: $e');
      print('StackTrace: $stackTrace');
    }
  }

  void _advanceToNextCandidate({required String reason}) {
    print(
      '➡️ _advanceToNextCandidate called - reason: $reason, index: $_currentCandidateIndex/$_candidateUsers.length, attempts: $_attemptCount/$_maxAttempts',
    );

    // ✅ CRITICAL: Stop everything first
    if (_pickupTimer != null) {
      _pickupTimer!.cancel();
      _pickupTimer = null;
      print('✋ Cancelled pickup timer');
    }

    // Stop calling tune BEFORE switching
    _stopCallingTune();

    // ✅ Stop listening to previous room to prevent "Room Deleted" trigger
    _callEndListener?.cancel();
    _callEndListener = null;

    // Clean up previous room doc asynchronously
    final prevRoom = _currentRoomId;
    if (prevRoom != null) {
      () async {
        try {
          await _db.child('calls').child(prevRoom).remove();
          // Also remove from pending_calls
          final prevTargetId = _candidateUsers[_currentCandidateIndex]['uid'];
          await _db
              .child('pending_calls')
              .child(prevTargetId)
              .child(prevRoom)
              .remove();
          print('🗑️ Cleaned up room in Realtime DB: $prevRoom');
        } catch (e) {
          print('⚠️ Error cleaning room: $e');
        }
      }();
    }

    // Move to next candidate
    _currentCandidateIndex++;

    print(
      '📋 Advanced to candidate index: $_currentCandidateIndex (Total: ${_candidateUsers.length})',
    );

    // ✅ Check if we can continue
    if (_currentCandidateIndex < _candidateUsers.length &&
        _attemptCount < _maxAttempts &&
        !_callEnded) {
      print('✅ Proceeding to next candidate immediately...');
      _isConnected = false;

      // ✅ CRITICAL: Call immediately without any delay
      _startDialForCurrentCandidate();
    } else {
      print(
        '❌ Cannot continue - index: $_currentCandidateIndex, length: ${_candidateUsers.length}, attempts: $_attemptCount, maxAttempts: $_maxAttempts, ended: $_callEnded',
      );
      _showLocalEndMessage(
        reason == 'declined' ? 'Declined' : 'No Answer',
        'Seems like everyone is busy. Try after sometime.',
        Icons.schedule_rounded,
        Colors.orange,
      );
    }
  }

  Future<void> _loadTokensFromCache() async {
    try {
      final coins = await _HttpService.getLocalCoins();
      setState(() {
        _currentTokens = coins;
      });
      print('💰 Call Screen: Loaded coins from cache: $_currentTokens');
    } catch (e) {
      print('❌ Error loading tokens from cache: $e');
    }
  }

  void _startTokenDeduction() {
    // ✅ Start call timer
    _startCallTimer();

    // ✅ Cancel any existing timer first
    _coinDeductionTimer?.cancel();

    _coinDeductionTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_callEnded || !mounted) {
        timer.cancel();
        return;
      }

      // ✅ FIRST: Deduct/add coins LOCALLY
      await _handlePeriodicCallCoinsWithCachedPricing();

      // ✅ GET FRESH LOCAL BALANCE
      final newBalance = await _HttpService.getLocalCoins();

      if (mounted) {
        setState(() => _currentTokens = newBalance);
        print('🔄 Local Balance Update: $_currentTokens coins');
      }

      // ✅ THEN: Check if can continue (ONLY Males)
      if (_currentUserGender == 'male') {
        if (_currentTokens <= 0) {
          timer.cancel();
          _showLocalEndMessage(
            'Insufficient Coins',
            'Your coin balance reached 0. Call ended.',
            Icons.account_balance_wallet_rounded,
            Colors.orange,
          );
          await Future.delayed(const Duration(seconds: 2));
          await _endCallWithReasonToRealtime(
            'insufficient_coins',
            'Insufficient coins to continue',
          );
          return;
        }
      }
    });
  }

  Future<void> _handlePeriodicCallCoinsWithCachedPricing() async {
    try {
      if (_currentUserGender == null) {
        await _loadCurrentUserName();
      }

      if (_currentUserGender == null) return;

      await _HttpService.handlePeriodicCallCoins(
        isVideoCall: widget.isVideoCall,
        gender: _currentUserGender!,
      );
    } catch (e) {
      print('❌ Error in periodic coins update: $e');
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = Duration.zero;

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callEnded || !mounted) {
        timer.cancel();
        return;
      }

      if (mounted) {
        setState(() {
          _callDuration = _callDuration + const Duration(seconds: 1);
        });
      }
    });
  }

  // ✅ Format call duration for display
  String _formatCallDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _monitorConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      if (!mounted || _callEnded) return;

      final hasConnection = result != ConnectivityResult.none;

      setState(() {
        _hasInternet = hasConnection;
        if (!hasConnection) {
          _connectionQuality = ConnectionQuality.disconnected;
        }
      });

      if (!hasConnection) {
        _handleConnectionLost();
      }
    });

    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_callEnded) {
        timer.cancel();
        return;
      }

      if (!_hasInternet && _isConnected) {
        _handleConnectionLost();
      }
    });
  }

  // ✅ NEW: Play calling tune
  Future<void> _playCallingTune() async {
    try {
      if (!_isCallingTunePlaying) {
        print('🔔 Attempting to play calling tune from assets/calling.mp3');

        // Set volume to a reasonable level
        await _callingTunePlayer.setVolume(0.7);

        // Set to loop before playing
        await _callingTunePlayer.setReleaseMode(ReleaseMode.loop);

        // Play the calling tune from assets
        await _callingTunePlayer.play(AssetSource('calling.mp3'));

        _isCallingTunePlaying = true;
        print('🔔 Calling tune started successfully - Volume: 0.7, Loop: ON');
      } else {
        print('ℹ️ Calling tune already playing');
      }
    } catch (e) {
      print('❌ Error playing calling tune: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _stopCallingTune() async {
    try {
      print(
        '🛑 _stopCallingTune called - Current state: $_isCallingTunePlaying',
      );

      if (_isCallingTunePlaying) {
        print('🛑 Stopping calling tune...');

        // Stop the audio immediately
        await _callingTunePlayer.stop();
        print('🛑 Audio player stopped');

        // Reset release mode
        await _callingTunePlayer.setReleaseMode(ReleaseMode.stop);
        print('🛑 Release mode set to stop');

        // Set volume to 0 as backup
        await _callingTunePlayer.setVolume(0.0);
        print('🛑 Volume set to 0');

        // Add delay to ensure it fully stops
        await Future.delayed(const Duration(milliseconds: 200));

        _isCallingTunePlaying = false;
        print('✅ Calling tune stopped successfully');
      } else {
        print('ℹ️ Calling tune not playing, nothing to stop');
      }
    } catch (e) {
      print('❌ Error stopping calling tune: $e');
      _isCallingTunePlaying = false;
    }
  }

  Future<void> _handleConnectionLost() async {
    if (_callEnded) return;

    await _endCallWithReasonToRealtime(
      'connection_lost',
      '${_currentUserName ?? "User"}\'s connection was lost',
    );
    _showLocalEndMessage(
      'Connection Lost',
      'Your internet connection was lost.',
      Icons.wifi_off_rounded,
      Colors.red,
    );
  }

  void _initializeModeration() {
    if (!widget.isVideoCall) return;

    _FaceRecognitionService.onFaceDetected = (hasFace) {
      if (mounted && !_isCameraOff && !_callEnded) {
        setState(() {
          _showFaceWarning = !hasFace;
          if (hasFace) {
            _warningCountdown = 45;
            _countdownTimer?.cancel();
          } else {
            _startWarningCountdown();
          }
        });
      }
    };

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _localStream != null && !_callEnded) {
        _FaceRecognitionService.initialize(_localStream!);
      }
    });
  }

  void _startWarningCountdown() {
    _countdownTimer?.cancel();
    _warningCountdown = 15;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_callEnded) {
        setState(() {
          _warningCountdown--;
          if (_warningCountdown <= 0) {
            timer.cancel();
            _endCallDueToNoFace();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _endCallDueToNoFace() async {
    if (_callEnded) return;

    await _endCallWithReasonToRealtime(
      'no_face_detected',
      '${_currentUserName ?? "User"}\'s face was not visible',
    );

    _showLocalEndMessage(
      'Call Ended',
      'No face detected for too long.\n\nPlease ensure your face is visible on camera.',
      Icons.face_retouching_off_rounded,
      Colors.red,
    );
  }

  Future<void> _endCallWithReasonToRealtime(
    String reasonCode,
    String reasonMessage,
  ) async {
    if (_callEnded) return;
    _callEnded = true;
    _locallyEnded = true;

    try {
      if (_roomDeletedByOptimization) {
        print(
          'ℹ️ Skipping RTDB update (reason) because room was deleted by optimization.',
        );
      } else {
        await _db.child('calls').child(_roomIdEffective).update({
          'ended': true,
          'endReasonCode': reasonCode,
          'endReasonMessage': reasonMessage,
          'endedBy': _currentUserName ?? 'User',
          'endedAt': ServerValue.timestamp,
        });
      }

      final token = _receiverTokenEffective;
      if (token != null) {
        await _fcmSender.sendCallEndNotification(
          targetToken: token,
          roomId: _roomIdEffective,
        );
      }

      // ✅ Delete in background without blocking
      _deleteCallRoomInBackground();
    } catch (e) {
      print('❌ Error in _endCallWithReasonToRealtime: $e');
    }

    // ✅ Update user status to active when call ends due to any reason
    await _HttpService.updateUserStatus('online');
  }

  void _showLocalEndMessage(
    String title,
    String message,
    IconData icon,
    Color iconColor,
  ) {
    print('🚫 _showLocalEndMessage: Title=$title, Message=$message');
    if (mounted) {
      // Get parent context BEFORE popping
      final parentContext = Navigator.of(context, rootNavigator: true).context;

      // Pop the call screen
      Navigator.pop(context);

      // Show dialog in PARENT context (not call screen context)
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: parentContext,
          barrierDismissible: false,
          builder: (ctx) => HeroMode(
            enabled: false,
            child: _buildNeumorphicDialog(
              title: title,
              icon: icon,
              iconColor: iconColor,
              message: message,
              buttonText: 'OK',
              buttonColor: iconColor == Colors.orange
                  ? const Color(0xFF667eea)
                  : iconColor,
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        );

        // Cleanup after showing
        Future.delayed(const Duration(milliseconds: 300), () {
          _cleanup();
        });
      });
    }
  }

  Future<void> _initializeCall() async {
    try {
      // ✅ Check if user has minimum coins to start call
      // Only fetch gender if not already loaded to check min coins
      if (_currentUserGender == null) {
        await _loadCurrentUserName();
      }

      final hasMinCoins = await _HttpService.hasMinimumCoinsForCall(
        widget.isVideoCall,
        _currentUserGender ?? 'male',
      );

      if (!hasMinCoins) {
        final minRequired = 5.0;

        _showLocalEndMessage(
          'Insufficient Coins',
          'You need at least $minRequired coins to start the call.',
          Icons.account_balance_wallet_rounded,
          Colors.orange,
        );
        return;
      }

      // ✅ NEW: Play calling tune for incoming call
      await _playCallingTune();

      await Permission.camera.request();
      await Permission.microphone.request();

      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': widget.isVideoCall
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      if (widget.isVideoCall) {
        _localRenderer.srcObject = _localStream;
      }

      // 🎧 Route audio smartly: use earphone if connected, else loudspeaker
      await _initAudioRouting();
      _listenForHeadsetChanges();

      setState(() {});

      _VideoCallService.onRemoteStream = (MediaStream stream) async {
        final hasMediaTracks =
            stream.getVideoTracks().isNotEmpty ||
            stream.getAudioTracks().isNotEmpty;

        if (hasMediaTracks) {
          print('📺 Remote stream received with tracks: ${stream.id}');
          print('📹 Video tracks: ${stream.getVideoTracks().length}');
          print('🔊 Audio tracks: ${stream.getAudioTracks().length}');

          // Ensure tracks are enabled
          for (var track in stream.getVideoTracks()) {
            track.enabled = true;
          }
          for (var track in stream.getAudioTracks()) {
            track.enabled = true;
          }

          _remoteRenderer.srcObject = stream;
        } else {
          print('⚠️ Remote stream received but no tracks found!');
        }

        // ✅ NEW: Stop calling tune when remote stream received (call connects)
        await _stopCallingTune();

        setState(() {
          _isConnected = true;
          _roomDeletedByOptimization = true; // ✅ Force optimization flag
          _connectionQuality = ConnectionQuality.excellent;
        });

        // ✅ Update user status to busy when call connects
        await _HttpService.updateUserStatus('busy');

        _startTokenDeduction(); // ✅ Start coin deduction timer
      };

      _VideoCallService.onConnectionStateChange =
          (RTCIceConnectionState state) async {
            if (!mounted || _callEnded) return;

            setState(() {
              switch (state) {
                case RTCIceConnectionState.RTCIceConnectionStateConnected:
                case RTCIceConnectionState.RTCIceConnectionStateCompleted:
                  _isConnected = true;
                  _roomDeletedByOptimization = true;
                  _connectionQuality = ConnectionQuality.excellent;
                  break;
                case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
                  _connectionQuality = ConnectionQuality.poor;
                  // Fail-safe: If disconnected for too long, end call
                  Timer(const Duration(seconds: 10), () {
                    if (mounted &&
                        !_callEnded &&
                        _connectionQuality == ConnectionQuality.poor) {
                      _handleConnectionLost();
                    }
                  });
                  break;
                case RTCIceConnectionState.RTCIceConnectionStateFailed:
                  _connectionQuality = ConnectionQuality.failed;
                  print('❄️ ICE Failed - Attempting manual ICE restart...');
                  _VideoCallService.restartIce();
                  // Give it 5 seconds to recover, otherwise end call
                  Timer(const Duration(seconds: 5), () {
                    if (_connectionQuality == ConnectionQuality.failed &&
                        !_callEnded) {
                      _handleConnectionLost();
                    }
                  });
                  break;
                case RTCIceConnectionState.RTCIceConnectionStateClosed:
                  print('❄️ ICE Closed - Ending Call');
                  _cleanup();
                  if (mounted) Navigator.pop(context);
                  break;
                default:
                  break;
              }
            });

            // ✅ Stop calling tune when connection established
            if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
                state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
              await _stopCallingTune();
            }
          };

      if (widget.isOutgoing) {
        await _VideoCallService.createOffer(
          roomId: _roomIdEffective,
          localStream: _localStream!,
          callerId: _AuthenticationService.currentUser?.uid ?? '',
          callerName: _currentUserName ?? 'User',
          callerAvatar: _currentUserAvatar ?? '',
          targetId: widget.targetId ?? '',
          isVideoCall: widget.isVideoCall,
          callerGender: _currentUserGender ?? 'male',
        );
      } else {
        await Future.delayed(const Duration(seconds: 1));
        await _VideoCallService.createAnswer(_roomIdEffective, _localStream!);
      }

      _attachRoomListeners();
      _monitorConnectivity();
      _initializeModeration();

      // ✅ Setup VirtualItem listener for incoming calls
      _setupGiftModelListener();
    } catch (e) {
      _showLocalEndMessage(
        'Error',
        'Failed to initialize call: ${e.toString()}',
        Icons.error_rounded,
        Colors.red,
      );
    }
  }

  void _attachRoomListeners() {
    _callEndListener?.cancel();

    _listenForCallEnd();
  }

  void _listenForCallEnd() {
    _callEndListener = _db.child('calls').child(_roomIdEffective).onValue.listen((
      event,
    ) async {
      if (!mounted) return;

      // ✅ NEW: Handle room deletion (null value) implies call ended
      if (event.snapshot.value == null) {
        // If room is deleted BUT we are optimized (connected), IGNORE IT.
        if (_roomDeletedByOptimization) {
          print('ℹ️ Room deleted from DB as expected (Optimization active)');
          return;
        }

        if (!_locallyEnded && !_callEnded) {
          print('📞 Room deleted detected in Realtime DB (Call Ended)');
          _callEnded = true;
          _showLocalEndMessage(
            'Call Ended',
            'Call ended.',
            Icons.call_end_rounded,
            Colors.red,
          );
        }
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // ✅ Check if call was declined
      if (data['status'] == 'declined' && !_locallyEnded && !_callEnded) {
        print('📞 Call declined detected in Realtime DB');

        // If not connected yet and have more candidates, advance
        if (!_isConnected &&
            widget.isOutgoing &&
            _currentCandidateIndex < _candidateUsers.length - 1 &&
            _attemptCount < _maxAttempts) {
          print('📞 Call declined, advancing to next candidate...');
          _pickupTimer?.cancel(); // Cancel timeout timer
          _advanceToNextCandidate(reason: 'declined');
          return; // Don't show message, just advance
        }

        // Otherwise, end the call with declined message
        _callEnded = true;
        _showLocalEndMessage(
          'Call Declined',
          'The call was declined',
          Icons.call_end_rounded,
          Colors.red,
        );
        return;
      }

      if (data['ended'] == true && !_locallyEnded) {
        print('📞 Call ended detected in Realtime DB (remote user ended)');

        // ✅ NEW: Auto-advance if remote user ends and we haven't connected
        if (!_isConnected &&
            widget.isOutgoing &&
            _currentCandidateIndex < _candidateUsers.length - 1 &&
            _attemptCount < _maxAttempts &&
            !_callEnded) {
          print(
            '📞 Remote ended before connection, advancing to next candidate...',
          );
          _callEnded = false; // Reset to allow advance
          _advanceToNextCandidate(reason: 'remote_ended');
          return; // Don't show message, just advance
        }

        _callEnded = true;

        // ✅ Save History for Remote End
        String myName = _currentUserName ?? 'User';
        String myAvatar = _currentUserAvatar ?? '';
        String otherName = widget.isOutgoing ? _displayName : widget.callerName;
        String otherAvatar = widget.isOutgoing
            ? _displayAvatar
            : widget.callerAvatar;

        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final otherUid =
            (widget.isOutgoing ? widget.targetId : widget.remoteUid) ?? '';

        await _HttpService.saveCallHistory(
          roomId: _roomIdEffective,
          callerName: widget.isOutgoing ? myName : otherName,
          receiverName: widget.isOutgoing ? otherName : myName,
          callerId: widget.isOutgoing ? myUid : otherUid,
          receiverId: widget.isOutgoing ? otherUid : myUid,
          callerAvatar: widget.isOutgoing ? myAvatar : otherAvatar,
          receiverAvatar: widget.isOutgoing ? otherAvatar : myAvatar,
          type: widget.isVideoCall ? 'video' : 'audio',
          durationSeconds: _callDuration.inSeconds,
          status: 'completed',
        );

        final endReasonMessage = data['endReasonMessage'] as String?;
        final endReasonCode = data['endReasonCode'] as String?;
        final endedBy = data['endedBy'] as String?;

        String title = 'Call Ended';
        IconData icon = Icons.call_end_rounded;
        Color iconColor = const Color(0xFF667eea);

        if (endReasonCode == 'no_face_detected') {
          title = 'Face Not Visible';
          icon = Icons.face_retouching_off_rounded;
          iconColor = Colors.red;
        } else if (endReasonCode == 'connection_lost') {
          title = 'Connection Lost';
          icon = Icons.wifi_off_rounded;
          iconColor = Colors.red;
        } else if (endReasonCode == 'out_of_tokens') {
          title = 'Out of Coins';
          icon = Icons.account_balance_wallet_rounded;
          iconColor = Colors.orange;
        }

        _showLocalEndMessage(
          title,
          endReasonMessage ?? '$endedBy ended the call',
          icon,
          iconColor,
        );
      }
    });
  }

  void _toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() => _isMuted = !audioTrack.enabled);
    }
  }

  void _toggleCamera() {
    if (_localStream != null && widget.isVideoCall) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
      setState(() {
        _isCameraOff = !videoTrack.enabled;
        if (_isCameraOff) {
          _showFaceWarning = false;
          _countdownTimer?.cancel();
        }
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_localStream != null && widget.isVideoCall) {
      try {
        final videoTrack = _localStream!.getVideoTracks().first;
        await Helper.switchCamera(videoTrack);
        setState(() => _isFrontCamera = !_isFrontCamera);
      } catch (e) {}
    }
  }

  // 🎧 Check if a headset is connected and set audio routing accordingly
  Future<void> _initAudioRouting() async {
    if (kIsWeb) return;
    try {
      final headsetConnected =
          await _audioMethodChannel.invokeMethod<bool>('isHeadsetConnected') ??
          false;

      // If earphones are connected → route to earpiece (not loudspeaker)
      // If no earphones → route to loudspeaker for hands-free
      await Helper.setSpeakerphoneOn(!headsetConnected);
      setState(() => _isSpeakerOn = !headsetConnected);

      print(
        '🎧 Headset connected: $headsetConnected → Speaker: ${!headsetConnected}',
      );
    } catch (e) {
      // Fallback: default to loudspeaker if we can't detect
      await Helper.setSpeakerphoneOn(true);
      setState(() => _isSpeakerOn = true);
      print('⚠️ Could not detect headset, defaulting to loudspeaker: $e');
    }
  }

  // 🎧 Listen for wired headset plug/unplug events
  void _listenForHeadsetChanges() {
    if (kIsWeb) return;
    _headsetSubscription?.cancel();
    _headsetSubscription = _audioEventChannel.receiveBroadcastStream().listen(
      (event) async {
        if (!mounted || _callEnded) return;
        final isPluggedIn = event as bool;
        // When earphones plugged in → disable speaker; when unplugged → enable speaker
        await Helper.setSpeakerphoneOn(!isPluggedIn);
        setState(() => _isSpeakerOn = !isPluggedIn);
        print(
          '🎧 Headset ${isPluggedIn ? "plugged in" : "unplugged"} → Speaker: ${!isPluggedIn}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isPluggedIn
                        ? Icons.headset_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPluggedIn
                        ? 'Audio routed to earphones'
                        : 'Audio routed to speaker',
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
              backgroundColor: isPluggedIn
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF10B981),
            ),
          );
        }
      },
      onError: (e) {
        print('⚠️ Headset event error: $e');
      },
    );
  }

  // Speaker mode toggle method (manual override by user)
  Future<void> _toggleSpeaker() async {
    try {
      if (!kIsWeb) {
        final newSpeakerState = !_isSpeakerOn;
        await Helper.setSpeakerphoneOn(newSpeakerState);
        setState(() => _isSpeakerOn = newSpeakerState);

        // Show feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    newSpeakerState
                        ? Icons.volume_up_rounded
                        : Icons.hearing_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(newSpeakerState ? 'Loudspeaker On' : 'Earpiece On'),
                ],
              ),
              duration: const Duration(milliseconds: 1000),
              behavior: SnackBarBehavior.floating,
              backgroundColor: newSpeakerState
                  ? const Color(0xFF10B981)
                  : const Color(0xFF3B82F6),
            ),
          );
        }
        print(
          '🔊 Speaker mode: ${newSpeakerState ? "Loudspeaker" : "Earpiece"}',
        );
      }
    } catch (e) {
      print('❌ Error toggling speaker: $e');
    }
  }

  void _toggleVideoLayout() {
    setState(() {
      _videoLayout = _videoLayout == VideoLayout.normal
          ? VideoLayout.fullscreen
          : VideoLayout.normal;
    });
  }

  void _deleteCallRoomInBackground() {
    // Don't await - let it run in background
    _deleteCallRoom().catchError((e) {
      print('❌ Background deletion error: $e');
    });
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;
    _locallyEnded = true;

    try {
      if (_roomDeletedByOptimization) {
        print(
          'ℹ️ Skipping RTDB update because room was deleted by optimization.',
        );
      } else {
        await _db.child('calls').child(_roomIdEffective).update({
          'ended': true,
          'endReasonCode': 'manual_end',
          'endReasonMessage': '${_currentUserName ?? "User"} ended the call',
          'endedBy': _currentUserName ?? 'User',
          'endedAt': ServerValue.timestamp,
        });
      }

      final token = _receiverTokenEffective;
      if (token != null) {
        await _fcmSender.sendCallEndNotification(
          targetToken: token,
          roomId: _roomIdEffective,
        );
      }

      // ✅ Delete in background without blocking
      _deleteCallRoomInBackground();
    } catch (e) {
      print('❌ Error in _endCall: $e');
    }

    // ✅ Update user status to active when call ends
    await _HttpService.updateUserStatus('online');

    // ✅ Save Call History
    // Determine names/avatars
    String myName = _currentUserName ?? 'User';
    String myAvatar = _currentUserAvatar ?? '';
    String otherName = widget.isOutgoing ? _displayName : widget.callerName;
    String otherAvatar = widget.isOutgoing
        ? _displayAvatar
        : widget.callerAvatar;

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final otherUid =
        (widget.isOutgoing ? widget.targetId : widget.remoteUid) ?? '';

    await _HttpService.saveCallHistory(
      roomId: _roomIdEffective,
      callerName: widget.isOutgoing ? myName : otherName,
      receiverName: widget.isOutgoing ? otherName : myName,
      callerId: widget.isOutgoing ? myUid : otherUid,
      receiverId: widget.isOutgoing ? otherUid : myUid,
      callerAvatar: widget.isOutgoing ? myAvatar : otherAvatar,
      receiverAvatar: widget.isOutgoing ? otherAvatar : myAvatar,
      type: widget.isVideoCall ? 'video' : 'audio',
      durationSeconds: _callDuration.inSeconds,
      status: 'completed',
    );

    _cleanup();

    if (mounted) Navigator.pop(context);
  }

  void _loadAvailableGiftModels() {
    setState(() {
      _availableGiftModels = VirtualItemCatalog.allGiftModels;
    });
    print(
      '🎁 Loaded ${_availableGiftModels.length} GiftModels in ChilliCallView',
    );
  }

  void _cleanup() {
    if (_cleanupCalled) {
      return;
    }
    _cleanupCalled = true;

    // ✅ Ensure call room is deleted when cleaning up
    _deleteCallRoomInBackground();

    // ✅ Cancel all timers FIRST to stop any ongoing billing
    _coinDeductionTimer?.cancel();
    _coinDeductionTimer = null;
    _callTimer?.cancel();
    _callTimer = null;
    _tokenTimer?.cancel();
    _countdownTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _callEndListener?.cancel();
    _headsetSubscription?.cancel(); // 🎧 Stop headset listener
    _headsetSubscription = null;

    // ✅ NEW: Stop calling tune
    _stopCallingTune();
    _callingTunePlayer.dispose();

    // ✅ Update user status to active when cleaning up (if connected)
    if (_isConnected) {
      _HttpService.updateUserStatus('online').catchError((e) {
        print('⚠️ Error updating status to active: $e');
      });
    }

    _FaceRecognitionService.dispose();
    // _pulseController.dispose();
    // _rotationController.dispose();
    // _buttonScaleController.dispose();
    // _rippleController.dispose();
    _GiftModelAnimationController.dispose();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _VideoCallService.dispose();

    // ✅ Clear isInCall flag when leaving call
    PushReceiver().isInCall = false;
    print('🔓 isInCall flag set to FALSE');
  }

  // Removed _getColorFilter method

  Widget _applyFilterToVideo(Widget videoWidget) {
    // Since filters are removed, this method now just returns the video widget.
    // If filter functionality is ever re-added, this method would need to be updated.
    return videoWidget;
  }

  Widget _buildConnectionIndicator() {
    // Hide top connection indicator until actually connected, since waiting screen handles "Connecting..."
    if (!_isConnected) return const SizedBox.shrink();

    if (_connectionQuality == ConnectionQuality.excellent)
      return const SizedBox.shrink();

    IconData icon;
    Color color;
    String text;

    switch (_connectionQuality) {
      case ConnectionQuality.good:
        icon = Icons.signal_cellular_alt_2_bar_rounded;
        color = Colors.yellow;
        text = 'Good connection';
        break;
      case ConnectionQuality.poor:
        icon = Icons.signal_cellular_alt_1_bar_rounded;
        color = Colors.orange;
        text = 'Weak connection';
        break;
      case ConnectionQuality.disconnected:
        icon = Icons.wifi_off_rounded;
        color = Colors.red;
        text = 'No internet';
        break;
      case ConnectionQuality.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.red;
        text = 'Connection lost';
        break;
      default:
        return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-3, -3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(3, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Build call timer widget
  Widget _buildCallTimer() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isVideoCall
            ? Colors.black.withOpacity(0.7)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            _formatCallDuration(_callDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: _currentTokens < 10
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
        borderRadius: BorderRadius.circular(10), // Square with rounded corners
        boxShadow: [
          BoxShadow(
            color:
                (_currentTokens < 10
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B))
                    .withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '₹$_currentTokens',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_callEnded) {
          await _endCall();
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isVideoCall
                  ? [
                      const Color(0xFF0A1628),
                      const Color(0xFF0F1F3D),
                      const Color(0xFF1A2744),
                    ]
                  : [
                      const Color(0xFF1E3A8A),
                      const Color(0xFF1E40AF),
                      const Color(0xFF2563EB),
                    ],
            ),
          ),
          child: Stack(
            children: [
              if (widget.isVideoCall)
                _videoLayout == VideoLayout.fullscreen
                    ? _buildFullscreenVideo()
                    : _buildNormalVideo()
              else
                _buildAudioVideoCallPage(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side: Connection & Timer
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildConnectionIndicator(),
                              if (_isConnected) ...[
                                const SizedBox(width: 8),
                                _buildCallTimer(),
                              ],
                            ],
                          ),
                          // Right side: Token balance
                          _buildTokenIndicator(),
                        ],
                      ),
                      // Center: Name pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isVideoCall
                                  ? Icons.videocam_rounded
                                  : Icons.phone_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.isVideoCall &&
                  _videoLayout == VideoLayout.normal &&
                  _isConnected)
                Positioned(
                  top: 140,
                  right: 20,
                  child: GestureDetector(
                    onTap: _toggleVideoLayout,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1E40AF).withOpacity(0.4),
                            const Color(0xFF1E3A8A).withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.5),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E40AF).withOpacity(0.4),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: -3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: _localStream != null
                            ? _applyFilterToVideo(
                                RTCVideoView(
                                  _localRenderer,
                                  mirror: _isFrontCamera,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF1E3A8A).withOpacity(0.8),
                                      const Color(0xFF1E40AF).withOpacity(0.6),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam_off_rounded,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              if (_showFaceWarning && widget.isVideoCall && !_isCameraOff)
                Positioned(
                  top: 320,
                  left: 20,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: _showFaceWarning ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.5),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No Face Detected!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Show your face or call ends in $_warningCountdown seconds',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              '$_warningCountdown',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC).withOpacity(0.65),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCallButton(
                              icon: _isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: 'Mute',
                              onPressed: _toggleMute,
                              isActive: _isMuted,
                              activeColor: Colors.white, // Invert on active
                              bgColor: _isMuted ? Colors.white : Colors.white.withOpacity(0.2),
                              iconColor: _isMuted ? Colors.black : Colors.white,
                            ),
                            const SizedBox(width: 16),
                            _buildCallButton(
                              icon: _isSpeakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              label: 'Speaker',
                              onPressed: _toggleSpeaker,
                              isActive: _isSpeakerOn,
                              activeColor: Colors.white,
                              bgColor: _isSpeakerOn ? Colors.white : Colors.white.withOpacity(0.2),
                              iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                            ),

                            if (_isConnected && _currentUserGender == 'male') ...[
                              const SizedBox(width: 16),
                              _buildGiftModelButton(),
                            ],
                            const SizedBox(width: 16),
                            _buildCallButton(
                              icon: Icons.call_end_rounded,
                              label: 'End',
                              onPressed: _endCall,
                              bgColor: const Color(0xFFFF3B30), // Apple Red
                              iconColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildGiftModelMenu(),
              _buildGiftModelAnimationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact icon+label button used in the video-call 2-row control bar
  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    Color? activeColor,
    Color? bgColor,
    Color? iconColor,
  }) {
    final Color resolvedBg =
        bgColor ??
        (isActive
            ? (activeColor ?? Colors.redAccent)
            : Colors.white.withOpacity(0.15));

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: resolvedBg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: resolvedBg.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 26),
      ),
    );
  }

  Widget _buildNeumorphicButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
    Color? backgroundColor,
    Color? activeColor,
  }) {
    final effectiveColor = isActive
        ? (activeColor ?? Colors.red)
        : (backgroundColor ?? const Color(0xFFE8EAF6));

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: backgroundColor != null || isActive
              ? LinearGradient(
                  colors: [effectiveColor, effectiveColor.withOpacity(0.8)],
                )
              : null,
          color: backgroundColor == null && !isActive
              ? const Color(0xFFE8EAF6)
              : null,
          shape: BoxShape.circle,
          boxShadow: [
            if (backgroundColor == null && !isActive) ...[
              BoxShadow(
                color: Colors.white.withOpacity(0.7),
                offset: const Offset(-4, -4),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: const Offset(4, 4),
                blurRadius: 8,
              ),
            ] else ...[
              BoxShadow(
                color: effectiveColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ],
        ),
        child: Icon(
          icon,
          color: backgroundColor != null || isActive
              ? Colors.white
              : const Color(0xFF667eea),
          size: 26,
        ),
      ),
    );
  }

  @override
  void dispose() {
    print('ChilliCallView dispose called');
    WakelockPlus.disable(); // 💡 Allow sleeping again

    // Cleanup notification service
    widget.pushNotificationService.onCallEnded = null;
    widget.pushNotificationService.onCallDeclined = null;
    widget.pushNotificationService.isInCall = false;

    if (!_callEnded) {
      _endCall();
    }

    _cleanup();
    super.dispose();
  }

  // Removed _buildFilterChip method

  Widget _buildNormalVideo() {
    return _isConnected
        ? _applyFilterToVideo(
            // Filter removed
            RTCVideoView(
              _remoteRenderer,
              mirror: false,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
            // _remoteFilter, // Filter removed
          )
        : _buildWaitingScreen();
  }

  Widget _buildFullscreenVideo() {
    return GestureDetector(
      onTap: _toggleVideoLayout,
      child: Stack(
        children: [
          _localStream != null
              ? _applyFilterToVideo(
                  // Filter removed
                  RTCVideoView(
                    _localRenderer,
                    mirror: _isFrontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                  // _currentFilter, // Filter removed
                )
              : Container(color: Colors.grey[900]),
          Positioned(
            top: 140,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.5),
                    child: _isConnected
                        ? _applyFilterToVideo(
                            // Filter removed
                            RTCVideoView(
                              _remoteRenderer,
                              mirror: false,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                            // _remoteFilter, // Filter removed
                          )
                        : Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Blurred background avatar
        if (_displayAvatar.isNotEmpty)
          Image.network(_displayAvatar, fit: BoxFit.cover),
        // 2. Blur effect + gradient overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
        // 3. Main content (Avatar, Name, Connecting Text)
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF06B6D4),
                      Color(0xFF0891B2),
                      Color(0xFF0E7490),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 70,
                    backgroundImage: NetworkImage(_displayAvatar),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Connecting Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.isOutgoing ? 'Calling...' : 'Connecting...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isOutgoing && _candidateUsers.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Attempt ${_attemptCount}/$_maxAttempts',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioVideoCallPage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Blurred background avatar
        if (_displayAvatar.isNotEmpty)
          Image.network(_displayAvatar, fit: BoxFit.cover),
        // 2. Blur effect + gradient overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
        // 3. Main content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Static avatar without animations
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.15),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: CircleAvatar(
                    radius: 90,
                    backgroundImage: NetworkImage(_displayAvatar),
                  ),
                ),
              ),
              if (_isConnected) ...[
                const SizedBox(height: 16),
                _buildCallTimer(),
                const SizedBox(height: 8),
              ],
              if (!_isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.isOutgoing ? 'Calling...' : 'Connecting...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Add this method after existing methods
  Future<void> _sendGiftModel(VirtualItem VirtualItem) async {
    // Check if user is male
    if (_currentUserGender != 'male') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only boys can send GiftModels to girls'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check token balance
    if (_currentTokens < VirtualItem.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need ₹${VirtualItem.cost} (You have ₹$_currentTokens)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Create VirtualItem message
      final giftMessage = VirtualItemMessage(
        GiftModelId: VirtualItem.id,
        senderName: _currentUserName ?? 'User',
        senderAvatar: widget.callerAvatar,
        senderGender: _currentUserGender ?? 'male',
        timestamp: DateTime.now(),
        senderCost: VirtualItem.cost,
        receiverReward: VirtualItem.reward,
      );

      // Send through WebRTC data channel
      final success = await _VideoCallService.sendGiftModel(
        giftMessage.toJson(),
      );

      if (success) {
        // Deduct tokens from sender
        await _HttpService.updateLocalCoins(VirtualItem.cost, isDeduction: true);
        final newBalance = await _HttpService.getLocalCoins();

        // Update UI
        setState(() {
          _currentTokens = newBalance;
          _showGiftModelMenu = false;
          _GiftModelHistory.add({
            'VirtualItem': VirtualItem,
            'timestamp': DateTime.now(),
            'type': 'sent',
          });
        });

        // Show success animation
        _showGiftModelSentAnimation(VirtualItem);

        // Broadcast the update
        DataBridge.broadcastTokenUpdate(newBalance);
        print(
          '🎁 VirtualItem sent: ${VirtualItem.name} (${VirtualItem.emoji}) - Cost: ${VirtualItem.cost} tokens',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send VirtualItem. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending VirtualItem: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error sending VirtualItem'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleGiftModelReceived(
    VirtualItem VirtualItem,
    VirtualItemMessage GiftModelMsg,
  ) async {
    if (!mounted || _callEnded) return;

    // Add reward tokens for female receiver
    if (_currentUserGender == 'female') {
      // Add reward using proper addition (not doubling)
      await _HttpService.updateLocalCoins(VirtualItem.reward, isDeduction: false);
      final newBalance = await _HttpService.getLocalCoins();

      // Update UI
      setState(() {
        _currentTokens = newBalance;
        _GiftModelHistory.add({
          'VirtualItem': VirtualItem,
          'timestamp': DateTime.now(),
          'type': 'received',
          'sender': GiftModelMsg.senderName,
        });
      });

      // Broadcast the update
      DataBridge.broadcastTokenUpdate(newBalance);
      print(
        '🎁 Reward received: +₹${VirtualItem.reward}, New balance: ₹$newBalance',
      );
    }

    // Show VirtualItem received animation
    _showGiftModelReceivedAnimation(VirtualItem, GiftModelMsg);
  }

  void _showGiftModelSentAnimation(VirtualItem VirtualItem) {
    setState(() {
      _currentAnimatingGiftModel = VirtualItem;
      _currentGiftModelSenderName = 'You';
    });

    _GiftModelAnimationController.forward(from: 0.0);

    // Hide after animation
    Future.delayed(VirtualItemAnimation.getDuration(VirtualItem.animation), () {
      if (mounted) {
        setState(() {
          _currentAnimatingGiftModel = null;
          _currentGiftModelSenderName = null;
        });
      }
    });
  }

  void _showGiftModelReceivedAnimation(
    VirtualItem VirtualItem,
    VirtualItemMessage GiftModelMsg,
  ) {
    setState(() {
      _currentAnimatingGiftModel = VirtualItem;
      _currentGiftModelSenderName = GiftModelMsg.senderName;
    });

    _GiftModelAnimationController.forward(from: 0.0);

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(VirtualItem.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${GiftModelMsg.senderName} sent you a ${VirtualItem.name}!',
                  ),
                  if (_currentUserGender == 'female')
                    Text(
                      '+₹${VirtualItem.reward} earned',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C2C2C),
        duration: const Duration(seconds: 3),
      ),
    );

    // Hide after animation
    Future.delayed(VirtualItemAnimation.getDuration(VirtualItem.animation), () {
      if (mounted) {
        setState(() {
          _currentAnimatingGiftModel = null;
          _currentGiftModelSenderName = null;
        });
      }
    });
  }

  // Update _initializeOutgoingFlow or _initializeIncomingFlow to add VirtualItem listener
  void _setupGiftModelListener() {
    _VideoCallService.onMessageReceived = (String message) {
      try {
        // Check if it's a VirtualItem message
        if (message.contains('"type":"VirtualItem"')) {
          final GiftModelMsg = VirtualItemMessage.fromJson(message);
          final VirtualItem = VirtualItemCatalog.getGiftModelById(
            GiftModelMsg.GiftModelId,
          );
          if (VirtualItem != null) {
            _handleGiftModelReceived(VirtualItem, GiftModelMsg);
          }
        }
      } catch (e) {
        print('Error parsing message: $e');
      }
    };
  }

  // ===================== GiftModeling UI Components =====================
  Widget _buildGiftModelButton() {
    return GestureDetector(
      onTap: () => setState(() => _showGiftModelMenu = !_showGiftModelMenu),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1E40AF)],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF60A5FA).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF1E40AF).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          ],
        ),
        child: const Center(child: Text('🎁', style: TextStyle(fontSize: 26))),
      ),
    );
  }

  Widget _buildGiftModelMenu() {
    if (!_showGiftModelMenu) return const SizedBox.shrink();

    final GiftModels = _availableGiftModels;
    print(
      '🎁 Building VirtualItem menu - GiftModels count: ${GiftModels.length}, connected: $_isConnected',
    );

    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showGiftModelMenu ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E40AF).withOpacity(0.95),
                const Color(0xFF1E3A8A).withOpacity(0.92),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF60A5FA).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E40AF).withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Send a VirtualItem',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => setState(() => _showGiftModelMenu = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (GiftModels.isEmpty)
                Container(
                  height: 96,
                  alignment: Alignment.center,
                  child: Text(
                    'Loading GiftModels...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: GiftModels.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) {
                      final g = GiftModels[i];
                      final affordable = _currentTokens >= g.cost;
                      return Opacity(
                        opacity: affordable ? 1.0 : 0.5,
                        child: InkWell(
                          onTap: affordable ? () => _sendGiftModel(g) : null,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 92,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  g.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  g.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF60A5FA),
                                        Color(0xFF3B82F6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '₹${g.cost}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
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
        ),
      ),
    );
  }

  Widget _buildGiftModelAnimationOverlay() {
    if (_currentAnimatingGiftModel == null) return const SizedBox.shrink();

    final VirtualItem = _currentAnimatingGiftModel!;
    final sender = _currentGiftModelSenderName ?? '';

    // Simple slide + fade + scale animation using one controller
    final animation = CurvedAnimation(
      parent: _GiftModelAnimationController,
      curve: Curves.easeOut,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final dy = 60.0 * (1 - animation.value);
            final scale = 0.7 + 0.3 * animation.value;
            final opacity = animation.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(VirtualItem.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sender.isEmpty
                            ? 'VirtualItem sent'
                            : '$sender sent a ${VirtualItem.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${VirtualItem.name} • ₹${VirtualItem.cost}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String message,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onPressed,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.7),
              offset: const Offset(-6, -6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.7),
                    offset: const Offset(-3, -3),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    offset: const Offset(3, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[900],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


