import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
  final VoidCallback? onChat;
  final double? coins;
  final String? currentUserGender;
  final DateTime? lastActive;
  final String status;
  final List<String> interests;
  final String career;

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
    this.onChat,
    this.coins,
    this.currentUserGender,
    this.lastActive,
    this.status = 'offline',
    this.interests = const [],
    this.career = 'Expert',
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
  static const _surface = Color(0xFF0F0A1E);

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.15), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildAvatar(accent, isBusy),
                const SizedBox(height: 12),
                _buildNameHeader(),
                const SizedBox(height: 4),
                _buildLanguageInfo(),
                const Spacer(),
                _buildCallActions(accent),
              ],
            ),
          ),
          if (widget.audioUrl != null) _buildPlayButton(),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color accent, bool isBusy) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isBusy ? Colors.amber.withOpacity(0.5) : (widget.isOnline ? accent.withOpacity(0.8 - (_glowController.value * 0.4)) : Colors.grey.withOpacity(0.2)),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: _surface,
                backgroundImage: NetworkImage(widget.imageUrl),
              ),
            );
          },
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isBusy ? Colors.amber : (widget.isOnline ? _neonCyan : Colors.grey),
              shape: BoxShape.circle,
              border: Border.all(color: _surface, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.name,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.verified_rounded, color: _neonViolet, size: 14),
      ],
    );
  }

  Widget _buildLanguageInfo() {
    return Text(
      'Speak ${widget.language}',
      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildPlayButton() {
    return Positioned(
      top: 10,
      right: 10,
      child: GestureDetector(
        onTap: _toggleAudio,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
          child: _isLoading 
            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white.withOpacity(0.5), size: 16),
        ),
      ),
    );
  }

  Widget _buildCallActions(Color accent) {
    final bool showPrice = widget.currentUserGender?.toLowerCase() != 'female';
    return Row(
      children: [
        Expanded(child: _miniCallBtn(Icons.chat_bubble_rounded, accent, '2', showPrice, widget.onChat)),
        const SizedBox(width: 8),
        Expanded(child: _miniCallBtn(Icons.mic_rounded, accent, widget.audioPrice, showPrice, widget.onAudioCall)),
        const SizedBox(width: 8),
        Expanded(child: _miniCallBtn(Icons.videocam_rounded, accent, widget.videoPrice, showPrice, widget.onVideoCall)),
      ],
    );
  }

  Widget _miniCallBtn(IconData icon, Color color, String price, bool showPrice, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              showPrice ? '₹$price' : 'FREE',
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
