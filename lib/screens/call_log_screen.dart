import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chilli/screens/call_screen.dart';
import 'package:chilli/services/push_receiver.dart';

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  static const _bg = Color(0xFF06010F);
  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);
  static const _surface = Color(0xFF1A1030);

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('CALL LOGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: _neonCyan), onPressed: () { setState(() => _isLoading = true); _loadHistory(); })],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: _neonCyan)) : (_history.isEmpty ? _buildEmpty() : _buildList()),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_missed_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text('EMPTY CALL LOG', style: TextStyle(color: Colors.white.withOpacity(0.2), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      itemBuilder: (context, i) => _buildCallCard(_history[i]),
    );
  }

  Widget _buildCallCard(Map<String, dynamic> data) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final bool amICaller = data['callerId'] == myUid;
    final name = amICaller ? (data['receiverName'] ?? 'Unknown') : (data['callerName'] ?? 'Unknown');
    final avatar = amICaller ? (data['receiverAvatar'] ?? '') : (data['callerAvatar'] ?? '');
    final bool isMissed = data['status'] == 'missed' || data['status'] == 'declined';
    final Color color = isMissed ? _neonPink : _neonCyan;
    
    final tsString = data['timestamp'] ?? '';
    final ts = DateTime.tryParse(tsString) ?? DateTime.now();
    final formatted = DateFormat('MMM dd • HH:mm').format(ts);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(0.1),
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? Icon(Icons.person_rounded, color: color) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(amICaller ? Icons.call_made_rounded : Icons.call_received_rounded, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(formatted, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(data['type'] == 'video' ? Icons.videocam_rounded : Icons.mic_rounded, color: Colors.white.withOpacity(0.1), size: 18),
              const SizedBox(height: 8),
              Text(isMissed ? 'MISSED' : 'CONNECTED', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}
