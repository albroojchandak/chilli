import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chilli/screens/chilli_call_view.dart';
import 'package:chilli/services/push_receiver.dart';
import 'dart:ui';

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  final _push = PushReceiver();

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);
  static const _surface = Color(0xFF151525);

  @override
  void initState() {
    super.initState();
    _push.initialize();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('call_history_local') ?? '[]';
      final list = jsonDecode(historyStr) as List;
      if (mounted) {
        setState(() {
          _history = list.map((e) => Map<String, dynamic>.from(e)).toList()..sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Clear All?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('This will delete all call logs permanently.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white24))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('DELETE ALL', style: TextStyle(color: _neonPink, fontWeight: FontWeight.w900))),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _neonPink.withOpacity(0.3))),
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('call_history_local');
      setState(() => _history = []);
    }
  }

  Future<void> _deleteItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);
    await prefs.setString('call_history_local', jsonEncode(_history));
    setState(() {});
  }

  void _reCall(Map<String, dynamic> data) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final bool amICaller = data['callerId'] == myUid;
    
    final targetId = amICaller ? data['receiverId'] : data['callerId'];
    final targetName = amICaller ? data['receiverName'] : data['callerName'];
    final targetAvatar = amICaller ? data['receiverAvatar'] : data['callerAvatar'];
    final targetToken = amICaller ? data['receiverToken'] : data['callerToken'];
    final isVideo = data['type'] == 'video';
    
    if (targetId == null) return;
    
    final roomId = 'recall_${DateTime.now().millisecondsSinceEpoch}';
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChilliCallView(
      roomId: roomId,
      callerName: targetName ?? 'User',
      callerAvatar: targetAvatar ?? '',
      isOutgoing: true,
      isVideoCall: isVideo,
      pushReceiver: _push,
      targetId: targetId,
      receiverToken: targetToken,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60 + MediaQuery.of(context).padding.top),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: _bg.withOpacity(0.7),
              elevation: 0,
              centerTitle: false,
              toolbarHeight: 60 + MediaQuery.of(context).padding.top,
              title: Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: const Text('CALL LOGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2)),
              ),
              actions: [
                if (_history.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, right: 10),
                    child: IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: _neonPink, size: 26),
                      onPressed: _clearHistory,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, right: 10),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: _neonCyan),
                    onPressed: () { setState(() => _isLoading = true); _loadHistory(); },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _neonCyan)) 
        : Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -0.6),
                radius: 1.5,
                colors: [Color(0xFF150833), _bg],
              ),
            ),
            child: _history.isEmpty ? _buildEmpty() : _buildList(),
          ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _neonPink.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: _neonPink.withOpacity(0.1), width: 2),
            ),
            child: Icon(Icons.phone_missed_rounded, size: 80, color: _neonPink.withOpacity(0.2)),
          ),
          const SizedBox(height: 32),
          Text('NO RECENT ACTIVITY', style: TextStyle(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 3)),
          const SizedBox(height: 8),
          Text('Your call history will appear here', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 80 + MediaQuery.of(context).padding.top, 20, 100),
      itemCount: _history.length,
      itemBuilder: (context, i) => _buildCallCard(_history[i], i),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> data, int index) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final bool amICaller = data['callerId'] == myUid;
    final name = amICaller ? (data['receiverName'] ?? 'Unknown') : (data['callerName'] ?? 'Unknown');
    final avatar = amICaller ? (data['receiverAvatar'] ?? '') : (data['callerAvatar'] ?? '');
    final bool isMissed = data['status'] == 'missed' || data['status'] == 'declined';
    final Color statusColor = isMissed ? _neonPink : _neonCyan;
    
    final tsString = data['timestamp'] ?? '';
    final ts = DateTime.tryParse(tsString) ?? DateTime.now();
    final formatted = DateFormat('MMM dd, hh:mm a').format(ts);
    final isVideo = data['type'] == 'video';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: _surface,
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? Icon(Icons.person_rounded, color: statusColor.withOpacity(0.5)) : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: _bg, width: 2)),
                        child: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, 
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(amICaller ? Icons.call_made_rounded : Icons.call_received_rounded, size: 14, color: statusColor.withOpacity(0.6)),
                          const SizedBox(width: 6),
                          Text(formatted, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildIconBtn(
                  Icons.call_rounded,
                  _neonCyan,
                  () => _reCall(data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
