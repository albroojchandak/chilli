import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';
import 'dart:math' as Math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import '../core_services/push_notification_service.dart'
    show PushNotificationService;
import '../core_services/video_call_service.dart';
import '../core_services/push_notification_service.dart';
import '../core_services/http_service.dart';

class ChatPage extends StatefulWidget {
  final String roomId;
  final String partnerName;
  final String partnerAvatar;
  final bool isOutgoing;
  final String? partnerToken;
  final String? partnerUid; // ✅ Partner's UID for Firestore notifications
  final PushNotificationService pushNotificationService;

  const ChatPage({
    super.key,
    required this.roomId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.isOutgoing,
    this.partnerToken,
    this.partnerUid, // ✅ Optional partner UID
    required this.pushNotificationService,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  late final VideoCallService _VideoCallService;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final _db = FirebaseDatabase.instance.ref();

  bool _isDataChannelOpen = false;
  bool _isConnecting = true;
  bool _chatEnded = false;
  bool _locallyEnded = false;
  bool _cleanupCalled = false;
  bool _isDisposed = false;
  bool _isDeleted = false;

  StreamSubscription<DatabaseEvent>? _chatEndListener;
  late AnimationController _backgroundAnimController;

  // Token management variables
  num _currentTokens = 0;
  StreamSubscription<num>? _tokenSubscription;
  int _messagesSent = 0;
  int _messagesReceived = 0;
  String _currentUserGender = '';
  String _currentUserEmail = '';
  bool _isLoadingTokens = true;
  DateTime _lastTokenUpdateTime = DateTime(2000); // ✅ Track last local update

  @override
  void initState() {
    super.initState();

    // Initialize background animation
    _backgroundAnimController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _VideoCallService = VideoCallService();
    widget.pushNotificationService.isInCall = true;
    _loadUserData();
    _initializeChat();
    _setupTokenListener();
    widget.pushNotificationService.onChatDeclined = (data) {
      if (data['roomId'] == widget.roomId && !_chatEnded) {
        _handleChatDeclined(data['declinedBy'] ?? 'User');
      }
    };
  }

  void _setupTokenListener() {
    _tokenSubscription = HttpService.tokenStream.listen((coins) {
      // ✅ Only update if stream value is newer than last local update
      final now = DateTime.now();
      final timeSinceLastUpdate = now
          .difference(_lastTokenUpdateTime)
          .inMilliseconds;

      // Ignore stream updates within 2 seconds of a local update
      if (timeSinceLastUpdate > 2000) {
        print(
          '🔔 Token stream update received: $coins (previous: $_currentTokens, time elapsed: ${timeSinceLastUpdate}ms)',
        );
        if (mounted && !_isDisposed) {
          setState(() {
            _currentTokens = coins;
          });
          print('✅ Token UI updated to: $_currentTokens');
        }
      } else {
        print(
          '⏭️ Ignoring stale stream update - local update was ${timeSinceLastUpdate}ms ago',
        );
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      print('🔄 Loading user data...');
      final localCoins = await HttpService().getLocalCoins();
      print('📊 Retrieved local coins: $localCoins');

      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      print('📦 User data exists: ${userDataString != null}');

      if (userDataString != null) {
        final userData = jsonDecode(userDataString) as Map<String, dynamic>;

        final rawGender = userData['Gender'];
        final processedGender = rawGender?.toString().toLowerCase() ?? '';

        print('👤 Raw gender from data: "$rawGender"');
        print('👤 Processed gender: "$processedGender"');
        print('📧 Email: ${userData['Email']}');

        if (mounted && !_isDisposed) {
          setState(() {
            _currentTokens = localCoins; // ✅ Use local coins
            _currentUserGender = processedGender;
            _currentUserEmail = userData['Email'] ?? '';
            _isLoadingTokens = false;
          });
        }

        print(
          '✅ User data loaded successfully:\n'
          '   💰 Tokens: $_currentTokens\n'
          '   👤 Gender: "$_currentUserGender"\n'
          '   📧 Email: $_currentUserEmail',
        );
      } else {
        print('⚠️ No user_data found in SharedPreferences');
        if (mounted && !_isDisposed) {
          setState(() {
            _currentTokens = localCoins;
            _isLoadingTokens = false;
          });
        }
        print('💰 Set tokens to: $_currentTokens (gender unknown)');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingTokens = false;
        });
      }
    }
  }

  Future<bool> _deductTokenForMale() async {
    print(
      '🔍 _deductTokenForMale called. Gender: $_currentUserGender, Balance: $_currentTokens',
    );

    if (_currentUserGender != 'male') {
      print('✅ Not male, allowing message');
      return true;
    }

    if (_currentTokens < 2) {
      print('❌ Insufficient tokens: $_currentTokens < 2');
      _showInsufficientTokensDialog();
      return false;
    }

    _messagesSent++;
    print(
      '📤 Message #$_messagesSent - Deducting 2 coins from $_currentTokens',
    );

    // ✅ Update timestamp before attempting operation
    _lastTokenUpdateTime = DateTime.now();

    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        print('💳 Deduction attempt ${retries + 1}/$maxRetries');

        // Deduct 2 coins
        await HttpService().updateLocalCoins(2, isDeduction: true);

        // Small delay to ensure backend processes the update
        await Future.delayed(const Duration(milliseconds: 150));

        // Get the updated balance directly
        final newBalance = await HttpService().getLocalCoins();
        print('📊 Retrieved balance after deduction: $newBalance');

        // Verify deduction happened
        if (newBalance >= _currentTokens) {
          print('⚠️ Balance did not decrease, retrying deduction...');
          retries++;
          await Future.delayed(Duration(milliseconds: 100 * retries));
          continue;
        }

        // Update local state immediately
        if (mounted && !_isDisposed) {
          setState(() {
            _currentTokens = newBalance;
          });
        }

        print('✅ Successfully deducted! New balance: $newBalance');

        if (newBalance <= 0 && !_chatEnded) {
          print('⚠️ Balance is zero or negative, showing dialog');
          Future.delayed(const Duration(milliseconds: 200), () {
            _showBalanceLowDialog();
          });
        }

        return true;
      } catch (e) {
        print('❌ Deduction attempt ${retries + 1} failed: $e');
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(Duration(milliseconds: 200 * retries));
        }
      }
    }

    print('❌ Failed to deduct tokens after $maxRetries attempts');
    return false;
  }

  Future<void> _addTokenForFemale() async {
    print(
      '🔍 _addTokenForFemale called. Gender: $_currentUserGender, Balance: $_currentTokens',
    );

    if (_currentUserGender != 'female') {
      print('✅ Not female, no rewards');
      return;
    }

    _messagesReceived++;
    print('📨 Message #$_messagesReceived received');

    if (_messagesReceived % 2 == 0) {
      print('💎 Earned reward! Adding 1 coin to $_currentTokens');

      // ✅ Update timestamp before attempting operation
      _lastTokenUpdateTime = DateTime.now();

      int retries = 0;
      const maxRetries = 3;

      while (retries < maxRetries) {
        try {
          print('🎁 Reward attempt ${retries + 1}/$maxRetries');

          // Add 1 coin
          await HttpService().updateLocalCoins(1);

          // Small delay to ensure backend processes the update
          await Future.delayed(const Duration(milliseconds: 150));

          // Get the updated balance directly
          final newBalance = await HttpService().getLocalCoins();
          print('📊 Retrieved balance after reward: $newBalance');

          // Verify addition happened
          if (newBalance <= _currentTokens) {
            print('⚠️ Balance did not increase, retrying reward...');
            retries++;
            await Future.delayed(Duration(milliseconds: 100 * retries));
            continue;
          }

          // Update local state immediately
          if (mounted && !_isDisposed) {
            setState(() {
              _currentTokens = newBalance;
            });
          }

          print('✅ Successfully added reward! New balance: $newBalance');
          return;
        } catch (e) {
          print('❌ Reward attempt ${retries + 1} failed: $e');
          retries++;
          if (retries < maxRetries) {
            await Future.delayed(Duration(milliseconds: 200 * retries));
          }
        }
      }

      print('❌ Failed to add tokens after $maxRetries attempts');
    } else {
      print('⏳ Waiting for next message ($_messagesReceived/2)');
    }
  }

  void _showBalanceLowDialog() {
    if (!mounted || _chatEnded || _isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.money_off, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Balance Low'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.account_balance_wallet, size: 60, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Your coin balance has reached 0.\nThe chat will end now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _endChat();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeChat() async {
    print(
      '🚀 _initializeChat started. Room: ${widget.roomId}, isOutgoing: ${widget.isOutgoing}',
    );
    try {
      _VideoCallService.onMessageReceived = (String message) {
        if (mounted && !_chatEnded && !_isDisposed) {
          print('📨 Received message: $message');

          setState(() {
            _messages.add({
              'text': message,
              'isMine': false,
              'timestamp': DateTime.now(),
            });
          });
          _scrollToBottom();

          if (_currentUserGender == 'female') {
            print('👩 Female user - checking token reward');
            _addTokenForFemale();
          }
        }
      };

      _VideoCallService.onDataChannelStateChange = (RTCDataChannelState state) {
        if (mounted && !_isDisposed) {
          setState(() {
            _isDataChannelOpen =
                (state == RTCDataChannelState.RTCDataChannelOpen);
            if (_isDataChannelOpen) {
              _isConnecting = false;
            }
          });
          print('📡 Chat data channel state: $state');
        }
      };

      if (widget.isOutgoing) {
        print('📤 Creating outgoing chat offer for room: ${widget.roomId}');

        final prefs = await SharedPreferences.getInstance();
        final userDataStr = prefs.getString('user_data');
        String myName = 'User';
        String myAvatar = '';

        if (userDataStr != null) {
          final data = jsonDecode(userDataStr);
          myName = data['Name'] ?? 'User';
          myAvatar =
              data['ProfilePicture'] ??
              data['AvatarUrl'] ??
              data['avatar'] ??
              '';
        }

        await _VideoCallService.createChatOnlyOffer(
          roomId: widget.roomId,
          senderName: myName,
          senderAvatar: myAvatar,
          targetId: widget.partnerUid ?? '',
        );

        // ✅ Notification is now also handled by Realtime DB 'pending_chats'
      } else {
        await _VideoCallService.createChatOnlyAnswer(widget.roomId);
      }

      _listenForChatEnd();

      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && !_isDataChannelOpen && !_chatEnded && !_isDisposed) {
          _showConnectionFailedDialog();
        }
      });
    } catch (e) {
      print('❌ Error initializing chat: $e');
      if (mounted && !_isDisposed) {
        _showConnectionFailedDialog();
      }
    }
  }

  void _listenForChatEnd() {
    _chatEndListener = _db.child('chats').child(widget.roomId).onValue.listen((
      event,
    ) {
      if (event.snapshot.value != null && mounted && !_isDisposed) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Check for ended flag
        if (data['ended'] == true && !_locallyEnded && !_chatEnded) {
          _chatEnded = true;
          _showPartnerLeftDialog();
        }

        // Check for declined status (for the sender)
        if (data['status'] == 'declined' && !_locallyEnded && !_chatEnded) {
          _chatEnded = true;
          _handleChatDeclined(data['declinedBy'] ?? 'User');
        }
      }
    });
  }

  void _showPartnerLeftDialog() {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.exit_to_app, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Chat Ended'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.person_off, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'User left the chat',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChatRoom() async {
    if (_isDeleted) return;
    _isDeleted = true;

    try {
      print('🗑️ Starting chat room deletion in Realtime DB: ${widget.roomId}');
      await _db.child('chats').child(widget.roomId).remove();

      // Also remove from pending_chats if it exists
      if (widget.partnerUid != null) {
        await _db
            .child('pending_chats')
            .child(widget.partnerUid!)
            .child(widget.roomId)
            .remove();
      }

      print('✅ Chat room deleted successfully from Realtime DB');
    } catch (e) {
      print('❌ Error deleting chat room: $e');
      _isDeleted = false; // Reset to allow retry if needed
    }
  }

  Future<void> _endChat() async {
    if (_chatEnded || _locallyEnded) return;

    _chatEnded = true;
    _locallyEnded = true;
    _isDisposed = true;

    if (mounted) {
      setState(() {});
    }

    try {
      await _db.child('chats').child(widget.roomId).update({
        'ended': true,
        'endedBy': _currentUserEmail,
        'endedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('❌ Error marking chat as ended: $e');
    }

    _deleteChatRoom().catchError(
      (e) => print('⚠️ Background deletion error: $e'),
    );
    _cleanup();

    Future.microtask(() {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _cleanup() {
    if (_cleanupCalled) return;
    _cleanupCalled = true;

    _isDisposed = true;
    _chatEndListener?.cancel();
    _tokenSubscription?.cancel();

    // Dispose animation controller
    _backgroundAnimController.dispose();

    // ✅ Ensure chat room is deleted when cleaning up
    _deleteChatRoom();

    try {
      _VideoCallService.dispose();
    } catch (e) {
      print('⚠️ Error disposing WebRTC: $e');
    }

    _messages.clear();

    try {
      _messageController.dispose();
      _scrollController.dispose();
    } catch (e) {
      print('⚠️ Error disposing controllers: $e');
    }

    widget.pushNotificationService.isInCall = false;
  }

  Future<bool> _handleBackPress() async {
    if (!_chatEnded) {
      await _endChat();
      return false;
    }
    return true;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatEnded || _isDisposed)
      return;

    if (_currentUserGender == 'male') {
      final canSend = await _deductTokenForMale();
      if (!canSend) return;
    }

    final messageText = _messageController.text.trim();

    if (mounted && !_isDisposed) {
      setState(() {
        _messages.add({
          'text': messageText,
          'isMine': true,
          'timestamp': DateTime.now(),
        });
      });
    }

    final success = await _VideoCallService.sendMessage(messageText);

    if (!success && mounted && !_isDisposed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
    }

    _messageController.clear();
    _scrollToBottom();
  }

  void _showInsufficientTokensDialog() {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 10),
            const Text('Insufficient Coins'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.chat_bubble, color: Colors.orange[700], size: 40),
                  const SizedBox(height: 10),
                  Text(
                    'Need 2 Coins',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '2 coins per message',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current balance: $_currentTokens Coins',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.add_circle, size: 20),
            label: const Text('Add Coins'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionFailedDialog() {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection Failed'),
        content: const Text(
          'Could not establish chat connection. Please try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endChat();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleChatDeclined(String declinedBy) {
    if (_chatEnded || _isDisposed) return;

    _chatEnded = true;
    _isDisposed = true;

    if (mounted) setState(() {});

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.cancel_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Chat Declined'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '$declinedBy declined the chat request',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EAF6),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _endChat,
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF667eea),
                backgroundImage: widget.partnerAvatar.isNotEmpty
                    ? NetworkImage(widget.partnerAvatar)
                    : null,
                child: widget.partnerAvatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.partnerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isDataChannelOpen ? 'Online' : 'Connecting...',
                      style: TextStyle(
                        color: _isDataChannelOpen
                            ? Colors.greenAccent
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: !_isLoadingTokens
              ? [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentTokens',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : null,
        ),
        body: Column(
          children: [
            if (_isConnecting)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.orange.withOpacity(0.2),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Waiting for other user...'),
                  ],
                ),
              ),
            if (_currentUserGender == 'male' && !_isLoadingTokens)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '2 coins deducted per message sent',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ],
                ),
              ),
            if (_currentUserGender == 'female' && !_isLoadingTokens)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.green.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.card_giftcard,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'You earn 1 coin per 2 messages received',
                      style: TextStyle(fontSize: 12, color: Colors.green[800]),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  // Animated bubble background pattern
                  AnimatedBuilder(
                    animation: _backgroundAnimController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ChatBackgroundPainter(
                          _backgroundAnimController.value,
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),

                  // Messages
                  _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF667eea).withOpacity(0.15),
                                      const Color(0xFF764ba2).withOpacity(0.15),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF667eea,
                                      ).withOpacity(0.2),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.waving_hand_rounded,
                                  size: 72,
                                  color: const Color(
                                    0xFF667eea,
                                  ).withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Say Hello! 👋',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF667eea,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF667eea,
                                    ).withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  'Start your conversation with ${widget.partnerName}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final showDateSeparator =
                                index == 0 ||
                                !_isSameDay(
                                  _messages[index - 1]['timestamp'] as DateTime,
                                  message['timestamp'] as DateTime,
                                );
                            final bool isGrouped =
                                index > 0 &&
                                _messages[index - 1]['isMine'] ==
                                    message['isMine'] &&
                                !showDateSeparator;

                            return Column(
                              children: [
                                if (showDateSeparator)
                                  _buildDateSeparator(
                                    message['timestamp'] as DateTime,
                                  ),
                                _buildChatBubble(
                                  message['text'] as String,
                                  message['isMine'] as bool,
                                  message['timestamp'] as DateTime,
                                  isGrouped,
                                ),
                              ],
                            );
                          },
                        ),
                ],
              ),
            ),
            if (!_isDisposed)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _isDataChannelOpen
                                  ? const Color(0xFF667eea).withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _messageController,
                            enabled: _isDataChannelOpen && !_chatEnded,
                            maxLines: 4,
                            minLines: 1,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                            decoration: InputDecoration(
                              hintText: _chatEnded
                                  ? 'Chat ended'
                                  : (_isDataChannelOpen
                                        ? 'Type a message...'
                                        : 'Connecting...'),
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.emoji_emotions_outlined,
                                    color: const Color(
                                      0xFF667eea,
                                    ).withOpacity(0.6),
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    // Could add emoji picker here
                                  },
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          gradient: _isDataChannelOpen && !_chatEnded
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF667eea),
                                    Color(0xFF764ba2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey[300]!,
                                    Colors.grey[400]!,
                                  ],
                                ),
                          shape: BoxShape.circle,
                          boxShadow: _isDataChannelOpen && !_chatEnded
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667eea,
                                    ).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_isDataChannelOpen && !_chatEnded)
                                ? _sendMessage
                                : null,
                            borderRadius: BorderRadius.circular(26),
                            child: const Center(
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(
    String text,
    bool isMine,
    DateTime timestamp,
    bool isGrouped,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(isMine ? 20 * (1 - value) : -20 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(bottom: isGrouped ? 4 : 16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMine ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMine ? 20 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMine
                          ? const Color(0xFF667eea).withOpacity(0.3)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isMine ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              if (!isGrouped) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(
                    left: isMine ? 0 : 12,
                    right: isMine ? 12 : 0,
                  ),
                  child: Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String dateText;

    if (_isSameDay(date, now)) {
      dateText = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          dateText,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Custom painter for animated chat background
class _ChatBackgroundPainter extends CustomPainter {
  final double animationValue;

  _ChatBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw animated gradient bubbles
    for (int i = 0; i < 8; i++) {
      final offset = (animationValue + i * 0.125) % 1.0;
      final x = (i % 3) * size.width / 2.5 + (offset * 50);
      final y = (i ~/ 3) * size.height / 3 + (offset * 100);
      final radius = 40 + (offset * 30);

      paint.color = [
        const Color(0xFF667eea).withOpacity(0.03),
        const Color(0xFF764ba2).withOpacity(0.03),
        const Color(0xFFF093FB).withOpacity(0.03),
      ][i % 3];

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw subtle wave pattern
    final wavePaint = Paint()
      ..color = const Color(0xFF667eea).withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    for (double x = 0; x <= size.width; x += 5) {
      final y =
          size.height * 0.5 +
          30 *
              Math.sin(
                (x / size.width) * 2 * Math.pi + animationValue * 2 * Math.pi,
              );
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(_ChatBackgroundPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
