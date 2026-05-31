import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:chilli/screens/chilli_call_view.dart';
import 'package:chilli/services/push_receiver.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chilli/widgets/genz_dialog.dart'; // ✅ Added GenZDialog

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // 7:3:1 Light Theme colors
  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _primaryLight = Color(0xFF818CF8);
  static const Color _bgColor = Color(0xFFFFFFFF);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFFFFFFFF);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _success = Color(0xFF10B981);
  static const Color _error = Color(0xFFE11D48);

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredHistory = _history.where((call) {
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        final callerId = call['callerId'] as String?;
        final amICaller = callerId == myUid;
        final name = amICaller
            ? (call['receiverName'] ?? 'Unknown')
            : (call['callerName'] ?? 'Unknown');
        return name.toLowerCase().contains(
          _searchController.text.toLowerCase(),
        );
      }).toList();
    });
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('call_history_local') ?? '[]';
      final List<dynamic> list = jsonDecode(historyString);

      setState(() {
        _history = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _history.sort((a, b) {
          try {
            return DateTime.parse(
              b['timestamp'],
            ).compareTo(DateTime.parse(a['timestamp']));
          } catch (_) {
            return 0;
          }
        });
        _filteredHistory = _history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCall(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);
    await prefs.setString('call_history_local', jsonEncode(_history));
    setState(() {
      _filteredHistory = _history;
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => GenZDialog(
        title: 'CLEAR HISTORY?',
        message: 'This will permanently delete all your call records. This action cannot be undone.',
        type: GenZDialogType.error,
        primaryButtonText: 'DELETE ALL',
        secondaryButtonText: 'CANCEL',
        onSecondaryPressed: () => Navigator.pop(ctx, false),
        onPrimaryPressed: () => Navigator.pop(ctx, true),
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('call_history_local');
      setState(() {
        _history.clear();
        _filteredHistory.clear();
      });
    }
  }

  Map<String, int> _getStatistics() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    int total = _history.length;
    int incoming = _history.where((h) => h['receiverId'] == myUid).length;
    int outgoing = _history.where((h) => h['callerId'] == myUid).length;
    int missed = _history
        .where((h) => h['status'] == 'missed' || h['status'] == 'declined')
        .length;

    return {
      'total': total,
      'incoming': incoming,
      'outgoing': outgoing,
      'missed': missed,
    };
  }

  List<Map<String, dynamic>> _getFilteredHistory() {
    return _searchController.text.isEmpty ? _history : _filteredHistory;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: _bgColor, body: _buildLoadingState());
    }

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.15),
                    blurRadius: 120,
                    spreadRadius: 120,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _error.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: _error.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: _history.isEmpty ? 140 : 260,
                  floating: true,
                  pinned: true,
                  snap: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    if (_history.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 16, top: 8),
                        child: GestureDetector(
                          onTap: _clearHistory,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 22,
                              color: _error,
                            ),
                          ),
                        ),
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: EdgeInsets.zero,
                    background: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _textDark.withValues(alpha: 0.05),
                                _textDark.withValues(alpha: 0.02),
                              ],
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: _textDark.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: SafeArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 60),
                                // Title with icon
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _primaryColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: _primaryColor.withValues(
                                              alpha: 0.5,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.history_rounded,
                                          color: _primaryColor,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Call History',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: _textDark,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Your recent calls',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: _textDark.withValues(
                                                  alpha: 0.6,
                                                ),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_history.isNotEmpty) ...[
                                  const Spacer(),
                                  _buildSearchBar(),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _textDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Call History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (_history.isNotEmpty)
            GestureDetector(
              onTap: _clearHistory,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.delete_sweep_rounded,
                  size: 22,
                  color: _error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _getStatistics();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _primaryLight],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.call_rounded,
            stats['total']!,
            'Total',
            Colors.white.withOpacity(0.9),
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.call_received_rounded,
            stats['incoming']!,
            'Incoming',
            Colors.white.withOpacity(0.9),
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.call_made_rounded,
            stats['outgoing']!,
            'Outgoing',
            Colors.white.withOpacity(0.9),
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.call_missed_rounded,
            stats['missed']!,
            'Missed',
            Colors.white.withOpacity(0.9),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, int count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildSearchBar() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 52,
      decoration: BoxDecoration(
        color: _textDark.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _textDark.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: _textDark.withValues(alpha: 0.5),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 15,
                color: _textDark,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search calls...',
                hintStyle: TextStyle(
                  color: _textDark.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _textDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: _textDark,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withValues(alpha: 0.2),
                  _primaryColor.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading history...',
            style: TextStyle(
              color: _textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final filteredHistory = _getFilteredHistory();

    if (filteredHistory.isEmpty) {
      return _buildEmptyState();
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in filteredHistory) {
      try {
        final date = DateTime.parse(item['timestamp']);
        final dateKey = _getDateKey(date);
        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add(item);
      } catch (_) {}
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final items = grouped[dateKey]!;
        return _buildDateSection(dateKey, items);
      },
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) return 'Today';
    if (itemDate == yesterday) return 'Yesterday';
    return DateFormat('EEEE, MMM dd').format(date);
  }

  Widget _buildDateSection(String dateKey, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 0, 12),
          child: Text(
            dateKey,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items.map((item) {
          final itemIndex = _history.indexOf(item);
          return _buildHistoryCard(item, itemIndex);
        }).toList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withValues(alpha: 0.1),
                  _primaryColor.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_disabled_rounded,
              size: 56,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No calls yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your call history will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data, int index) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final callerId = data['callerId'] as String?;
    final receiverId = data['receiverId'] as String?;
    bool amICaller = callerId == myUid;

    String remoteName;
    String remoteAvatar;
    String remoteId;

    if (callerId != null && receiverId != null && myUid != null) {
      if (amICaller) {
        remoteName = data['receiverName'] ?? 'Unknown';
        remoteAvatar = data['receiverAvatar'] ?? '';
        remoteId = receiverId;
      } else {
        remoteName = data['callerName'] ?? 'Unknown';
        remoteAvatar = data['callerAvatar'] ?? '';
        remoteId = callerId;
      }
    } else {
      remoteName = data['receiverName'] ?? data['callerName'] ?? 'User';
      remoteAvatar = data['receiverAvatar'] ?? '';
      remoteId = '';
    }

    final type = data['type'] ?? 'audio';
    final status = data['status'] ?? 'unknown';

    DateTime timestamp;
    try {
      timestamp = DateTime.parse(data['timestamp']);
    } catch (_) {
      timestamp = DateTime.now();
    }

    final duration = data['duration'] as int? ?? 0;
    final formattedTime = DateFormat('hh:mm a').format(timestamp);
    final durationStr = _formatDuration(duration);
    final isVideo = type == 'video';

    Color statusColor;
    IconData statusIcon;
    String statusText;
    Color cardAccent;

    if (status == 'declined' || status == 'missed') {
      statusColor = _error;
      cardAccent = _error.withValues(alpha: 0.1);
      statusIcon = amICaller
          ? Icons.call_missed_outgoing_rounded
          : Icons.call_missed_rounded;
      statusText = status == 'declined' ? 'Declined' : 'Missed';
    } else {
      statusColor = _success;
      cardAccent = _success.withValues(alpha: 0.1);
      statusIcon = amICaller
          ? Icons.call_made_rounded
          : Icons.call_received_rounded;
      statusText = durationStr;
    }

    return Dismissible(
      key: Key('${data['timestamp']}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_error.withValues(alpha: 0.8), _error],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _deleteCall(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: remoteId.isEmpty
                ? null
                : () async {
                    await _callUser(
                      remoteId,
                      remoteName,
                      remoteAvatar,
                      isVideo,
                    );
                    _loadHistory();
                  },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: [
                              _primaryColor.withOpacity(0.15),
                              _primaryColor.withOpacity(0.05),
                            ],
                          ),
                          image: remoteAvatar.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(remoteAvatar),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: remoteAvatar.isEmpty
                            ? Center(
                                child: Text(
                                  remoteName.isNotEmpty
                                      ? remoteName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: _primaryColor,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isVideo
                                  ? [_primaryColor, _primaryLight]
                                  : [_success, _success.withValues(alpha: 0.8)],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: _cardColor, width: 2.5),
                          ),
                          child: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.call_rounded,
                            size: 12,
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
                        Text(
                          remoteName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 12,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: _textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (remoteId.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isVideo
                              ? [_primaryColor, _primaryLight]
                              : [_success, _success.withValues(alpha: 0.9)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isVideo ? _primaryColor : _success)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _callUser(
    String targetId,
    String name,
    String avatar,
    bool isVideo,
  ) async {
    if (targetId.isEmpty) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primaryColor.withOpacity(0.2),
                        _primaryColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Connecting...',
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please wait',
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetId)
          .get();

      if (!userDoc.exists) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text('User not found'),
                ],
              ),
              backgroundColor: _error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        return;
      }

      final userData = userDoc.data();
      final token = userData?['fcmToken'] as String?;

      if (mounted) Navigator.pop(context);

      final roomId = const Uuid().v4();
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChilliCallView(
              roomId: roomId,
              callerName: name,
              callerAvatar: avatar,
              targetId: targetId,
              remoteUid: targetId,
              receiverToken: token,
              isOutgoing: true,
              isVideoCall: isVideo,
              pushNotificationService: PushReceiver(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error calling user: $e');
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '${minutes}m';
    return '${minutes}m ${secs}s';
  }
}


