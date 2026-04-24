import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chilli/services/firestore_repo.dart';

class UserTile extends StatefulWidget {
  final String name;
  final String imageUrl;
  final String language;
  final String gender;
  final double rating;
  final String audioPrice;
  final String videoPrice;
  final bool isOnline;
  final String? audioUrl;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;
  final double? coins;
  final String? currentUserGender;
  final DateTime? lastActive;
  final String status;
  final List<String> interests;
  final String career;
  final String? uid;

  const UserTile({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.language,
    required this.gender,
    required this.rating,
    required this.audioPrice,
    required this.videoPrice,
    required this.isOnline,
    this.audioUrl,
    this.onAudioCall,
    this.onVideoCall,
    this.coins,
    this.currentUserGender,
    this.lastActive,
    this.status = 'offline',
    this.interests = const [],
    this.career = 'Expert',
    this.uid,
  });

  @override
  State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  late final AnimationController _glowController;

  static const _neonPink = Color(0xFFFF2D78);
  static const _neonCyan = Color(0xFF00F5FF);
  static const _neonViolet = Color(0xFFBF5AF2);
  static const _surface = Color(0xFF0A0A12);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _confirmBlock() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF15082E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: _neonPink, width: 0.5)),
          title: const Text('BLOCK USER?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
          content: Text('Do you want to block ${widget.name}? They will no longer appear in your feed.', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white38))),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('BLOCK', style: TextStyle(color: _neonPink, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && widget.uid != null) {
      await FirestoreRepository().blockUser(widget.uid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.name} blocked'), backgroundColor: _neonPink));
      }
    }
  }

  Future<void> _handleReport() async {
    final List<String> reasons = [
      'Inappropriate Content',
      'Harassment or Bullying',
      'Spam or Fake Profile',
      'Hate Speech',
      'Nudity or Sexual Content',
      'Other'
    ];

    final reason = await showDialog<String>(
      context: context,
      builder: (c) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF15082E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.amberAccent, width: 0.5)),
          title: const Text('REPORT USER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) => ListTile(
              title: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              onTap: () => Navigator.pop(c, r),
              dense: true,
            )).toList(),
          ),
        ),
      ),
    );

    if (reason != null && widget.uid != null) {
      await FirestoreRepository().reportUser(widget.uid!, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User reported. We will investigate.'), backgroundColor: Colors.amber));
      }
    }
  }

  Future<void> _toggleAudio() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isLoading = true);
        await _audioPlayer.play(UrlSource(widget.audioUrl!));
        setState(() { _isPlaying = true; _isLoading = false; });
        _audioPlayer.onPlayerComplete.listen((_) { if (mounted) setState(() => _isPlaying = false); });
      }
    } catch (_) {
      setState(() { _isLoading = false; _isPlaying = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBusy = widget.status.toLowerCase() == 'busy';
    final Color accent = widget.gender.toLowerCase() == 'female' ? _neonPink : _neonCyan;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.05), blurRadius: 20, spreadRadius: -5),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageLayer(accent),
            _buildOverlayLayer(accent, isBusy),
            _buildInfoPanel(accent),
            if (widget.audioUrl != null) _buildVoiceIndicator(),
            _buildBlockButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockButton() {
    return Positioned(
      top: 12,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 14),
              padding: EdgeInsets.zero,
              color: const Color(0xFF15082E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
              onSelected: (val) {
                if (val == 'block') _confirmBlock();
                if (val == 'report') _handleReport();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, color: Colors.amberAccent, size: 18),
                      SizedBox(width: 12),
                      Text('Report Protocol', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: _neonPink, size: 18),
                      SizedBox(width: 12),
                      Text('Block Identity', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageLayer(Color accent) {
    return Positioned.fill(
      child: Hero(
        tag: 'user_avatar_${widget.uid ?? widget.imageUrl}',
        child: widget.imageUrl.isEmpty
            ? Container(
                color: accent.withOpacity(0.05),
                child: Icon(
                  widget.gender.toLowerCase() == 'female' ? Icons.face_3_rounded : Icons.face_6_rounded,
                  color: accent.withOpacity(0.2),
                  size: 60,
                ),
              )
            : Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _surface, child: Icon(Icons.person, color: accent.withOpacity(0.2), size: 50)),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: _surface);
                },
              ),
      ),
    );
  }

  Widget _buildOverlayLayer(Color accent, bool isBusy) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.1),
              Colors.black.withOpacity(0.0),
              Colors.black.withOpacity(0.4),
              Colors.black.withOpacity(0.95),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(Color accent) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.name.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: _neonViolet, size: 14),
                        ],
                      ),
                      Text(
                        'Speak ${widget.language}',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _buildOnlineDot(accent),
              ],
            ),
            const SizedBox(height: 12),
            _buildQuickActions(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineDot(Color accent) {
    final bool isBusy = widget.status.toLowerCase() == 'busy';
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final double op = widget.isOnline ? (0.6 + (_glowController.value * 0.4)) : 0.3;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBusy ? Colors.amber : (widget.isOnline ? _neonCyan : Colors.grey),
            boxShadow: [
              if (widget.isOnline || isBusy)
                BoxShadow(
                  color: (isBusy ? Colors.amber : _neonCyan).withOpacity(op),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(Color accent) {
    final bool isFemale = widget.currentUserGender?.toLowerCase() == 'female';
    return Row(
      children: [
        _actionIcon(Icons.mic_rounded, accent, widget.audioPrice, '/min', isFemale, widget.onAudioCall),
        const SizedBox(width: 8),
        _actionIcon(Icons.videocam_rounded, accent, widget.videoPrice, '/min', isFemale, widget.onVideoCall),
      ],
    );
  }

  Widget _actionIcon(IconData icon, Color color, String price, String unit, bool isFree, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: isFree ? 'FREE' : '₹$price',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                          if (!isFree)
                            TextSpan(
                              text: unit,
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 7, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
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

  Widget _buildVoiceIndicator() {
    return Positioned(
      top: 12,
      left: 12,
      child: GestureDetector(
        onTap: _toggleAudio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
              child: _isLoading
                  ? const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ),
    );
  }
}
