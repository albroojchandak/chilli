import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:archive/archive.dart';

class PeerSessionController {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final _db = FirebaseDatabase.instance.ref();

  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceConnectionState state)? onConnectionStateChange;
  Function(String message)? onMessageReceived;
  Function(RTCDataChannelState state)? onDataChannelStateChange;

  final Map<String, dynamic> _rtcConfig = {
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

  Future<void> _buildPeerConnection(String roomId, bool isCaller) async {
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection(_rtcConfig);

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        print('PeerSessionController: remote track received (${event.track.kind})');
        final stream = event.streams[0];
        for (var track in stream.getTracks()) {
          print('PeerSessionController: track id=${track.id} kind=${track.kind}');
        }
        onRemoteStream?.call(stream);
      } else {
        print('PeerSessionController: track without stream (${event.track.kind})');
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('PeerSessionController: ICE state ($roomId): $state');
      onConnectionStateChange?.call(state);

      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        print('PeerSessionController: P2P connected, cleaning room in 5s');
        Future.delayed(const Duration(seconds: 5), () {
          _db.child('calls').child(roomId).remove();
          print('PeerSessionController: room $roomId removed');
        });
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        final path = isCaller ? 'callerCandidates' : 'calleeCandidates';
        _db.child('calls').child(roomId).child(path).push().set({
          'c': candidate.candidate,
          'm': candidate.sdpMid,
          'l': candidate.sdpMLineIndex,
        });
      }
    };
  }

  Future<void> _buildChatPeerConnection(String roomId, bool isCaller) async {
    if (_peerConnection != null) return;

    _peerConnection = await createPeerConnection(_rtcConfig);

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('PeerSessionController: chat ICE state ($roomId): $state');
      onConnectionStateChange?.call(state);
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        final path = isCaller ? 'callerCandidates' : 'calleeCandidates';
        _db.child('chats').child(roomId).child(path).push().set({
          'c': candidate.candidate,
          'm': candidate.sdpMid,
          'l': candidate.sdpMLineIndex,
        });
      }
    };
  }

  Future<void> initiateOffer({
    required String roomId,
    required MediaStream localStream,
    required String callerId,
    required String callerName,
    required String callerAvatar,
    required String targetId,
    required bool isVideoCall,
    required String callerGender,
  }) async {
    await _buildPeerConnection(roomId, true);

    localStream.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, localStream);
    });

    await _openDataChannel();

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);

    final offerData = {'s': _pack(offer.sdp!), 't': offer.type!};

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
    await _db
        .child('pending_calls')
        .child(targetId)
        .child(roomId)
        .set(callData);

    _db.child('calls').child(roomId).child('answer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('PeerSessionController: received answer, setting remote desc');

      String sdp = _unpack(data['s']);
      String type = data['t'];

      RTCSessionDescription answer = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(answer);
    });

    _watchCandidates(roomId, 'calleeCandidates');
  }

  void _watchCandidates(String roomId, String path) {
    _db.child('calls').child(roomId).child(path).onChildAdded.listen((event) {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      String? candidate = data['c'] ?? data['candidate'];
      String? sdpMid = data['m'] ?? data['sdpMid'];
      int? sdpMLineIndex = data['l'] ?? data['sdpMLineIndex'];

      print('PeerSessionController: adding $path candidate');
      _peerConnection!
          .addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex))
          .catchError((e) {
            print('PeerSessionController: candidate add error: $e');
          });
    });
  }

  Future<void> respondWithAnswer(String roomId, MediaStream localStream) async {
    await _buildPeerConnection(roomId, false);

    localStream.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, localStream);
    });

    _listenForDataChannel();

    _db.child('calls').child(roomId).child('offer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('PeerSessionController: received offer, creating answer');

      String sdp = _unpack(data['s']);
      String type = data['t'];

      RTCSessionDescription offer = RTCSessionDescription(sdp, type);

      await _peerConnection!.setRemoteDescription(offer);

      RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(answer);

      await _db.child('calls').child(roomId).update({
        'answer': {'s': _pack(answer.sdp!), 't': answer.type!},
        'status': 'answered',
      });

      _watchCandidates(roomId, 'callerCandidates');
    });
  }

  void triggerIceRestart() {
    _peerConnection?.createOffer({'iceRestart': true}).then((offer) {
      _peerConnection?.setLocalDescription(offer);
    });
  }

  Future<void> initiateChatOffer({
    required String roomId,
    required String senderName,
    required String senderAvatar,
    required String targetId,
  }) async {
    await _buildChatPeerConnection(roomId, true);
    await _openDataChannel();

    RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(offer);

    final chatData = {
      'offer': {'s': _pack(offer.sdp!), 't': offer.type!},
      'status': 'waiting',
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderUid': FirebaseAuth.instance.currentUser?.uid,
      'targetId': targetId,
      'roomId': roomId,
      'createdAt': ServerValue.timestamp,
    };

    await _db.child('chats').child(roomId).set(chatData);
    await _db
        .child('pending_chats')
        .child(targetId)
        .child(roomId)
        .set(chatData);

    _db.child('chats').child(roomId).child('answer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('PeerSessionController: received chat answer');

      String sdp = _unpack(data['s']);
      String type = data['t'];
      RTCSessionDescription answer = RTCSessionDescription(sdp, type);
      await _peerConnection!.setRemoteDescription(answer);
    });

    _watchChatCandidates(roomId, 'calleeCandidates');
  }

  Future<void> respondWithChatAnswer(String roomId) async {
    await _buildChatPeerConnection(roomId, false);
    _listenForDataChannel();

    _db.child('chats').child(roomId).child('offer').onValue.listen((
      event,
    ) async {
      if (_peerConnection == null || event.snapshot.value == null) {
        print('PeerSessionController: null peer or offer in chat answer');
        return;
      }

      if (_peerConnection!.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer ||
          _peerConnection!.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        print('PeerSessionController: ignoring redundant offer');
        return;
      }

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      print('PeerSessionController: chat offer received for $roomId');

      String sdp, type;
      if (data.containsKey('s')) {
        sdp = _unpack(data['s']);
        type = data['t'];
      } else {
        sdp = data['sdp'];
        type = data['type'];
      }

      RTCSessionDescription offer = RTCSessionDescription(sdp, type);

      try {
        await _peerConnection!.setRemoteDescription(offer);
        print('PeerSessionController: remote desc set for chat');

        RTCSessionDescription answer = await _peerConnection!.createAnswer({
          'offerToReceiveAudio': false,
          'offerToReceiveVideo': false,
        });
        await _peerConnection!.setLocalDescription(answer);
        print('PeerSessionController: local desc (answer) set for chat');

        await _db.child('chats').child(roomId).update({
          'answer': {'s': _pack(answer.sdp!), 't': answer.type!},
          'status': 'connected',
        });
        print('PeerSessionController: answer uploaded to RTDB');

        _watchChatCandidates(roomId, 'callerCandidates');
      } catch (e) {
        print('PeerSessionController: chat answer error: $e');
      }
    });
  }

  void _watchChatCandidates(String roomId, String path) {
    _db.child('chats').child(roomId).child(path).onChildAdded.listen((event) {
      if (_peerConnection == null || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      String? candidate = data['c'] ?? data['candidate'];
      String? sdpMid = data['m'] ?? data['sdpMid'];
      int? sdpMLineIndex = data['l'] ?? data['sdpMLineIndex'];

      print('PeerSessionController: adding chat $path candidate');
      _peerConnection!
          .addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex))
          .catchError((e) {
            print('PeerSessionController: chat candidate add error: $e');
          });
    });
  }

  Future<void> _openDataChannel() async {
    final dataChannelInit = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 30;

    _dataChannel = await _peerConnection!.createDataChannel(
      'chat',
      dataChannelInit,
    );

    _applyDataChannelListeners();
    print('PeerSessionController: data channel opened');
  }

  void _applyDataChannelListeners() {
    _dataChannel?.onDataChannelState = (RTCDataChannelState state) {
      print('PeerSessionController: data channel state: $state');
      onDataChannelStateChange?.call(state);
    };

    _dataChannel?.onMessage = (RTCDataChannelMessage message) {
      if (!message.isBinary) {
        onMessageReceived?.call(message.text);
      }
    };
  }

  void _listenForDataChannel() {
    _peerConnection?.onDataChannel = (RTCDataChannel channel) {
      print('PeerSessionController: data channel received from peer');
      _dataChannel = channel;
      _applyDataChannelListeners();
    };
  }

  Future<bool> transmitMessage(String message) async {
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

  Future<bool> transmitVirtualItem(String itemJson) async {
    return await transmitMessage(itemJson);
  }

  void teardown() {
    _dataChannel?.close();
    _dataChannel = null;
    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;
  }

  String _pack(String input) {
    if (input.isEmpty) return "";
    var bytes = utf8.encode(input);
    var gzipBytes = GZipEncoder().encode(bytes);
    return base64Encode(gzipBytes);
  }

  String _unpack(String? input) {
    if (input == null || input.isEmpty) return "";
    try {
      if (input.startsWith('v=0')) return input;

      var gzipBytes = base64Decode(input);
      var bytes = GZipDecoder().decodeBytes(gzipBytes);
      return utf8.decode(bytes);
    } catch (e) {
      return input;
    }
  }
}
