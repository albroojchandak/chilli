import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chilli/services/firestore_repo.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  static const _cardBg = Color(0xFF130E26);

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your request has been sent successfully.'),
        backgroundColor: _neonPink,
      ),
    );
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
    final Color accent = widget.gender.toLowerCase() == 'female' ? _neonPink : _neonCyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.04),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with voice intro play button
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Hero(
                        tag: 'user_avatar_${widget.uid ?? widget.imageUrl}',
                        child: widget.imageUrl.isEmpty
                            ? Container(
                                color: Colors.white10,
                                child: Icon(
                                  widget.gender.toLowerCase() == 'female' ? Icons.face_3_rounded : Icons.face_6_rounded,
                                  color: accent.withOpacity(0.6),
                                  size: 36,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: widget.imageUrl,
                                fit: BoxFit.cover,
                                httpHeaders: const {
                                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36',
                                },
                                errorListener: (error) {
                                  debugPrint('CachedNetworkImage error: $error');
                                },
                                placeholder: (context, url) => Container(
                                  color: Colors.white10,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(accent.withOpacity(0.4)),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.white10,
                                  child: Icon(Icons.person, color: accent.withOpacity(0.6), size: 36),
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Voice Introduction Player
                  if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: _toggleAudio,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
                          ),
                          child: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // User profile details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: _neonViolet, size: 14),
                        const Spacer(),
                        _buildBlockButton(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.career,
                      style: TextStyle(
                        color: accent.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (index) => const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.rating > 0 ? widget.rating.toStringAsFixed(1) : '5.0',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildMetaInfo(accent),
                  ],
                ),
              ),
            ],
          ),
          if (widget.interests.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: widget.interests.map((tag) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Large Call Actions spanning full width at the bottom
          _buildCallActions(accent),
        ],
      ),
    );
  }

  Widget _buildBlockButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: const Color(0xFF15082E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
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
              Text('Report', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'block',
          child: Row(
            children: [
              Icon(Icons.block_rounded, color: _neonPink, size: 18),
              SizedBox(width: 12),
              Text('Block', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaInfo(Color accent) {
    final bool isBusy = widget.status.toLowerCase() == 'busy';

    return Row(
      children: [
        const Icon(Icons.translate_rounded, color: Colors.white38, size: 12),
        const SizedBox(width: 4),
        Text(
          widget.language,
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        if (isBusy) ...[
          const SizedBox(width: 12),
          const Text(
            'Busy',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCallActions(Color accent) {
    final bool isFemale = widget.currentUserGender?.toLowerCase() == 'female';
    return Row(
      children: [
        Expanded(
          child: _callButton(
            icon: Icons.mic_rounded,
            price: widget.audioPrice,
            isFree: isFemale,
            onTap: widget.onAudioCall,
            accent: accent,
            label: "Voice Call",
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _callButton(
            icon: Icons.videocam_rounded,
            price: widget.videoPrice,
            isFree: isFemale,
            onTap: widget.onVideoCall,
            accent: accent,
            label: "Video Call",
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _callButton({
    required IconData icon,
    required String price,
    required bool isFree,
    required VoidCallback? onTap,
    required Color accent,
    required String label,
    required bool isPrimary,
  }) {
    final BoxDecoration deco = isPrimary
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent,
                accent.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.4), width: 1.5),
          );

    final Color contentColor = isPrimary ? Colors.white : accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: deco,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: contentColor, size: 18),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  isFree ? "FREE" : "₹$price/m",
                  style: TextStyle(
                    color: isPrimary ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.55),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

