import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TxnScreen extends StatefulWidget {
  final bool isWithdrawal;
  const TxnScreen({Key? key, this.isWithdrawal = false})
    : super(key: key);

  @override
  State<TxnScreen> createState() => _TxnScreenState();
}

class _TxnScreenState extends State<TxnScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  // Tracks which refIds are currently being checked (shows spinner per card)
  final Set<String> _checkingRefs = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      if (widget.isWithdrawal) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        // Firestore Fetch for Withdrawals
        final snapshot = await FirebaseFirestore.instance
            .collection('withdrawals')
            .where('userId', isEqualTo: user.uid)
            .get();

        if (mounted) {
          setState(() {
            _transactions = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'Amount': data['amount'],
                'Status': data['status'],
                'Date': data['date'],
                'Upi': data['upiId'],
                'type': 'withdrawal',
              };
            }).toList();

            // Client-side Sort
            _transactions.sort((a, b) {
              try {
                return DateTime.parse(
                  b['Date'] ?? '',
                ).compareTo(DateTime.parse(a['Date'] ?? ''));
              } catch (e) {
                return 0;
              }
            });

            _isLoading = false;
          });
        }
      } else {
        // Load Deposits from Local Storage
        final prefs = await SharedPreferences.getInstance();
        final historyString = prefs.getString('local_transaction_history');

        if (historyString != null && historyString.isNotEmpty) {
          final List<dynamic> localData = jsonDecode(historyString);
          if (mounted) {
            setState(() {
              _transactions = List<Map<String, dynamic>>.from(localData);
              // Sort by date descending
              _transactions.sort((a, b) {
                try {
                  final dateA =
                      DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
                  final dateB =
                      DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
                  return dateB.compareTo(dateA);
                } catch (e) {
                  return 0;
                }
              });
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _transactions = [];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Call Paygic check-payment-status API and handle the result.
  Future<void> _checkPaymentStatus(Map<String, dynamic> item) async {
    final refId = item['refId']?.toString() ?? '';
    final mid = item['mid']?.toString() ?? '';
    final token = item['token']?.toString() ?? '';

    if (refId.isEmpty) {
      _showToast('No reference ID available for this transaction.', Colors.red);
      return;
    }

    // Use stored credentials; fall back to app config if not saved in record
    final effectiveMid = mid.isNotEmpty
        ? mid
        : DataBridge.appConfig['paygic_mid']?.toString().trim() ?? '';
    final effectiveToken = token.isNotEmpty
        ? token
        : DataBridge.appConfig['paygic_token']?.toString().trim() ?? '';

    if (effectiveMid.isEmpty || effectiveToken.isEmpty) {
      _showToast(
        'Payment credentials not available. Try again later.',
        Colors.orange,
      );
      return;
    }

    setState(() => _checkingRefs.add(refId));

    try {
      final response = await http
          .post(
            Uri.parse('https://server.paygic.in/api/v2/checkPaymentStatus'),
            headers: {
              'Content-Type': 'application/json',
              'token': effectiveToken,
            },
            body: jsonEncode({
              'mid': effectiveMid,
              'merchantReferenceId': refId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final txnStatus = (data['txnStatus'] ?? data['status'] ?? '')
            .toString()
            .toUpperCase();
        final statusOk =
            data['status'] == true ||
            data['statusCode'] == 200 ||
            txnStatus == 'SUCCESS';

        if (statusOk && txnStatus == 'SUCCESS') {
          // ✅ DOUBLE-CREDIT GUARD: check the shared processed_payment_refs
          // list BEFORE crediting. balance_page auto-check writes to this list
          // too, so whichever side runs first will claim it.
          final prefs = await SharedPreferences.getInstance();
          final processedSet =
              (prefs.getStringList('processed_payment_refs') ?? []).toSet();

          final alreadyCredited = processedSet.contains(refId);

          // Always update the UI record to 'success'
          await _markTransactionSuccess(refId);

          if (alreadyCredited) {
            // Coins were already added (e.g. by auto-check on WalletScreen).
            // Just inform the user — do NOT add coins again.
            _showToast(
              '✅ Payment already verified. Coins were previously credited.',
              Colors.green,
            );
          } else {
            // First time confirming — credit coins and mark as processed
            await _creditCoinsFromTransaction(item, data, refId);
            _showToast(
              '✅ Payment verified! Coins have been credited.',
              Colors.green,
            );
          }
        } else {
          // Still pending / failed on gateway side
          final msg = data['msg']?.toString() ?? 'Status: $txnStatus';
          _showStatusDialog(txnStatus, msg, data);
        }
      } else {
        _showToast('Server error: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      _showToast('Network error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _checkingRefs.remove(refId));
    }
  }

  /// Update the local transaction record from 'pending'/'failed' → 'success'.
  Future<void> _markTransactionSuccess(String refId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString =
          prefs.getString('local_transaction_history') ?? '[]';
      final List<dynamic> history = jsonDecode(historyString);

      for (int i = history.length - 1; i >= 0; i--) {
        final item = history[i] as Map<String, dynamic>;
        if (item['refId'] == refId) {
          history[i]['status'] = 'success';
          break;
        }
      }
      await prefs.setString('local_transaction_history', jsonEncode(history));

      // Reload the list in-place
      if (mounted) {
        setState(() {
          for (int i = 0; i < _transactions.length; i++) {
            if (_transactions[i]['refId'] == refId) {
              _transactions[i] = Map<String, dynamic>.from(_transactions[i])
                ..['status'] = 'success';
              break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating local transaction: $e');
    }
  }

  /// Credit coins to the user's balance based on transaction tokens.
  /// Also saves [refId] to the shared 'processed_payment_refs' guard so the
  /// balance_page auto-check cannot double-credit the same payment.
  Future<void> _creditCoinsFromTransaction(
    Map<String, dynamic> item,
    Map<String, dynamic> serverResponse,
    String refId,
  ) async {
    try {
      // Prefer tokens from our saved record; fall back to amount from server
      final num tokensToAdd =
          (item['tokens'] as num?) ??
          (serverResponse['data']?['amount'] as num?) ??
          0;

      if (tokensToAdd <= 0) return;

      final prefs = await SharedPreferences.getInstance();
      final currentBalance =
          prefs.getDouble('local_coins') ?? await DataBridge().getLocalCoins();
      final newBalance = currentBalance + tokensToAdd.toDouble();

      await prefs.setDouble('local_coins', newBalance);
      DataBridge.broadcastTokenUpdate(newBalance.toInt());

      // ✅ Mark this refId as processed so neither this page nor the
      // balance_page auto-check can credit it a second time.
      final processedList = prefs.getStringList('processed_payment_refs') ?? [];
      if (!processedList.contains(refId)) {
        processedList.add(refId);
        await prefs.setStringList('processed_payment_refs', processedList);
      }

      debugPrint(
        '💰 Credited $tokensToAdd coins via status-check. New balance: $newBalance',
      );
    } catch (e) {
      debugPrint('Error crediting coins: $e');
    }
  }

  void _showStatusDialog(
    String txnStatus,
    String message,
    Map<String, dynamic> data,
  ) {
    final isPending = txnStatus == 'PENDING' || txnStatus == '';
    final color = isPending ? Colors.orange : Colors.red;
    final icon = isPending ? Icons.hourglass_top : Icons.cancel;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              txnStatus.isEmpty ? 'PENDING' : txnStatus,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
    );
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null) return DateTime(1970);
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          widget.isWithdrawal ? 'Withdrawals' : 'Payment History',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final item = _transactions[index];
                return _buildTransactionCard(item);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Your deposit history will appear here.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    final status = (item['Status'] ?? item['status'] ?? 'unknown').toString();
    final isSuccess = status.toLowerCase() == 'success';
    final isPending = status.toLowerCase() == 'pending';
    final isFailed = !isSuccess && !isPending;

    final amount =
        double.tryParse(
          item['Amount']?.toString() ?? item['amount']?.toString() ?? '0',
        ) ??
        0.0;
    final tokens = item['tokens'];
    final dateStr = item['Date'] ?? item['date'] ?? '';
    final date = _parseDate(dateStr);
    final refId = item['refId']?.toString() ?? '';
    final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);

    final statusColor = isSuccess
        ? Colors.green
        : (isPending ? Colors.orange : Colors.red);
    final statusIcon = isSuccess
        ? Icons.check_circle
        : (isPending ? Icons.hourglass_empty : Icons.cancel);

    final bool isCheckingThis = _checkingRefs.contains(refId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isFailed
              ? Colors.red.withOpacity(0.15)
              : (isPending
                    ? Colors.orange.withOpacity(0.15)
                    : Colors.green.withOpacity(0.1)),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status icon circle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isWithdrawal
                        ? Icons.arrow_upward
                        : (isSuccess ? Icons.arrow_downward : statusIcon),
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isWithdrawal ? 'Withdrawal' : 'Coin Purchase',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formattedDate,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      if (widget.isWithdrawal && item['Upi'] != null)
                        Text(
                          'UPI: ${item['Upi']}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      if (!widget.isWithdrawal && tokens != null)
                        Text(
                          '🪙 $tokens coins',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (refId.isNotEmpty)
                        Text(
                          'Ref: $refId',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Amount + status badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSuccess ? Colors.green : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── "Check Payment Status" button for pending / failed deposits ──
          if (!widget.isWithdrawal &&
              (isPending || isFailed) &&
              refId.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isPending
                    ? Colors.orange.withOpacity(0.06)
                    : Colors.red.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border(
                  top: BorderSide(
                    color: statusColor.withOpacity(0.15),
                    width: 1,
                  ),
                ),
              ),
              child: TextButton.icon(
                onPressed: isCheckingThis
                    ? null
                    : () => _checkPaymentStatus(item),
                style: TextButton.styleFrom(
                  foregroundColor: statusColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                ),
                icon: isCheckingThis
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      )
                    : Icon(Icons.sync_rounded, size: 18, color: statusColor),
                label: Text(
                  isCheckingThis ? 'Checking…' : 'Check Payment Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


