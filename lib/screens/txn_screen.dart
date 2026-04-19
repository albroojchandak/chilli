import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/theme/palette.dart';

class TxnScreen extends StatefulWidget {
  final bool isWithdrawal;
  const TxnScreen({super.key, this.isWithdrawal = false});

  @override
  State<TxnScreen> createState() => _TxnScreenState();
}

class _TxnScreenState extends State<TxnScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  final Set<String> _checkingRefs = {};

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
      if (widget.isWithdrawal) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) { if (mounted) setState(() => _isLoading = false); return; }
        final snapshot = await FirebaseFirestore.instance.collection('withdrawals').where('userId', isEqualTo: user.uid).get();
        if (mounted) {
          setState(() {
            _transactions = snapshot.docs.map((doc) {
              final d = doc.data();
              return {'id': doc.id, 'Amount': d['amount'], 'Status': d['status'], 'Date': d['date'], 'Upi': d['upiId'], 'type': 'withdrawal'};
            }).toList()..sort((a, b) => (b['Date'] ?? '').compareTo(a['Date'] ?? ''));
            _isLoading = false;
          });
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final historyStr = prefs.getString('local_transaction_history');
        if (historyStr != null && historyStr.isNotEmpty) {
          if (mounted) {
            setState(() {
              _transactions = List<Map<String, dynamic>>.from(jsonDecode(historyStr))..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() { _transactions = []; _isLoading = false; });
        }
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
        title: Text(widget.isWithdrawal ? 'WITHDRAWALS' : 'HISTORY', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: _neonCyan), onPressed: () { setState(() => _isLoading = true); _loadHistory(); })],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: _neonCyan)) : (_transactions.isEmpty ? _buildEmpty() : _buildList()),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text('NO TRANSACTIONS YET', style: TextStyle(color: Colors.white.withOpacity(0.2), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _transactions.length,
      itemBuilder: (context, i) => _buildCard(_transactions[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = (item['Status'] ?? item['status'] ?? 'pending').toString().toLowerCase();
    final bool isSuccess = status == 'success';
    final bool isPending = status == 'pending';
    final Color accent = isSuccess ? _neonCyan : (isPending ? Colors.amber : _neonPink);
    
    final amount = double.tryParse((item['Amount'] ?? item['amount'] ?? '0').toString()) ?? 0.0;
    final date = DateTime.tryParse(item['Date'] ?? item['date'] ?? '') ?? DateTime.now();
    final formatted = DateFormat('MMM dd • HH:mm').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(widget.isWithdrawal ? Icons.arrow_upward_rounded : Icons.payments_rounded, color: accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.isWithdrawal ? 'Withdrawal' : 'Coin Purchase', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                Text(formatted, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
