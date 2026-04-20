import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chilli/services/peer_session.dart';
import 'package:chilli/services/push_receiver.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/services/identity_manager.dart';
import 'package:chilli/theme/palette.dart';

class ChilliChatScreen extends StatefulWidget {
  final String roomId;
  final String partnerName;
  final String partnerAvatar;
  final bool isOutgoing;
  final String? partnerToken;
  final String? partnerUid;
  final PushReceiver pushReceiver;

  const ChilliChatScreen({
    super.key,
    required this.roomId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.isOutgoing,
    this.partnerToken,
    this.partnerUid,
    required this.pushReceiver,
  });

  @override
  State<ChilliChatScreen> createState() => _ChilliChatScreenState();
}

class _ChilliChatScreenState extends State<ChilliChatScreen> with SingleTickerProviderStateMixin {
  final PeerSessionController _peer = PeerSessionController();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final _db = FirebaseDatabase.instance.ref();
  final _identity = IdentityManager();
  final _bridge = DataBridge();

  bool _isDataChannelOpen = false;
  bool _isConnecting = true;
  bool _chatEnded = false;
  bool _locallyEnded = false;
  bool _isDisposed = false;

  num _coins = 0;
  String? _gender;
  String? _email;
  StreamSubscription? _coinSub;
  StreamSubscription? _chatSub;

  int _sentCount = 0;
  int _receivedCount = 0;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _surface = Color(0xFF1A1030);

  @override
  void initState() {
    super.initState();
    widget.pushReceiver.isInCall = true;
    _initApp();
    _setupWebRTC();
    _listenToStatus();
  }

  void _initApp() async {
    final profile = await _identity.loadProfile();
    final coins = await _bridge.getLocalCoins();
    
    if (mounted) {
      setState(() {
        _gender = profile?['gender']?.toString().toLowerCase();
        _email = profile?['email'];
        _coins = coins;
      });
    }

    _coinSub = DataBridge.balanceStream.listen((c) {
      if (mounted) setState(() => _coins = c);
    });
  }

  void _setupWebRTC() {
    _peer.onMessageReceived = (msg) {
      if (!mounted || _chatEnded) return;
      setState(() {
        _messages.add({'text': msg, 'isMine': false, 'time': DateTime.now()});
      });
      _jumpToBottom();
      if (_gender == 'female') _rewardFemale();
    };

    _peer.onDataChannelStateChange = (state) {
      if (!mounted) return;
      setState(() {
        _isDataChannelOpen = (state == RTCDataChannelState.RTCDataChannelOpen);
        if (_isDataChannelOpen) _isConnecting = false;
      });
    };

    if (widget.isOutgoing) {
      _identity.loadProfile().then((p) {
        _peer.initiateChatOffer(
          roomId: widget.roomId,
          senderName: p?['username'] ?? 'User',
          senderAvatar: p?['avatarUrl'] ?? '',
          targetId: widget.partnerUid ?? '',
        );
      });
    } else {
      _peer.respondWithChatAnswer(widget.roomId);
    }
  }

  void _listenToStatus() {
    _chatSub = _db.child('chats').child(widget.roomId).onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      if (data['ended'] == true && !_locallyEnded && !_chatEnded) {
        _onPartnerLeft();
      }
      if (data['status'] == 'declined' && !_locallyEnded && !_chatEnded) {
        _onPartnerDeclined(data['declinedBy'] ?? 'User');
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || !_isDataChannelOpen || _chatEnded) return;

    if (_gender == 'male') {
      if (_coins < 2) {
        _showNoCoins();
        return;
      }
      await _bridge.updateLocalCoins(2, isDeduction: true);
      _sentCount++;
    }

    final success = await _peer.transmitMessage(text);
    if (success) {
      setState(() {
        _messages.add({'text': text, 'isMine': true, 'time': DateTime.now()});
      });
      _msgCtrl.clear();
      _jumpToBottom();
    }
  }

  void _rewardFemale() async {
    _receivedCount++;
    if (_receivedCount % 2 == 0) {
      await _bridge.updateLocalCoins(1, isDeduction: false);
    }
  }

  void _onPartnerLeft() {
    if (_chatEnded) return;
    setState(() => _chatEnded = true);
    _showEndDialog('Chat Ended', 'The other user has left the room.');
  }

  void _onPartnerDeclined(String name) {
    if (_chatEnded) return;
    setState(() => _chatEnded = true);
    _showEndDialog('Declined', '$name declined the chat request.');
  }

  void _showEndDialog(String title, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(color: _neonPink, fontWeight: FontWeight.w900)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(c);
            _exit();
          }, child: const Text('OK', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showNoCoins() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('NO COINS', style: TextStyle(color: _neonPink, fontWeight: FontWeight.w900)),
        content: const Text('You need 2 coins per message. Please recharge to continue.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('BACK', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('RECHARGE', style: TextStyle(color: _neonCyan, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _exit() async {
    if (_locallyEnded) return;
    _locallyEnded = true;
    _chatEnded = true;

    try {
      await _db.child('chats').child(widget.roomId).update({
        'ended': true,
        'endedBy': _email,
        'endedAt': ServerValue.timestamp,
      });
      _db.child('chats').child(widget.roomId).remove();
      if (widget.partnerUid != null) {
        _db.child('pending_chats').child(widget.partnerUid!).child(widget.roomId).remove();
      }
    } catch (_) {}

    _cleanup();
    if (mounted) Navigator.pop(context);
  }

  void _cleanup() {
    if (_isDisposed) return;
    _isDisposed = true;
    _chatSub?.cancel();
    _coinSub?.cancel();
    _peer.teardown();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    widget.pushReceiver.isInCall = false;
  }

  void _jumpToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent + 100, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { _exit(); return false; },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_isConnecting) _buildConnectingStatus(),
            _buildCostHeader(),
            Expanded(child: _buildChatList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: _exit),
      title: Row(
        children: [
          _buildPartnerAvatar(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.partnerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              _buildOnlineStatus(),
            ],
          ),
        ],
      ),
      actions: [
        _buildCoinBadge(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildPartnerAvatar() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _neonCyan.withOpacity(0.5), width: 1.5)),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white10,
        child: ClipOval(
          child: widget.partnerAvatar.isEmpty 
            ? const Icon(Icons.person, color: Colors.white, size: 16)
            : Image.network(
                widget.partnerAvatar,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 16),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: _neonCyan)));
                },
              ),
        ),
      ),
    );
  }

  Widget _buildOnlineStatus() {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: _isDataChannelOpen ? _neonCyan : Colors.white38, shape: BoxShape.circle, boxShadow: _isDataChannelOpen ? [BoxShadow(color: _neonCyan.withOpacity(0.5), blurRadius: 4)] : null),
        ),
        const SizedBox(width: 6),
        Text(_isDataChannelOpen ? 'ACTIVE' : 'CONNECTING', style: TextStyle(color: _isDataChannelOpen ? _neonCyan : Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildCoinBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          const Icon(Icons.toll_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Text(_coins.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildConnectingStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: _neonPink.withOpacity(0.1),
      child: const Center(
        child: Text('ESTABLISHING SECURE P2P CONNECTION...', style: TextStyle(color: _neonPink, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildCostHeader() {
    if (_gender == null) return const SizedBox.shrink();
    final isMale = _gender == 'male';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: (isMale ? _neonPink : _neonCyan).withOpacity(0.05), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Text(
        isMale ? '⚡ 2 COINS PER MESSAGE' : '🎁 EARN 1 COIN PER 2 MESSAGES RECEIVED',
        textAlign: TextAlign.center,
        style: TextStyle(color: isMale ? _neonPink : _neonCyan, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('No messages yet', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Start dating with a hello!', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMine = msg['isMine'] == true;
        return _buildMessageBubble(msg['text'], isMine, msg['time']);
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isMine, DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMine ? _neonCyan.withOpacity(0.1) : _surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMine ? 20 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 20),
            ),
            border: Border.all(color: isMine ? _neonCyan.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
              const SizedBox(height: 4),
              Text('${time.hour}:${time.minute.toString().padLeft(2, "0")}', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: _surface, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white10)),
              child: TextField(
                controller: _msgCtrl,
                enabled: _isDataChannelOpen && !_chatEnded,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(hintText: 'Type a message...', hintStyle: TextStyle(color: Colors.white24, fontSize: 14), border: InputBorder.none),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [_neonCyan, Color(0xFF00B4FF)]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: _neonCyan, blurRadius: 10, offset: Offset(0, 2))]),
              child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
