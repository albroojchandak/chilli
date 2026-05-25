import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chilli/core_services/http_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AppRatingService {
  static final InAppReview _inAppReview = InAppReview.instance;

  static Future<void> checkAndShowRating(BuildContext context) async {
    try {
      await Future.delayed(
        const Duration(seconds: 2),
      ); // ✅ Wait for UI/Coins to load
      final prefs = await SharedPreferences.getInstance();

      // 1. Check if user already rated or declined
      bool hasRated = prefs.getBool('app_rating_done') ?? false;
      if (hasRated) return;

      // 2. Check Coin Balance (User must have > 2 coins)
      final num currentCoins = await HttpService().getLocalCoins();
      debugPrint('⭐ Rating Check: Current Coins = $currentCoins');

      if (currentCoins <= 2) {
        debugPrint('⭐ Rating Check: Balance too low (<= 2), skipping.');
        return;
      }

      // 3. Show Rating Dialog
      debugPrint('⭐ Rating Check: Conditions met, showing dialog.');
      if (context.mounted) {
        _showRatingDialog(context);
      }
    } catch (e) {
      debugPrint('Error checking rating status: $e');
    }
  }

  static void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Enjoying chilli?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 60),
            SizedBox(height: 16),
            Text(
              'Your rating helps us improve and bring more amazing people together!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('app_rating_done', true); // Don't show again
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('app_rating_done', true);
              if (context.mounted) Navigator.pop(context);

              // 🚀 Use direct URL launch for robustness (prevents MissingPluginException)
              const String playStoreUrl =
                  'https://play.google.com/store/apps/details?id=com.chilli.inflyratech';
              final Uri uri = Uri.parse(playStoreUrl);

              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  // Final fallback using InAppReview if available
                  if (await _inAppReview.isAvailable()) {
                    await _inAppReview.requestReview();
                  }
                }
              } catch (e) {
                debugPrint('Rating Error: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Rate 5 Stars'),
          ),
        ],
      ),
    );
  }
}
