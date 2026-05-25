import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:archive/archive.dart';

class VideoCallService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final _db = FirebaseDatabase.instance.ref();

  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceConnectionState state)? onConnectionStateChange;
  Function(String message)? onMessageReceived;
  Function(RTCDataChannelState state)? onDataChannelStateChange;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {'urls': 'stun:global.stun.twilio.com:3478'},
      {'urls': 'stun:stun.services.mozilla.com'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turns:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'max-compat',
    'rtcpMuxPolicy': 'require',
    'iceCandidatePoolSize': 10,
    'sdpSemantics': 'unified-plan',
  };

  // Create Peer Connection and set up listeners
  Future<void> _initPeerConnection(String roomId, bool isCaller) async {
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        print(
          '📺 remote stream: onTrack with stream (Kind: ${event.track.kind})',
        );
        final stream = event.streams[0];
        // Log the tracks in the stream
        for (var track in stream.getTracks()) {
          print(
            '   Track ID: ${track.id}, Kind: ${track.kind}, Enabled: ${track.enabled}',
          );
        }
        onRemoteStream?.call(stream);
      } else {
        print(
          '📺 remote stream: onTrack without streams (isolating track: ${event.track.kind})',
        );
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('❄️ ICE Connection State ($roomId): $state');
      onConnectionStateChange?.call(state);

      // ✅ Delete room after connection is established to save DB space/bandwidth
      // Wait 5 seconds to ensure BOTH parties are connected before cleanup
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        print('✅ P2P Connected. Deleting room $roomId in 5 seconds...');
        Future.delayed(const Duration(seconds: 5), () {
          _db.child('calls').child(roomId).remove();
          print('🗑️ Room $roomId deleted after delay');
        });
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        final path = isCaller ? 'callerCandidates' : 'calleeCandidates';
        // Optimization: Use short keys (c=candidate, m=sdpMid, l=sdpMLineIndex)
        _db.child('calls').child(roomId).child(path).push().set({
          'c': candidate.candidate,
          'm': candidate.sdpMid,
          'l': candidate.sdpMLineIndex,
        });
      }
    };
  }

  // ✅ Create Peer Connection for CHAT ONLY (uses 'chats' node)
  Future<void> _initChatPeerConnection(String roomId, bool isCaller) async {
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('💬 Chat ICE Connection State ($roomId): $state');
      onConnectionStateChange?.call(state);
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        final path = isCaller ? 'callerCandidates' : 'calleeCandidates';
        // Optimization: Short keys for chat candidates too
        _db.child('chats').child(roomId).child(path).push().set({
          'c': candidate.candidate,
          'm': candidate.sdpMid,
          'l': candidate.sdpMLineIndex,
        });
      }
    };
  }

  // Offer Side
  Future<void> createOffer({
    required String roomId,
    required MediaStream localStream,
    required String callerId,
    required String callerName,
    required String callerAvatar,
    required String targetId,
    required bool isVideoCall,
    required String callerGender,
  }) async {
    await _initPeerConnection(roomId, true);

    localStream.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, localStream);
    });

    await _createDataChannel();

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);

    // Compress SDP
    final offerData = {'s': _compress(offer.sdp!), 't': offer.type!};

    final callData = {
      'offer': offerData,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'targetId': targetId,
      'isVideoCall': isVideoCall,
      'callerGender': callerGender.toLowerCase(),
      'status': 'ringing',
      'roomId': roomId,
      'createdAt': ServerValue.timestamp,
    };

    await _db.child('calls').child(roomId).set(callData);
    // ✅ Also write to pending_calls for the target user to listen
    await _db
        .child('pending_calls')
        .child(targetId)
        .child(roomId)
        .set(callData);

    // Listen for Answer (Compressed)
    _db.child('calls').child(roomId).child('answer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('📞 Received answer, setting remote description');

      // Decompress SDP
      String sdp = _decompress(data['s']);
      String type = data['t'];

      RTCSessionDescription answer = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(answer);
    });

    // Listen for Callee Candidates
    _listenForCandidates(roomId, 'calleeCandidates');
  }

  void _listenForCandidates(String roomId, String path) {
    _db.child('calls').child(roomId).child(path).onChildAdded.listen((event) {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      // Handle legacy (full keys) or new (short keys)
      String? candidate = data['c'] ?? data['candidate'];
      String? sdpMid = data['m'] ?? data['sdpMid'];
      int? sdpMLineIndex = data['l'] ?? data['sdpMLineIndex'];

      print('❄️ Adding $path remote candidate');
      _peerConnection!
          .addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex))
          .catchError((e) {
            print('❌ Error adding candidate: $e');
          });
    });
  }

  // Answer Side
  Future<void> createAnswer(String roomId, MediaStream localStream) async {
    await _initPeerConnection(roomId, false);

    localStream.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, localStream);
    });

    _setupAnswerDataChannel();

    _db.child('calls').child(roomId).child('offer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('📞 Received offer, creating answer...');

      // Decompress SDP
      String sdp = _decompress(data['s']);
      String type = data['t'];

      RTCSessionDescription offer = RTCSessionDescription(sdp, type);

      await _peerConnection!.setRemoteDescription(offer);

      RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(answer);

      // Compress Answer SDP
      await _db.child('calls').child(roomId).update({
        'answer': {'s': _compress(answer.sdp!), 't': answer.type!},
        'status': 'answered',
      });

      // Listen for Caller Candidates
      _listenForCandidates(roomId, 'callerCandidates');
    });
  }

  void restartIce() {
    _peerConnection?.createOffer({'iceRestart': true}).then((offer) {
      _peerConnection?.setLocalDescription(offer);
    });
  }

  // ✅ Chat-only offer (no media, just data channel)
  Future<void> createChatOnlyOffer({
    required String roomId,
    required String senderName,
    required String senderAvatar,
    required String targetId,
  }) async {
    await _initChatPeerConnection(roomId, true);
    await _createDataChannel();

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(offer);

    final chatData = {
      'offer': {'s': _compress(offer.sdp!), 't': offer.type!},
      'status': 'waiting',
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderUid': FirebaseAuth.instance.currentUser?.uid, // ✅ Added senderUid
      'targetId': targetId,
      'roomId': roomId,
      'createdAt': ServerValue.timestamp,
    };

    await _db.child('chats').child(roomId).set(chatData);
    // ✅ Also write to pending_chats for the target user to listen
    await _db
        .child('pending_chats')
        .child(targetId)
        .child(roomId)
        .set(chatData);

    // Listen for Answer
    _db.child('chats').child(roomId).child('answer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('💬 Received chat answer, setting remote description');

      String sdp = _decompress(data['s']);
      String type = data['t'];
      RTCSessionDescription answer = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(answer);
    });

    // Listen for Callee Candidates (short keys handled inside)
    _listenForChatCandidates(roomId, 'calleeCandidates');
  }

  // ✅ Chat-only answer (no media, just data channel)
  Future<void> createChatOnlyAnswer(String roomId) async {
    await _initChatPeerConnection(roomId, false);
    _setupAnswerDataChannel();

    _db.child('chats').child(roomId).child('offer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) {
        print(
          '⚠️ createChatOnlyAnswer: PeerConnection is null or offer is missing',
        );
        return;
      }

      if (_peerConnection!.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
          _peerConnection!.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        print(
          '⚠️ createChatOnlyAnswer: Signaling state is already ${_peerConnection!.signalingState}, ignoring redundant offer',
        );
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('💬 Received chat offer for room $roomId, creating answer...');

      // Decompress
      String sdp, type;
      if (data.containsKey('s')) {
        sdp = _decompress(data['s']);
        type = data['t'];
      } else {
        // Fallback legacy
        sdp = data['sdp'];
        type = data['type'];
      }

      RTCSessionDescription offer = RTCSessionDescription(sdp, type);

      try {
        await _peerConnection!.setRemoteDescription(offer);
        print('✅ Remote description set for chat');

        RTCSessionDescription answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': false,
          'offerToReceiveVideo': false,
        });
        await _peerConnection!.setLocalDescription(answer);
        print('✅ Local description (answer) set for chat');

        await _db.child('chats').child(roomId).update({
          'answer': {'s': _compress(answer.sdp!), 't': answer.type!},
          'status': 'connected',
        });
        print('✅ Answer uploaded to Realtime DB');

        // Listen for Caller Candidates (for chats node)
        _listenForChatCandidates(roomId, 'callerCandidates');
      } catch (e) {
        print('❌ Error in createChatOnlyAnswer: $e');
      }
    });
  }

  void _listenForChatCandidates(String roomId, String path) {
    _db.child('chats').child(roomId).child(path).onChildAdded.listen((event) {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      String? candidate = data['c'] ?? data['candidate'];
      String? sdpMid = data['m'] ?? data['sdpMid'];
      int? sdpMLineIndex = data['l'] ?? data['sdpMLineIndex'];

      print('💬 Adding chat $path remote candidate');
      _peerConnection!
          .addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex))
          .catchError((e) {
            print('❌ Error adding chat candidate: $e');
          });
    });
  }

  // Data Channel Methods
  Future<void> _createDataChannel() async {
    final dataChannelInit = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 30;

    _dataChannel = await _peerConnection!.createDataChannel(
      'chat',
      dataChannelInit,
    );

    _setupDataChannelListeners();
    print('📡 Data channel created');
  }

  void _setupDataChannelListeners() {
    _dataChannel?.onDataChannelState = (RTCDataChannelState state) {
      print('📡 Data channel state: $state');
      onDataChannelStateChange?.call(state);
    };

    _dataChannel?.onMessage = (RTCDataChannelMessage message) {
      if (!message.isBinary) {
        onMessageReceived?.call(message.text);
      }
    };
  }

  void _setupAnswerDataChannel() {
    _peerConnection?.onDataChannel = (RTCDataChannel channel) {
      print('📡 Received data channel from peer');
      _dataChannel = channel;
      _setupDataChannelListeners();
    };
  }

  Future<bool> sendMessage(String message) async {
    try {
      if (_dataChannel != null &&
          _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannel!.send(RTCDataChannelMessage(message));
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendGiftModel(String GiftModelJson) async {
    return await sendMessage(GiftModelJson);
  }

  void dispose() {
    _dataChannel?.close();
    _dataChannel = null;
    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;
  }

  // ✅ Compression Helper: GZIP + Base64
  String _compress(String input) {
    if (input.isEmpty) return "";
    var bytes = utf8.encode(input);
    var gzipBytes = GZipEncoder().encode(bytes);
    return base64Encode(gzipBytes);
  }

  // ✅ Decompression Helper: Base64 + GZIP
  String _decompress(String? input) {
    if (input == null || input.isEmpty) return "";
    try {
      // Check if it's already plain (legacy support)
      if (input.startsWith('v=0')) return input;

      var gzipBytes = base64Decode(input);
      var bytes = GZipDecoder().decodeBytes(gzipBytes);
      return utf8.decode(bytes);
    } catch (e) {
      // Fallback if not compressed
      return input;
    }
  }
}
