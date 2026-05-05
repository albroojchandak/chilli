import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/push_receiver.dart';
import '../services/peer_session.dart';
import '../services/notif_transmitter.dart';
import '../services/data_bridge.dart';
import '../services/biometric_scanner.dart';
import '../services/identity_manager.dart';
import '../models/virtual_item.dart';

enum ConnectionStateQuality { excellent, good, poor, disconnected, failed }
enum LayoutMode { grid, spotlight }

class ChilliCallView extends StatefulWidget {
  final String roomId;
  final String callerName;
  final String callerAvatar;
  final bool isOutgoing;
  final bool isVideoCall;
  final String? receiverToken;
  final String? targetId;
  final String? remoteUid;
  final PushReceiver pushReceiver;
  final List<Map<String, dynamic>>? candidateUsers;

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
    required this.pushReceiver,
    this.candidateUsers,
  });

  @override
  State<ChilliCallView> createState() => _ChilliCallViewState();
}

class _ChilliCallViewState extends State<ChilliCallView> with TickerProviderStateMixin {
  final RTCVideoRenderer _localProxy = RTCVideoRenderer();
  final RTCVideoRenderer _remoteProxy = RTCVideoRenderer();
  final PeerSessionController _sessionCtrl = PeerSessionController();
  final NotificationTransmitter _signalDispatcher = NotificationTransmitter();
  final IdentityManager _idStore = IdentityManager();
  final DataBridge _bridge = DataBridge();
  final _dbRef = FirebaseDatabase.instance.ref();
  final BiometricScanner _bioScanner = BiometricScanner();

  MediaStream? _localStream;
  bool _isTerminated = false;
  bool _isLocallyTerminated = false;
  bool _hasCleanedUp = false;
  bool _isPipelineActive = false;
  bool _isNetworkAvailable = true;
  bool _isEntryDeleted = false;
  bool _isLeakOptimized = false;

  num _balance = 0;
  Timer? _billingTimer;
  Timer? _metricsTimer;
  Duration _elapsed = Duration.zero;

  late AudioPlayer _audioHarness;
  bool _isAudioPlaying = false;

  bool _isAudioMuted = false;
  bool _isCamHidden = false;
  bool _isSelfieMode = true;
  bool _isLoudspeakerActive = true;

  bool _faceWarningActive = false;
  int _faceGracePeriod = 45;

  ConnectionStateQuality _signalStrength = ConnectionStateQuality.good;
  LayoutMode _viewportMode = LayoutMode.grid;

  String? _activeRoomId;
  String? _activeTargetToken;
  List<Map<String, dynamic>> _targets = const [];
  int _currentTargetIndex = 0;
  int _dialingAttempts = 0;
  static const int _maxRetries = 5;
  Timer? _callRoutingTimer;

  String? _calleeIdentity;
  String? _calleeDisplay;
  Timer? _graceTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<DatabaseEvent>? _syncObserver;
  StreamSubscription<List<ConnectivityResult>>? _netObserver;
  late AnimationController _fxPulse;

  String? _localLabel;
  String? _localEmail;
  String? _localDisplay;
  String? _localGender;

  String get _effectiveRoom => _activeRoomId ?? widget.roomId;
  String? get _effectiveToken => _activeTargetToken ?? widget.receiverToken;
  String get _resolvedName => widget.isOutgoing ? (_calleeIdentity ?? widget.callerName) : widget.callerName;
  String get _resolvedAvatar => widget.isOutgoing ? (_calleeDisplay ?? widget.callerAvatar) : widget.callerAvatar;

  double _audioUnitCost = 5;
  double _videoUnitCost = 10;
  bool _isMenuVisible = false;
  List<ChilliGift> _inventory = [];
  ChilliGift? _activeEffect;
  String? _effectOrigin;

  static const _neonRose = Color(0xFFFF2D78);
  static const _neonIce = Color(0xFF00F5FF);
  static const _glassBase = Color(0xFF0A0A12);

  @override
  void initState() {
    super.initState();
    widget.pushReceiver.isInCall = true;
    _audioHarness = AudioPlayer();
    _sessionCtrl.onConnectionStateChange = _onPeerStateTransition;
    WakelockPlus.enable();
    _initSessionData();
  }

  void _onPeerStateTransition(RTCIceConnectionState state) async {
    if (!mounted || _isTerminated) return;
    setState(() {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _isPipelineActive = true;
          _isLeakOptimized = true;
          _signalStrength = ConnectionStateQuality.excellent;
          _callRoutingTimer?.cancel();
          _killRoutingAudio();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _signalStrength = ConnectionStateQuality.poor;
          if (_isPipelineActive && !_isTerminated && !_isLocallyTerminated) {
            Timer(const Duration(seconds: 4), () {
              if (mounted && !_isTerminated && !_isLocallyTerminated && _signalStrength == ConnectionStateQuality.poor) {
                _handleNetworkFault();
              }
            });
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _signalStrength = ConnectionStateQuality.failed;
          if (!_isTerminated) {
            _sessionCtrl.triggerIceRestart();
            Timer(const Duration(seconds: 4), () {
              if (_signalStrength == ConnectionStateQuality.failed && !_isTerminated) {
                _handleNetworkFault();
              }
            });
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          if (!_isTerminated) {
            _performCleanup();
            if (mounted) Navigator.pop(context);
          }
          break;
        default:
          break;
      }
    });
  }

  Future<void> _initSessionData() async {
    await _syncBalance();
    await _syncLocalProfile();
    await _syncPricing();
    _inventory = GiftRegistry.catalog;
    _fxPulse = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    if (mounted) {
      if (widget.isOutgoing) {
        _startOutgoingSequence();
      } else {
        _bindIncomingSession();
      }
    }
  }

  Future<void> _syncLocalProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blob = prefs.getString('user_data');
      if (blob != null) {
        final data = jsonDecode(blob);
        _localLabel = data['name'] ?? data['username'] ?? 'User';
        _localEmail = data['email'] ?? '';
        _localDisplay = data['Avatar'] ?? data['avatarUrl'] ?? '';
      }
      final cloud = await _idStore.loadProfile();
      if (cloud != null) {
        setState(() {
          _localLabel = cloud['name'] ?? cloud['username'] ?? _localLabel;
          _localDisplay = cloud['avatarUrl'] ?? cloud['Avatar'] ?? _localDisplay;
          _localGender = cloud['gender']?.toString().toLowerCase();
        });
      }
    } catch (_) {}
  }

  Future<void> _syncPricing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blob = prefs.getString('user_data');
      if (blob != null) {
        final data = jsonDecode(blob) as Map<String, dynamic>;
        _localGender = data['Gender']?.toString().toLowerCase();
        final ma = data['MaleAudio'] ?? 10;
        final mv = data['MaleVideo'] ?? 20;
        final fa = data['FemaleAudio'] ?? 8;
        final fv = data['FemaleVideo'] ?? 12;
        _audioUnitCost = double.tryParse(ma.toString()) ?? 10;
        _videoUnitCost = double.tryParse(mv.toString()) ?? 20;
      }
    } catch (_) {}
  }

  Future<void> _startOutgoingSequence() async {
    try {
      final canProceed = await _bridge.hasMinimumBalance(widget.isVideoCall, _localGender ?? 'male');
      if (!canProceed) {
        _haltInternal('Insufficient Coins', 'Balance below minimum threshold.', Icons.account_balance_wallet_rounded, Colors.orange);
        return;
      }

      await [Permission.camera, Permission.microphone].request();
      await _localProxy.initialize();
      await _remoteProxy.initialize();

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.isVideoCall ? {'facingMode': 'user', 'width': 1280, 'height': 720} : false,
      });

      if (widget.isVideoCall) _localProxy.srcObject = _localStream;
      await _configureRouting();

      _sessionCtrl.onRemoteStream = (stream) async {
        if (stream.getVideoTracks().isNotEmpty || stream.getAudioTracks().isNotEmpty) {
          _remoteProxy.srcObject = stream;
          _isPipelineActive = true;
          _callRoutingTimer?.cancel();
        }
        await _killRoutingAudio();
        setState(() {
          _isPipelineActive = true;
          _signalStrength = ConnectionStateQuality.excellent;
        });
        await _bridge.updateUserStatus('busy');
        _invokeMetering();
      };

      _bindGiftEvents();
      _enableModeration();

      if (widget.candidateUsers != null) {
        _targets = widget.candidateUsers!;
      } else {
        _targets = [
          {
            'uid': widget.targetId,
            'Name': widget.callerName,
            'Avatar': widget.callerAvatar,
            'Token': widget.receiverToken,
          }
        ];
      }
      _executeDialing();
    } catch (e) {
      _haltInternal('Error', e.toString(), Icons.error_rounded, Colors.red);
    }
  }

  Future<void> _executeDialing() async {
    if (_targets.isEmpty || _currentTargetIndex >= _targets.length || _dialingAttempts >= _maxRetries) {
      _haltInternal('No Answer', 'Target unavailable at the moment.', Icons.schedule_rounded, Colors.orange);
      return;
    }

    final target = _targets[_currentTargetIndex];
    _activeTargetToken = target['Token']?.toString();
    setState(() {
      _calleeIdentity = target['Name']?.toString() ?? widget.callerName;
      _calleeDisplay = target['Avatar']?.toString() ?? widget.callerAvatar;
    });

    _activeRoomId = 'chilli_${DateTime.now().millisecondsSinceEpoch}_$_dialingAttempts';
    _dialingAttempts++;

    final targetUid = target['uid']?.toString() ?? target['Uid']?.toString() ?? widget.targetId ?? '';

    if (_localStream != null) {
      await _sessionCtrl.initiateOffer(
        roomId: _activeRoomId!,
        localStream: _localStream!,
        callerId: _idStore.activeUser?.uid ?? '',
        callerName: _localLabel ?? 'User',
        callerAvatar: _localDisplay ?? '',
        targetId: targetUid,
        isVideoCall: widget.isVideoCall,
        callerGender: _localGender ?? 'male',
      );
    }

    _bindSyncListeners();
    _callRoutingTimer?.cancel();
    _callRoutingTimer = Timer(const Duration(seconds: 45), () {
      if (!_isPipelineActive && !_isTerminated && mounted) _cycleToNextTarget();
    });

    try {
      final snapshot = await _idStore.loadProfile();
      if (_effectiveToken != null && snapshot != null) {
        await _signalDispatcher.dispatchCallInvite(
          targetToken: _effectiveToken!,
          callerData: snapshot,
          roomId: _activeRoomId!,
          isVideoCall: widget.isVideoCall,
          targetId: targetUid,
        );
      }
    } catch (_) {}
  }

  void _cycleToNextTarget() {
    _callRoutingTimer?.cancel();
    _killRoutingAudio();
    _syncObserver?.cancel();

    if (_activeRoomId != null) {
      final r = _activeRoomId!;
      final t = _targets[_currentTargetIndex]['uid'];
      _dbRef.child('calls').child(r).remove();
      _dbRef.child('pending_calls').child(t).child(r).remove();
    }

    _currentTargetIndex++;
    if (_currentTargetIndex < _targets.length && _dialingAttempts < _maxRetries && !_isTerminated) {
      _isPipelineActive = false;
      _executeDialing();
    } else {
      _haltInternal('No Answer', 'Disconnected from queue.', Icons.schedule_rounded, Colors.orange);
    }
  }

  void _invokeMetering() {
    _startClock();
    _billingTimer?.cancel();
    
    _billingTimer = Timer.periodic(const Duration(seconds: 30), (t) async {
      if (_isTerminated || !mounted) {
        t.cancel();
        return;
      }
      await _performBillingCycle(timer: t);
    });
  }

  Future<void> _performBillingCycle({Timer? timer}) async {
    final gender = _localGender ?? (widget.isOutgoing ? 'male' : 'female');
    await _bridge.applyCallBilling(isVideoCall: widget.isVideoCall, gender: gender);
    final b = await _bridge.getLocalCoins();
    if (mounted) setState(() => _balance = b);
    
    if (gender == 'male' && _balance <= 0) {
      timer?.cancel();
      _billingTimer?.cancel();
      _haltInternal('Insufficient Coins', 'Balance depleted.', Icons.account_balance_wallet_rounded, Colors.orange);
      _shutdownCall(reason: 'insufficient_coins');
    }
  }

  void _startClock() {
    _metricsTimer?.cancel();
    _elapsed = Duration.zero;
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_isTerminated || !mounted) {
        t.cancel();
        return;
      }
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _bindIncomingSession() async {
    try {
      final canProceed = await _bridge.hasMinimumBalance(widget.isVideoCall, _localGender ?? 'male');
      if (!canProceed) {
        _haltInternal('Insufficient Coins', 'Balance below threshold.', Icons.account_balance_wallet_rounded, Colors.orange);
        return;
      }
      await _spawnRoutingAudio();
      await [Permission.camera, Permission.microphone].request();
      await _localProxy.initialize();
      await _remoteProxy.initialize();
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.isVideoCall ? {'facingMode': 'user', 'width': 1280, 'height': 720} : false,
      });
      if (widget.isVideoCall) _localProxy.srcObject = _localStream;
      await _configureRouting();
      _sessionCtrl.onRemoteStream = (stream) async {
        if (stream.getVideoTracks().isNotEmpty || stream.getAudioTracks().isNotEmpty) _remoteProxy.srcObject = stream;
        await _killRoutingAudio();
        setState(() {
          _isPipelineActive = true;
          _signalStrength = ConnectionStateQuality.excellent;
        });
        await _bridge.updateUserStatus('busy');
        _invokeMetering();
      };
      await Future.delayed(const Duration(seconds: 1));
      await _sessionCtrl.respondWithAnswer(_effectiveRoom, _localStream!);
      _bindSyncListeners();
      _enableModeration();
      _bindGiftEvents();
    } catch (e) {
      _haltInternal('Error', e.toString(), Icons.error_rounded, Colors.red);
    }
  }

  void _bindSyncListeners() {
    _syncObserver?.cancel();
    _syncObserver = _dbRef.child('calls').child(_effectiveRoom).onValue.listen((e) async {
      if (!mounted) return;
      if (e.snapshot.value == null) {
        if (!_isLeakOptimized && !_isLocallyTerminated && !_isTerminated) {
          _isTerminated = true;
          _haltInternal('Call Ended', 'Session closed by peer.', Icons.call_end_rounded, Colors.red);
        }
        return;
      }
      final data = Map<String, dynamic>.from(e.snapshot.value as Map);
      if (data['status'] == 'declined' && !_isLocallyTerminated && !_isTerminated) {
        if (!_isPipelineActive && widget.isOutgoing && _currentTargetIndex < _targets.length - 1) {
          _cycleToNextTarget();
          return;
        }
        _isTerminated = true;
        _haltInternal('Declined', 'Target rejected the request.', Icons.call_end_rounded, Colors.red);
        return;
      }
      if (data['ended'] == true && !_isLocallyTerminated) {
        _isTerminated = true;
        await _logHistory();
        _haltInternal('Disconnected', data['endReasonMessage'] ?? 'Call finished.', Icons.call_end_rounded, Colors.blueAccent);
      }
    });
  }

  Future<void> _logHistory() async {
    final self = _localLabel ?? 'User';
    final peer = widget.isOutgoing ? _resolvedName : widget.callerName;
    final selfUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final peerUid = (widget.isOutgoing ? widget.targetId : widget.remoteUid) ?? '';
    await _bridge.saveCallHistory(
      roomId: _effectiveRoom,
      callerName: widget.isOutgoing ? self : peer,
      receiverName: widget.isOutgoing ? peer : self,
      callerId: widget.isOutgoing ? selfUid : peerUid,
      receiverId: widget.isOutgoing ? peerUid : selfUid,
      callerAvatar: widget.isOutgoing ? _localDisplay! : _resolvedAvatar,
      receiverAvatar: widget.isOutgoing ? _resolvedAvatar : _localDisplay!,
      type: widget.isVideoCall ? 'video' : 'audio',
      durationSeconds: _elapsed.inSeconds,
      status: 'completed',
    );
  }

  Future<void> _spawnRoutingAudio() async {
    try {
      if (!_isAudioPlaying) {
        await _audioHarness.setVolume(0.7);
        await _audioHarness.setReleaseMode(ReleaseMode.loop);
        await _audioHarness.play(AssetSource('calling.mp3'));
        _isAudioPlaying = true;
      }
    } catch (_) {}
  }

  Future<void> _killRoutingAudio() async {
    try {
      if (_isAudioPlaying) {
        await _audioHarness.stop();
        _isAudioPlaying = false;
      }
    } catch (_) {}
  }


  void _enableModeration() {
    if (!widget.isVideoCall) return;
    _bioScanner.onFaceDetected = (found) {
      if (mounted && !_isCamHidden && !_isTerminated) {
        setState(() {
          _faceWarningActive = !found;
          if (found) {
            _faceGracePeriod = 15;
            _graceTimer?.cancel();
          } else {
            _fireGraceTimer();
          }
        });
      }
    };
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _localStream != null && !_isTerminated) _bioScanner.beginStreamScan(_localStream!);
    });
  }

  void _fireGraceTimer() {
    _graceTimer?.cancel();
    _faceGracePeriod = 15;
    _graceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && !_isTerminated) {
        setState(() {
          _faceGracePeriod--;
          if (_faceGracePeriod <= 0) {
            t.cancel();
            _onProctorViolation();
          }
        });
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _onProctorViolation() async {
    if (_isTerminated) return;
    await _shutdownCall(reason: 'no_face_detected');
    _haltInternal('Safety Alert', 'Identity verification failed. Session terminated.', Icons.face_retouching_off_rounded, Colors.red);
  }

  void _handleNetworkFault() {
    if (_isTerminated || _isLocallyTerminated) return;
    _isTerminated = true;
    _haltInternal('Connection Lost', 'The network session timed out or was interrupted.', Icons.wifi_off_rounded, Colors.orange);
  }

  Future<void> _shutdownCall({String reason = 'manual_end'}) async {
    if (_isTerminated) return;
    _isTerminated = true;
    _isLocallyTerminated = true;
    try {
      if (!_isLeakOptimized) {
        await _dbRef.child('calls').child(_effectiveRoom).update({
          'ended': true,
          'endReasonCode': reason,
          'endedBy': _localLabel ?? 'User',
          'endedAt': ServerValue.timestamp,
        });
      }
      if (_effectiveToken != null) await _signalDispatcher.dispatchCallEnd(targetToken: _effectiveToken!, roomId: _effectiveRoom);
      _dbRef.child('calls').child(_effectiveRoom).remove();
    } catch (_) {}
    await _bridge.updateUserStatus('online');
    await _logHistory();
    _isTerminated = true; // Set again to be absolutely sure
    _performCleanup();
    if (mounted) Navigator.pop(context);
  }

  void _performCleanup() {
    if (_hasCleanedUp) return;
    _hasCleanedUp = true;
    _billingTimer?.cancel();
    _metricsTimer?.cancel();
    _graceTimer?.cancel();
    _heartbeatTimer?.cancel();
    _netObserver?.cancel();
    _syncObserver?.cancel();
    _killRoutingAudio();
    _audioHarness.dispose();
    _fxPulse.dispose();
    _localStream?.dispose();
    _localProxy.dispose();
    _remoteProxy.dispose();
    _sessionCtrl.teardown();
    _bioScanner.release();
    WakelockPlus.disable();
    widget.pushReceiver.isInCall = false;
  }

  void _toggleAudioStream() {
    if (_localStream != null) {
      final track = _localStream!.getAudioTracks().first;
      track.enabled = !track.enabled;
      setState(() => _isAudioMuted = !track.enabled);
    }
  }

  void _toggleVideoStream() {
    if (_localStream != null && widget.isVideoCall) {
      final track = _localStream!.getVideoTracks().first;
      track.enabled = !track.enabled;
      setState(() {
        _isCamHidden = !track.enabled;
        if (_isCamHidden) {
          _faceWarningActive = false;
          _graceTimer?.cancel();
        }
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_localStream != null && widget.isVideoCall) {
      final track = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(track);
      setState(() => _isSelfieMode = !_isSelfieMode);
    }
  }

  Future<void> _configureRouting() async {
    if (kIsWeb) return;
    try {
      final plugged = await const MethodChannel('audio_route/check').invokeMethod<bool>('isHeadsetConnected') ?? false;
      await Helper.setSpeakerphoneOn(!plugged);
      setState(() => _isLoudspeakerActive = !plugged);
    } catch (_) {
      await Helper.setSpeakerphoneOn(true);
      setState(() => _isLoudspeakerActive = true);
    }
  }

  Future<void> _toggleOutput() async {
    if (!kIsWeb) {
      final s = !_isLoudspeakerActive;
      await Helper.setSpeakerphoneOn(s);
      setState(() => _isLoudspeakerActive = s);
    }
  }

  void _bindGiftEvents() {
    _sessionCtrl.onMessageReceived = (msg) {
      if (msg.contains('"type":"Gift"')) {
        final ev = GiftEvent.fromJson(msg);
        final g = GiftRegistry.find(ev.giftId);
        if (g != null) _spawnEffect(g, ev);
      }
    };
  }

  void _spawnEffect(ChilliGift g, GiftEvent ev) async {
    if (!mounted || _isTerminated) return;
    if (_localGender == 'female') {
      await _bridge.updateLocalCoins(g.reward, isDeduction: false);
      final b = await _bridge.getLocalCoins();
      setState(() => _balance = b);
    }
    setState(() {
      _activeEffect = g;
      _effectOrigin = ev.senderName;
    });
    _fxPulse.forward(from: 0.0);
    Future.delayed(GiftAnimator.getDuration(g.animation), () {
      if (mounted) setState(() {
        _activeEffect = null;
        _effectOrigin = null;
      });
    });
  }

  Future<void> _transmitGift(ChilliGift g) async {
    if (_localGender != 'male') return;
    if (_balance < g.cost) return;
    final ev = GiftEvent(
      giftId: g.id,
      senderName: _localLabel ?? 'User',
      senderAvatar: widget.callerAvatar,
      senderGender: _localGender ?? 'male',
      timestamp: DateTime.now(),
      cost: g.cost,
      reward: g.reward,
    );
    final ok = await _sessionCtrl.transmitVirtualItem(ev.toJson());
    if (ok) {
      await _bridge.updateLocalCoins(g.cost, isDeduction: true);
      final b = await _bridge.getLocalCoins();
      setState(() {
        _balance = b;
        _isMenuVisible = false;
        _activeEffect = g;
        _effectOrigin = 'You';
      });
      _fxPulse.forward(from: 0.0);
      Future.delayed(GiftAnimator.getDuration(g.animation), () {
        if (mounted) setState(() => _activeEffect = null);
      });
    }
  }

  Future<void> _syncBalance() async {
    final b = await _bridge.getLocalCoins();
    setState(() => _balance = b);
  }

  void _haltInternal(String title, String msg, IconData icon, Color color) {
    if (mounted) {
      final root = Navigator.of(context, rootNavigator: true).context;
      Navigator.pop(context);
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(context: root, barrierDismissible: false, builder: (ctx) => _ChilliFeedbackDialog(
          title: title, msg: msg, icon: icon, color: color, onConfirm: () => Navigator.pop(ctx),
        ));
        _performCleanup();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildPrimaryStream(),
          _buildGlassOverlay(),
          _buildEffectLayer(),
          if (_faceWarningActive) _buildFaceNotice(),
          if (_isMenuVisible) _buildGiftHub(),
        ],
      ),
    );
  }

  Widget _buildPrimaryStream() {
    if (!widget.isVideoCall) return _buildAudioLandscape();
    if (!_isPipelineActive) return _buildStaticBackdrop();

    return RTCVideoView(_remoteProxy, mirror: false, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
  }

  Widget _buildAudioLandscape() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F1A), Color(0xFF050508)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPulseAvatar(120),
            const SizedBox(height: 32),
            Text(_resolvedName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            _buildStatusChip(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (_isPipelineActive ? _neonIce : Colors.white).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (_isPipelineActive ? _neonIce : Colors.white).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: _isPipelineActive ? _neonIce : Colors.white54, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(_isPipelineActive ? 'CONNECTED' : 'ENCRYPTING...', style: TextStyle(color: _isPipelineActive ? _neonIce : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildPulseAvatar(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (!_isTerminated) ...List.generate(2, (i) => _Ripple(index: i, color: _neonRose)),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _neonRose.withOpacity(0.5), width: 2),
            image: DecorationImage(image: NetworkImage(_resolvedAvatar), fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticBackdrop() {
    return Stack(
      children: [
        Positioned.fill(child: Image.network(_resolvedAvatar, fit: BoxFit.cover)),
        Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(color: Colors.black.withOpacity(0.6)))),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPulseAvatar(140),
              const SizedBox(height: 40),
              Text(widget.isOutgoing ? 'CONNECTING TO' : 'INCOMING FROM', style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_resolvedName, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -2)),
              const SizedBox(height: 48),
              const CircularProgressIndicator(color: _neonIce, strokeWidth: 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTopHud(),
            const Spacer(),
            if (widget.isVideoCall && _isPipelineActive) _buildSelfSpotlight(),
            const SizedBox(height: 24),
            _buildControlDeck(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHud() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isPipelineActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: _neonIce, size: 14),
                    const SizedBox(width: 8),
                    Text(_formatDuration(_elapsed), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
              ),
          ],
        ),
        _buildWalletTag(),
      ],
    );
  }

  Widget _buildWalletTag() {
    final poor = _balance < 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: poor ? _neonRose.withOpacity(0.2) : Colors.black38,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: poor ? _neonRose.withOpacity(0.5) : Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.toll_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Text(_balance.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSelfSpotlight() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _isCamHidden ? Container(color: Colors.black87, child: const Icon(Icons.videocam_off, color: Colors.white24)) : RTCVideoView(_localProxy, mirror: _isSelfieMode, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
            if (!_isCamHidden)
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _flipCamera,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlDeck() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleButton(icon: _isAudioMuted ? Icons.mic_off_rounded : Icons.mic_rounded, active: _isAudioMuted, color: _neonRose, onTap: _toggleAudioStream),
          if (widget.isVideoCall) _buildCircleButton(icon: _isCamHidden ? Icons.videocam_off_rounded : Icons.videocam_rounded, active: _isCamHidden, color: _neonRose, onTap: _toggleVideoStream),
          _buildEndButton(),
          _buildCircleButton(icon: _isLoudspeakerActive ? Icons.volume_up_rounded : Icons.volume_off_rounded, active: !_isLoudspeakerActive, color: _neonIce, onTap: _toggleOutput),
          if (_localGender == 'male' && _isPipelineActive) _buildCircleButton(icon: Icons.card_giftcard_rounded, active: _isMenuVisible, color: _neonIce, onTap: () => setState(() => _isMenuVisible = !_isMenuVisible)),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required bool active, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: active ? color : Colors.white10, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildEndButton() {
    return GestureDetector(
      onTap: () => _shutdownCall(),
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(color: _neonRose, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _neonRose, blurRadius: 20, spreadRadius: -5)]),
        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildFaceNotice() {
    return Positioned(
      top: 100,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _neonRose.withOpacity(0.9), borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FACE NOT DETECTED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('Moving out of frame ends call in $_faceGracePeriod s', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftHub() {
    return Positioned(
      bottom: 120,
      left: 24,
      right: 24,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.9), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white12)),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _inventory.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, i) {
            final g = _inventory[i];
            return GestureDetector(
              onTap: () => _transmitGift(g),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
                    child: Center(child: Text(g.emoji, style: const TextStyle(fontSize: 32))),
                  ),
                  const SizedBox(height: 8),
                  Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('₹${g.cost.toStringAsFixed(2)}', style: const TextStyle(color: _neonIce, fontSize: 12, fontWeight: FontWeight.w900)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEffectLayer() {
    if (_activeEffect == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fxPulse,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_activeEffect!.emoji, style: const TextStyle(fontSize: 100)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                child: Text('${_effectOrigin == 'You' ? "You sent" : "$_effectOrigin sent"} ${_activeEffect!.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String p(int n) => n.toString().padLeft(2, "0");
    return "${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}";
  }
}

class _Ripple extends StatefulWidget {
  final int index;
  final Color color;
  const _Ripple({required this.index, required this.color});

  @override
  State<_Ripple> createState() => _RippleState();
}

class _RippleState extends State<_Ripple> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final progress = (_ctrl.value + (widget.index * 0.5)) % 1.0;
        return Container(
          width: 120 + (progress * 150),
          height: 120 + (progress * 150),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color.withOpacity(1 - progress), width: 2 - progress)),
        );
      },
    );
  }
}

class _ChilliFeedbackDialog extends StatelessWidget {
  final String title, msg, buttonText;
  final IconData icon;
  final Color color;
  final VoidCallback onConfirm;

  const _ChilliFeedbackDialog({
    required this.title,
    required this.msg,
    required this.icon,
    required this.color,
    required this.onConfirm,
    this.buttonText = "DISMISS",
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: const Color(0xFF151525).withOpacity(0.9), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 48)),
              const SizedBox(height: 24),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
