import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chilli/theme/palette.dart';

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
  final String career; // User's profession

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
    this.career = 'Professional', // Default career
  });

  @override
  State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Single accent color for consistency
  static const Color _primaryColor = Color(0xFF5B7FFF);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMuted = Color(0xFF6B7280);

  // Random category labels
  static const List<String> _categoryLabels = [
    'Profession',
    'Career',
    'Occupation',
    'Work',
    'Job',
    'Field',
    'Expertise',
    'Specialty',
  ];

  late String _selectedLabel;

  @override
  void initState() {
    super.initState();
    // Generate a consistent random label based on user's name hash
    final labelIndex = widget.name.hashCode.abs() % _categoryLabels.length;
    _selectedLabel = _categoryLabels[labelIndex];

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isLoading = true);
        await _audioPlayer.play(UrlSource(widget.audioUrl!));
        setState(() {
          _isPlaying = true;
          _isLoading = false;
        });

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play audio: $e')));
      }
    }
  }

  String _formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return 'Offline';
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  bool get _isUserOnline =>
      widget.status.toLowerCase() == 'online' ||
      widget.status.toLowerCase() == 'active';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Palette.textPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernAvatarSection(),
                      const SizedBox(width: 16),
                      Expanded(child: _buildEnhancedUserInfoSection()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInterestTagsSection(),
                  const SizedBox(height: 16),
                  _buildModernActionButtonsSection(),
                ],
              ),
          ),
        ),
    );
  }

  Widget _buildModernAvatarSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Avatar with square design
        Container(
          width: 90,
          height: 90, // Making it a perfect square
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16), // Square with rounded corners
            border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Palette.textPrimary.withValues(alpha: 0.05),
                  child: const Icon(Icons.person, size: 50, color: Color(0xFF8B5CF6)),
                );
              },
            ),
          ),
        ),

        // Play Button - Modern square design
        if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty)
          Positioned(
            top: -5,
            right: -5,
            child: GestureDetector(
              onTap: _togglePlay,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Palette.surface,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
              ),
            ),
          ),

        // Status Badge - Glassmorphic floating design
        Positioned(
          bottom: -10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: widget.status.toLowerCase() == 'busy'
                    ? const Color(0xFFF59E0B)
                    : _isUserOnline
                    ? const Color(0xFF10B981)
                    : Colors.grey[700]!,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Palette.surface, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _isUserOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isUserOnline)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  Text(
                    widget.status.toLowerCase() == 'busy'
                        ? 'Busy'
                        : _isUserOnline
                        ? 'Online'
                        : _formatLastActive(widget.lastActive),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + Verified
        Row(
          children: [
            Flexible(
              child: Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Palette.textPrimary,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded, color: Color(0xFF06B6D4), size: 18),
          ],
        ),
        const SizedBox(height: 4),
        // Language
        Row(
          children: [
            Icon(Icons.language_rounded, size: 14, color: Palette.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.language,
                style: const TextStyle(color: Palette.textSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Category Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), width: 1),
          ),
          child: Text(
            _selectedLabel,
            style: const TextStyle(
              color: Color(0xFFC4B5FD),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Star Rating
        Row(
          children: [
            ...List.generate(5, (index) {
              return Icon(
                index < widget.rating.floor()
                    ? Icons.star_rounded
                    : index < widget.rating
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
                color: const Color(0xFFFBBF24),
                size: 16,
              );
            }),
            const SizedBox(width: 6),
            Text(
              widget.rating.toStringAsFixed(1),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Palette.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInterestTagsSection() {
    final interests = ['Music 🎵', 'Funk 🎸', 'Hip Hop 🎤', 'Love Story 💕'];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: interests.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Palette.textPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Palette.textPrimary.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                interests[index],
                style: const TextStyle(
                  color: Palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernActionButtonsSection() {
    final bool showPrice = widget.currentUserGender?.toLowerCase() != 'female';

    return Row(
      children: [
        // Audio Call
        Expanded(
          child: _buildCallButton(
            icon: Icons.call_rounded,
            iconColor: const Color(0xFF06B6D4),
            price: widget.audioPrice,
            showPrice: showPrice,
            onTap: widget.onAudioCall,
          ),
        ),
        const SizedBox(width: 12),
        // Video Call
        Expanded(
          child: _buildCallButton(
            icon: Icons.videocam_rounded,
            iconColor: const Color(0xFF8B5CF6),
            price: widget.videoPrice,
            showPrice: showPrice,
            onTap: widget.onVideoCall,
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color iconColor,
    required String price,
    required bool showPrice,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              if (showPrice) ...[
                const SizedBox(width: 8),
                Text(
                  '₹$price/m',
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                Text(
                  'FREE',
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

