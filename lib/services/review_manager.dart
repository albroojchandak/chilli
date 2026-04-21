import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreReviewManager {
  static final InAppReview _reviewInstance = InAppReview.instance;

  static Future<void> evaluateAndPrompt(BuildContext context) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final prefs = await SharedPreferences.getInstance();

      bool hasReviewed = prefs.getBool('app_rating_done') ?? false;
      if (hasReviewed) return;

      final num currentCoins = await DataBridge().getLocalCoins();
      debugPrint('StoreReviewManager: coins = $currentCoins');

      if (currentCoins <= 2) {
        debugPrint('StoreReviewManager: coins too low, skipping');
        return;
      }

      debugPrint('StoreReviewManager: showing prompt');
      if (context.mounted) {
        _openPrompt(context);
      }
    } catch (e) {
      debugPrint('StoreReviewManager: error - $e');
    }
  }

  static void _openPrompt(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1030),
        title: const Text(
          'Loving the App?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 60),
            const SizedBox(height: 16),
            Text(
              'Your rating helps us connect more amazing people!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('app_rating_done', true);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Not Now',
              style: TextStyle(color: Color(0xFF9B93B8)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('app_rating_done', true);
              if (context.mounted) Navigator.pop(context);

              const String storeUrl = '';
              final Uri uri = Uri.parse(storeUrl);

              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (await _reviewInstance.isAvailable()) {
                    await _reviewInstance.requestReview();
                  }
                }
              } catch (e) {
                debugPrint('StoreReviewManager: launch error: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Rate Now ⭐'),
          ),
        ],
      ),
    );
  }
}
