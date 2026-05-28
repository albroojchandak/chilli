import 'dart:ui';
import 'package:flutter/material.dart';

enum GenZDialogType {
  info,
  warning,
  error,
  success,
}

class GenZDialog extends StatelessWidget {
  final String title;
  final String message;
  final GenZDialogType type;
  final String primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final Widget? customContent;

  const GenZDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = GenZDialogType.info,
    required this.primaryButtonText,
    this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.customContent,
  });

  Color _getPrimaryColor() {
    switch (type) {
      case GenZDialogType.info:
        return const Color(0xFF06B6D4); // Neon Cyan
      case GenZDialogType.warning:
        return const Color(0xFFFF9800); // Neon Orange
      case GenZDialogType.error:
        return const Color(0xFFFF2D78); // Neon Pink
      case GenZDialogType.success:
        return const Color(0xFF10B981); // Emerald
    }
  }

  IconData _getIcon() {
    switch (type) {
      case GenZDialogType.info:
        return Icons.info_outline_rounded;
      case GenZDialogType.warning:
        return Icons.warning_amber_rounded;
      case GenZDialogType.error:
        return Icons.error_outline_rounded;
      case GenZDialogType.success:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPrimaryColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF151525).withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with glow
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIcon(),
                    color: color,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Message
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                
                if (customContent != null) ...[
                  const SizedBox(height: 24),
                  customContent!,
                ],

                const SizedBox(height: 32),
                
                // Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Primary Button
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: onPrimaryPressed ?? () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          primaryButtonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    
                    if (secondaryButtonText != null) ...[
                      const SizedBox(height: 16),
                      // Secondary Button
                      SizedBox(
                        height: 54,
                        child: TextButton(
                          onPressed: onSecondaryPressed ?? () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Text(
                            secondaryButtonText!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
