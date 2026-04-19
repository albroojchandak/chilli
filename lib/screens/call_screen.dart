import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/push_receiver.dart';
import '../services/peer_session.dart';
import '../services/notif_transmitter.dart';
import '../services/data_bridge.dart';
import '../services/biometric_scanner.dart';
import '../services/identity_manager.dart';
import '../models/virtual_item.dart';

enum ConnectionQuality { excellent, good, poor, disconnected, failed }

enum VideoLayout { normal, fullscreen }

class CallScreen extends StatefulWidget {
  final String roomId;
  final String callerName;
  final String callerAvatar;
  final bool isOutgoing;
  final bool isVideoCall;
  final String? receiverToken;
  final String? targetId;
  final String? remoteUid;
  final PushReceiver pushReceiver;
  final List<Map<String, dynamic>>?
  candidateUsers;

  const CallScreen({
    super.key,
    required this.roomId,
    required this.callerName,
    required this.callerAvatar,
    this.isOutgoing = false,
    this.isVideoCall = true,
    this.receiverToken,
    this.targetId,
    this.remoteUid,
    required this.pushReceiver,
    this.candidateUsers,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final PeerSessionController _peerSessionController = PeerSessionController();
  final NotificationTransmitter _fcmSender = NotificationTransmitter();
  final IdentityManager _identityManager = IdentityManager();
  final DataBridge _dataBridge =
      DataBridge();
  final _db = FirebaseDatabase.instance.ref();
  final BiometricScanner _biometricScanner =
      BiometricScanner();

  MediaStream? _localStream;
  bool _callEnded = false;
  bool _locallyEnded = false;
  bool _cleanupCalled = false;
  bool _isConnected = false;
  bool _hasInternet = true;
  bool _isDeleted = false;
  bool _roomDeletedByOptimization = false;

  Timer? _tokenTimer;
  num _currentTokens = 0;
  Timer? _coinDeductionTimer;

  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  late AudioPlayer _callingTunePlayer;
  bool _isCallingTunePlaying = false;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isSpeakerOn =
      true;

  bool _showFaceWarning = false;
  int _warningCountdown = 45;

  ConnectionQuality _connectionQuality = ConnectionQuality.good;
  VideoLayout _videoLayout = VideoLayout.normal;

  String? _currentRoomId;
  String? _currentReceiverToken;
  List<Map<String, dynamic>> _candidateUsers = const [];
  int _currentCandidateIndex = 0;
  int _attemptCount = 0;
  static const int _maxAttempts = 5;
  static const int _firstAttemptTimeoutSeconds =
      16;
  static const int _subsequentAttemptTimeoutSeconds =
      16;
  Timer? _pickupTimer;

  String? _currentCalleeName;
  String? _currentCalleeAvatar;
  Timer? _countdownTimer;
  Timer? _connectionCheckTimer;
  StreamSubscription<DatabaseEvent>? _callEndListener;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

late AnimationController _giftAnimationController;

String? _currentUserName;
  String? _currentUserEmail;
  String? _currentUserAvatar;

  String get _roomIdEffective => _currentRoomId ?? widget.roomId;
  String? get _receiverTokenEffective =>
      _currentReceiverToken ?? widget.receiverToken;
  String get _displayName => widget.isOutgoing
      ? (_currentCalleeName ?? widget.callerName)
      : widget.callerName;
  String get _displayAvatar => widget.isOutgoing
      ? (_currentCalleeAvatar ?? widget.callerAvatar)
      : widget.callerAvatar;

  double _maleAudioCost = 5;
  double _maleVideoCost = 10;
  double _femaleAudioCost = 1;
  double _femaleVideoCost = 1;
  String? _currentUserGender;

  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);

  bool _showGiftMenu = false;
  List<ChilliGift> _availableGifts = [];
  final List<Map<String, dynamic>> _giftHistory = [];
  ChilliGift? _currentAnimatingGift;
  String? _currentGiftSenderName;

  static const _audioMethodChannel = MethodChannel('audio_route/check');
  static const _audioEventChannel = EventChannel('audio_route/events');
  StreamSubscription<dynamic>? _headsetSubscription;

  @override
  void initState() {
    super.initState();
    widget.pushReceiver.isInCall =
        true;
    _callingTunePlayer = AudioPlayer();

    widget.pushReceiver.onCallEnded = (roomId) {
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

    _peerSessionController.onConnectionStateChange = (state) async {
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
            _peerSessionController.triggerIceRestart();

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

    WakelockPlus.enable();
    _initCallData();
  }

  Future<void> _deleteCallRoom() async {
    if (_isDeleted) return;
    _isDeleted = true;

    try {
      print('🗑️ Deleting call room in Realtime DB: ${_roomIdEffective}');

      await _db.child('calls').child(_roomIdEffective).remove();

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
    _loadAvailableGifts();

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

  void _loadAvailableGifts() {
    setState(() {
      _availableGifts = GiftRegistry.catalog;
    });
  }

  bool _depsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsInitialized) return;
    _depsInitialized = true;
    _initializeAnimations();

    if (widget.candidateUsers != null && widget.candidateUsers!.isNotEmpty) {
      _candidateUsers = widget.candidateUsers!;
    } else {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is Map && routeArgs['candidateUsers'] is List) {
        _candidateUsers = List<Map<String, dynamic>>.from(
          routeArgs['candidateUsers'] as List,
        );
      }
    }
  }

  Future<void> _loadCurrentUserName() async {
    try {

      final prefs = await SharedPreferences.getInstance();
      final profileRecord = prefs.getString('user_data');
      if (profileRecord != null) {
        final data = jsonDecode(profileRecord);
        _currentUserName = data['name'] ?? data['username'] ?? 'User';
        _currentUserEmail = data['email'] ?? data['Email'] ?? '';
        _currentUserAvatar = data['Avatar'] ?? data['avatarUrl'] ?? '';
      }

      final fsData = await _identityManager.loadProfile();
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

  Future<void> _loadPricingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final data = jsonDecode(userDataString) as Map<String, dynamic>;

        _currentUserGender = data['Gender']?.toString().toLowerCase();

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

    } finally {
      print('✅ _loadPricingData completed');
    }
  }

  void _initializeAnimations() {

    _giftAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

}

  Future<void> _initializeOutgoingFlow() async {
    try {

      if (_currentUserGender == null) {
        await _loadCurrentUserName();
      }

      final hasMinCoins = await _dataBridge.hasMinimumBalance(
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

      await _initAudioRouting();
      _listenForHeadsetChanges();
      setState(() {});

      _peerSessionController.onRemoteStream = (MediaStream stream) async {
        final hasMediaTracks =
            stream.getVideoTracks().isNotEmpty ||
            stream.getAudioTracks().isNotEmpty;

        if (hasMediaTracks) {
          print(
            '📺 Outgoing: Remote stream received with tracks: ${stream.id}',
          );

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

        await _stopCallingTune();

        setState(() {
          _isConnected = true;
          _roomDeletedByOptimization = true;
          _connectionQuality = ConnectionQuality.excellent;
        });

        await _dataBridge.updateUserStatus('busy');

        _startTokenDeduction();
      };

_setupGiftListener();

      _initializeModeration();

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

    if (_localStream != null) {
      await _peerSessionController.initiateOffer(
        roomId: _currentRoomId!,
        localStream: _localStream!,
        callerId: _identityManager.activeUser?.uid ?? '',
        callerName: _currentUserName ?? 'User',
        callerAvatar: _currentUserAvatar ?? '',
        targetId: targetUid,
        isVideoCall: widget.isVideoCall,
        callerGender: _currentUserGender ?? 'male',
      );
    }

    _attachRoomListeners();

final timeoutSeconds = _currentCandidateIndex == 0
        ? _firstAttemptTimeoutSeconds
        : _subsequentAttemptTimeoutSeconds;

    _pickupTimer?.cancel();
    _pickupTimer = Timer(Duration(seconds: timeoutSeconds), () {
      print('⏱️ $timeoutSeconds second timeout fired');
      print(
        '   Connected: $_isConnected, CallEnded: $_callEnded, Mounted: $mounted',
      );

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

    try {
      print('🔍 DEBUG: About to send FCM...');
      final callerData = await _identityManager.loadProfile();
      print(
        '🔍 DEBUG: callerData = ${callerData != null ? "NOT NULL" : "NULL"}',
      );
      print('🔍 DEBUG: _currentReceiverToken = $_currentReceiverToken');

      if (_currentReceiverToken != null &&
          _currentReceiverToken!.isNotEmpty &&
          callerData != null) {
        print('📱 Initiating FCM Send to ${_currentCalleeName}...');
        await _fcmSender.dispatchCallInvite(
          targetToken: _currentReceiverToken!,
          callerData: callerData,
          roomId: _currentRoomId!,
          isVideoCall: widget.isVideoCall,
          targetId: targetUid,
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

    if (_pickupTimer != null) {
      _pickupTimer!.cancel();
      _pickupTimer = null;
      print('✋ Cancelled pickup timer');
    }

    _stopCallingTune();

    _callEndListener?.cancel();
    _callEndListener = null;

    final prevRoom = _currentRoomId;
    if (prevRoom != null) {
      () async {
        try {
          await _db.child('calls').child(prevRoom).remove();

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

    _currentCandidateIndex++;

    print(
      '📋 Advanced to candidate index: $_currentCandidateIndex (Total: ${_candidateUsers.length})',
    );

    if (_currentCandidateIndex < _candidateUsers.length &&
        _attemptCount < _maxAttempts &&
        !_callEnded) {
      print('✅ Proceeding to next candidate immediately...');
      _isConnected = false;

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
      final coins = await _dataBridge.getLocalCoins();
      setState(() {
        _currentTokens = coins;
      });
      print('💰 Call Screen: Loaded coins from cache: $_currentTokens');
    } catch (e) {
      print('❌ Error loading tokens from cache: $e');
    }
  }

  void _startTokenDeduction() {

    _startCallTimer();

    _coinDeductionTimer?.cancel();

    _coinDeductionTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_callEnded || !mounted) {
        timer.cancel();
        return;
      }

      await _handlePeriodicCallCoinsWithCachedPricing();

      final newBalance = await _dataBridge.getLocalCoins();

      if (mounted) {
        setState(() => _currentTokens = newBalance);
        print('🔄 Local Balance Update: $_currentTokens coins');
      }

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

      await _dataBridge.applyCallBilling(
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

  Future<void> _playCallingTune() async {
    try {
      if (!_isCallingTunePlaying) {
        print('🔔 Attempting to play calling tune from assets/calling.mp3');

        await _callingTunePlayer.setVolume(0.7);

        await _callingTunePlayer.setReleaseMode(ReleaseMode.loop);

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

        await _callingTunePlayer.stop();
        print('🛑 Audio player stopped');

        await _callingTunePlayer.setReleaseMode(ReleaseMode.stop);
        print('🛑 Release mode set to stop');

        await _callingTunePlayer.setVolume(0.0);
        print('🛑 Volume set to 0');

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

    _biometricScanner.onFaceDetected = (hasFace) {
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
        _biometricScanner.beginStreamScan(_localStream!);
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
        await _fcmSender.dispatchCallEnd(
          targetToken: token,
          roomId: _roomIdEffective,
        );
      }

      _deleteCallRoomInBackground();
    } catch (e) {
      print('❌ Error in _endCallWithReasonToRealtime: $e');
    }

    await _dataBridge.updateUserStatus('online');
  }

  void _showLocalEndMessage(
    String title,
    String message,
    IconData icon,
    Color iconColor,
  ) {
    print('🚫 _showLocalEndMessage: Title=$title, Message=$message');
    if (mounted) {

      final parentContext = Navigator.of(context, rootNavigator: true).context;

      Navigator.pop(context);

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

        Future.delayed(const Duration(milliseconds: 300), () {
          _cleanup();
        });
      });
    }
  }

  Future<void> _initializeCall() async {
    try {

if (_currentUserGender == null) {
        await _loadCurrentUserName();
      }

      final hasMinCoins = await _dataBridge.hasMinimumBalance(
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

      await _initAudioRouting();
      _listenForHeadsetChanges();

      setState(() {});

      _peerSessionController.onRemoteStream = (MediaStream stream) async {
        final hasMediaTracks =
            stream.getVideoTracks().isNotEmpty ||
            stream.getAudioTracks().isNotEmpty;

        if (hasMediaTracks) {
          print('📺 Remote stream received with tracks: ${stream.id}');
          print('📹 Video tracks: ${stream.getVideoTracks().length}');
          print('🔊 Audio tracks: ${stream.getAudioTracks().length}');

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

        await _stopCallingTune();

        setState(() {
          _isConnected = true;
          _roomDeletedByOptimization = true;
          _connectionQuality = ConnectionQuality.excellent;
        });

        await _dataBridge.updateUserStatus('busy');

        _startTokenDeduction();
      };

      _peerSessionController.onConnectionStateChange =
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
                  _peerSessionController.triggerIceRestart();

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

      if (widget.isOutgoing) {
        await _peerSessionController.initiateOffer(
          roomId: _roomIdEffective,
          localStream: _localStream!,
          callerId: _identityManager.activeUser?.uid ?? '',
          callerName: _currentUserName ?? 'User',
          callerAvatar: _currentUserAvatar ?? '',
          targetId: widget.targetId ?? '',
          isVideoCall: widget.isVideoCall,
          callerGender: _currentUserGender ?? 'male',
        );
      } else {
        await Future.delayed(const Duration(seconds: 1));
        await _peerSessionController.respondWithAnswer(_roomIdEffective, _localStream!);
      }

      _attachRoomListeners();
      _monitorConnectivity();
      _initializeModeration();

      _setupGiftListener();
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

      if (event.snapshot.value == null) {

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

      if (data['status'] == 'declined' && !_locallyEnded && !_callEnded) {
        print('📞 Call declined detected in Realtime DB');

        if (!_isConnected &&
            widget.isOutgoing &&
            _currentCandidateIndex < _candidateUsers.length - 1 &&
            _attemptCount < _maxAttempts) {
          print('📞 Call declined, advancing to next candidate...');
          _pickupTimer?.cancel();
          _advanceToNextCandidate(reason: 'declined');
          return;
        }

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

        if (!_isConnected &&
            widget.isOutgoing &&
            _currentCandidateIndex < _candidateUsers.length - 1 &&
            _attemptCount < _maxAttempts &&
            !_callEnded) {
          print(
            '📞 Remote ended before connection, advancing to next candidate...',
          );
          _callEnded = false;
          _advanceToNextCandidate(reason: 'remote_ended');
          return;
        }

        _callEnded = true;

        String myName = _currentUserName ?? 'User';
        String myAvatar = _currentUserAvatar ?? '';
        String otherName = widget.isOutgoing ? _displayName : widget.callerName;
        String otherAvatar = widget.isOutgoing
            ? _displayAvatar
            : widget.callerAvatar;

        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final otherUid =
            (widget.isOutgoing ? widget.targetId : widget.remoteUid) ?? '';

        await _dataBridge.saveCallHistory(
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

  Future<void> _initAudioRouting() async {
    if (kIsWeb) return;
    try {
      final headsetConnected =
          await _audioMethodChannel.invokeMethod<bool>('isHeadsetConnected') ??
          false;

await Helper.setSpeakerphoneOn(!headsetConnected);
      setState(() => _isSpeakerOn = !headsetConnected);

      print(
        '🎧 Headset connected: $headsetConnected → Speaker: ${!headsetConnected}',
      );
    } catch (e) {

      await Helper.setSpeakerphoneOn(true);
      setState(() => _isSpeakerOn = true);
      print('⚠️ Could not detect headset, defaulting to loudspeaker: $e');
    }
  }

  void _listenForHeadsetChanges() {
    if (kIsWeb) return;
    _headsetSubscription?.cancel();
    _headsetSubscription = _audioEventChannel.receiveBroadcastStream().listen(
      (event) async {
        if (!mounted || _callEnded) return;
        final isPluggedIn = event as bool;

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

  Future<void> _toggleSpeaker() async {
    try {
      if (!kIsWeb) {
        final newSpeakerState = !_isSpeakerOn;
        await Helper.setSpeakerphoneOn(newSpeakerState);
        setState(() => _isSpeakerOn = newSpeakerState);

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
        await _fcmSender.dispatchCallEnd(
          targetToken: token,
          roomId: _roomIdEffective,
        );
      }

      _deleteCallRoomInBackground();
    } catch (e) {
      print('❌ Error in _endCall: $e');
    }

    await _dataBridge.updateUserStatus('online');

String myName = _currentUserName ?? 'User';
    String myAvatar = _currentUserAvatar ?? '';
    String otherName = widget.isOutgoing ? _displayName : widget.callerName;
    String otherAvatar = widget.isOutgoing
        ? _displayAvatar
        : widget.callerAvatar;

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final otherUid =
        (widget.isOutgoing ? widget.targetId : widget.remoteUid) ?? '';

    await _dataBridge.saveCallHistory(
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


  void _cleanup() {
    if (_cleanupCalled) {
      return;
    }
    _cleanupCalled = true;

    _deleteCallRoomInBackground();

    _coinDeductionTimer?.cancel();
    _coinDeductionTimer = null;
    _callTimer?.cancel();
    _callTimer = null;
    _tokenTimer?.cancel();
    _countdownTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _callEndListener?.cancel();
    _headsetSubscription?.cancel();
    _headsetSubscription = null;

    _stopCallingTune();
    _callingTunePlayer.dispose();

    if (_isConnected) {
      _dataBridge.updateUserStatus('online').catchError((e) {
        print('⚠️ Error updating status to active: $e');
      });
    }

    _biometricScanner.release();

_giftAnimationController.dispose();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerSessionController.teardown();

    PushReceiver().isInCall = false;
    print('🔓 isInCall flag set to FALSE');
  }

Widget _applyFilterToVideo(Widget videoWidget) {

return videoWidget;
  }

  Widget _buildConnectionIndicator() {
    if (_connectionQuality == ConnectionQuality.excellent)
      return const SizedBox.shrink();

    IconData icon;
    Color color;
    String text;

    switch (_connectionQuality) {
      case ConnectionQuality.good:
        icon = Icons.signal_cellular_alt_2_bar_rounded;
        color = Colors.yellow;
        text = 'Connecting...';
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

  Widget _buildCallTimer() {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isVideoCall
              ? Colors.black.withOpacity(0.7)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
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
            Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _formatCallDuration(_callDuration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: _currentTokens < 10
            ? const LinearGradient(colors: [Colors.red, Colors.redAccent])
            : const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_currentTokens < 10 ? Colors.red : const Color(0xFF667eea))
                .withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.amber, size: 10),
          const SizedBox(width: 8),
          Text(
            '₹$_currentTokens',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
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

              if (!widget.isVideoCall) ...[
                Positioned(
                  top: -150,
                  left: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.2),
                          const Color(0xFF2563EB).withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -150,
                  child: Container(
                    width: 450,
                    height: 450,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1D4ED8).withOpacity(0.18),
                          const Color(0xFF1E40AF).withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 200,
                  right: 50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF60A5FA).withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.isVideoCall)
                _videoLayout == VideoLayout.fullscreen
                    ? _buildFullscreenVideo()
                    : _buildNormalVideo()
              else
                _buildAudioVideoCallPage(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF3B82F6).withOpacity(0.3),
                                  const Color(0xFF2563EB).withOpacity(0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFF60A5FA).withOpacity(0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF1E40AF,
                                  ).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF60A5FA),
                                        Color(0xFF3B82F6),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.isVideoCall
                                        ? Icons.videocam_rounded
                                        : Icons.phone_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildConnectionIndicator(),
                        ],
                      ),
                      _buildTokenIndicator(),
                    ],
                  ),
                ),
              ),
              if (widget.isVideoCall && _videoLayout == VideoLayout.normal)
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
                bottom: 30,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: widget.isVideoCall

                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCallButton(
                                  icon: _isMuted
                                      ? Icons.mic_off_rounded
                                      : Icons.mic_rounded,
                                  label: _isMuted ? 'Unmute' : 'Mute',
                                  onPressed: _toggleMute,
                                  isActive: _isMuted,
                                  activeColor: Colors.redAccent,
                                ),
                                _buildCallButton(
                                  icon: Icons.call_end_rounded,
                                  label: 'End',
                                  onPressed: _endCall,
                                  bgColor: Colors.red,
                                ),

                                _buildCallButton(
                                  icon: _isSpeakerOn
                                      ? Icons.volume_up_rounded
                                      : Icons.headset_rounded,
                                  label: _isSpeakerOn ? 'Speaker' : 'Earphone',
                                  onPressed: _toggleSpeaker,
                                  isActive: _isSpeakerOn,
                                  activeColor: const Color(0xFF10B981),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (_isConnected &&
                                    _currentUserGender == 'male')
                                  _buildGiftButton()
                                else
                                  const SizedBox(width: 72),
                              ],
                            ),
                          ],
                        )

                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNeumorphicButton(
                              icon: _isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              onPressed: _toggleMute,
                              isActive: _isMuted,
                            ),
                            _buildNeumorphicButton(
                              icon: Icons.call_end_rounded,
                              onPressed: _endCall,
                              backgroundColor: Colors.red,
                            ),

                            _buildNeumorphicButton(
                              icon: _isSpeakerOn
                                  ? Icons.volume_up_rounded
                                  : Icons.headset_rounded,
                              onPressed: _toggleSpeaker,
                              isActive: _isSpeakerOn,
                              activeColor: const Color(0xFF10B981),
                            ),
                            if (_isConnected && _currentUserGender == 'male')
                              _buildGiftButton(),
                          ],
                        ),
                ),
              ),
              _buildGiftMenu(),
              _buildGiftAnimationOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    Color? activeColor,
    Color? bgColor,
  }) {
    final Color resolvedBg =
        bgColor ??
        (isActive
            ? (activeColor ?? Colors.redAccent)
            : Colors.white.withOpacity(0.15));

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: resolvedBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: resolvedBg.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
    print('CallScreen dispose called');
    WakelockPlus.disable();

    widget.pushReceiver.onCallEnded = null;
    widget.pushReceiver.onCallDeclined = null;
    widget.pushReceiver.isInCall = false;

    if (!_callEnded) {
      _endCall();
    }

    _cleanup();
    super.dispose();
  }

Widget _buildNormalVideo() {
    return _isConnected
        ? _applyFilterToVideo(

            RTCVideoView(
              _remoteRenderer,
              mirror: false,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),

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

                  RTCVideoView(
                    _localRenderer,
                    mirror: _isFrontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),

                )
              : Container(color: Colors.grey[900]),
          Positioned(
            top: 140,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.7),
                    offset: const Offset(-4, -4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(4, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _isConnected
                    ? _applyFilterToVideo(

                        RTCVideoView(
                          _remoteRenderer,
                          mirror: false,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),

                      )
                    : Container(color: Colors.grey[900]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.95),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

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
            const SizedBox(height: 35),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Text(
                widget.isOutgoing
                    ? 'Calling ${_displayName}...'
                    : 'Connecting...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (widget.isOutgoing && _candidateUsers.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
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
            if (_isConnected) ...[
              const SizedBox(height: 14),
              _buildCallTimer(),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: const Color(0xFF06B6D4),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioVideoCallPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

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
          const SizedBox(height: 45),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              _displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (_isConnected) ...[
            const SizedBox(height: 16),
            _buildCallTimer(),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? const Color(0xFF10B981)
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isConnected
                                    ? const Color(0xFF10B981)
                                    : Colors.white)
                                .withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isConnected ? 'Connected' : 'Connecting...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (!_isConnected)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendGift(ChilliGift gift) async {
    if (_currentUserGender != 'male') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only boys can send gifts to girls'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_currentTokens < gift.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Need ₹${gift.cost} (You have ₹$_currentTokens)'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final giftMsg = GiftEvent(
        giftId: gift.id,
        senderName: _currentUserName ?? 'User',
        senderAvatar: widget.callerAvatar,
        senderGender: _currentUserGender ?? 'male',
        timestamp: DateTime.now(),
        cost: gift.cost,
        reward: gift.reward,
      );

      final success = await _peerSessionController.transmitVirtualItem(giftMsg.toJson());

      if (success) {
        await _dataBridge.updateLocalCoins(gift.cost, isDeduction: true);
        final newBalance = await _dataBridge.getLocalCoins();

        setState(() {
          _currentTokens = newBalance;
          _showGiftMenu = false;
          _giftHistory.add({'gift': gift, 'timestamp': DateTime.now(), 'type': 'sent'});
        });

        _showGiftSentAnimation(gift);
        DataBridge.broadcastBalance(newBalance);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send gift'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error sending gift'), backgroundColor: Colors.red));
    }
  }

  void _handleGiftReceived(ChilliGift gift, GiftEvent event) async {
    if (!mounted || _callEnded) return;

    if (_currentUserGender == 'female') {
      await _dataBridge.updateLocalCoins(gift.reward, isDeduction: false);
      final newBalance = await _dataBridge.getLocalCoins();

      setState(() {
        _currentTokens = newBalance;
        _giftHistory.add({
          'gift': gift,
          'timestamp': DateTime.now(),
          'type': 'received',
          'sender': event.senderName,
        });
      });

      DataBridge.broadcastBalance(newBalance);
    }
    _showGiftReceivedAnimation(gift, event);
  }

  void _showGiftSentAnimation(ChilliGift gift) {
    setState(() {
      _currentAnimatingGift = gift;
      _currentGiftSenderName = 'You';
    });
    _giftAnimationController.forward(from: 0.0);
    Future.delayed(GiftAnimator.getDuration(gift.animation), () {
      if (mounted) {
        setState(() {
          _currentAnimatingGift = null;
          _currentGiftSenderName = null;
        });
      }
    });
  }

  void _showGiftReceivedAnimation(ChilliGift gift, GiftEvent event) {
    setState(() {
      _currentAnimatingGift = gift;
      _currentGiftSenderName = event.senderName;
    });
    _giftAnimationController.forward(from: 0.0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(gift.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${event.senderName} sent you a ${gift.name}!'),
                  if (_currentUserGender == 'female')
                    Text('+₹${gift.reward} earned', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C2C2C),
        duration: const Duration(seconds: 3),
      ),
    );

    Future.delayed(GiftAnimator.getDuration(gift.animation), () {
      if (mounted) {
        setState(() {
          _currentAnimatingGift = null;
          _currentGiftSenderName = null;
        });
      }
    });
  }

  void _setupGiftListener() {
    _peerSessionController.onMessageReceived = (String message) {
      try {
        if (message.contains('"type":"Gift"')) {
          final event = GiftEvent.fromJson(message);
          final gift = GiftRegistry.find(event.giftId);
          if (gift != null) _handleGiftReceived(gift, event);
        }
      } catch (e) {}
    };
  }

  Widget _buildGiftButton() {
    return InkWell(
      onTap: () => setState(() => _showGiftMenu = !_showGiftMenu),
      borderRadius: BorderRadius.circular(28),
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
          border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: const Center(child: Text('🎁', style: TextStyle(fontSize: 26))),
      ),
    );
  }
   Widget _buildGiftMenu() {
    if (!_showGiftMenu) return const SizedBox.shrink();
    final gifts = _availableGifts;

    return Positioned(
      bottom: 120,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showGiftMenu ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF1E40AF).withOpacity(0.95), const Color(0xFF1E3A8A).withOpacity(0.92)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Send a Gift', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5)),
                    onPressed: () => setState(() => _showGiftMenu = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: gifts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final g = gifts[i];
                    final affordable = _currentTokens >= g.cost;
                    return Opacity(
                      opacity: affordable ? 1.0 : 0.5,
                      child: InkWell(
                        onTap: affordable ? () => _sendGift(g) : null,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 92,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(g.emoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1),
                              const SizedBox(height: 4),
                              Text('₹${g.cost}', style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.w900)),
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
   Widget _buildGiftAnimationOverlay() {
    if (_currentAnimatingGift == null) return const SizedBox.shrink();
    final gift = _currentAnimatingGift!;
    final sender = _currentGiftSenderName ?? '';
    final animation = CurvedAnimation(parent: _giftAnimationController, curve: Curves.easeOut);

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final dy = 60.0 * (1 - animation.value);
            final scale = 0.7 + 0.3 * animation.value;
            return Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, dy), child: Transform.scale(scale: scale, child: child)),
            );
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gift.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sender.isEmpty ? 'Gift Sent' : '$sender sent a ${gift.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('₹${gift.cost} Spice Gift', style: const TextStyle(color: Colors.white70, fontSize: 10)),
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

