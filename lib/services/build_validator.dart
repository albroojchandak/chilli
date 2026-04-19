import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

class BuildValidator {
  static Future<void> runVersionCheck(BuildContext context) async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String installedVersion = info.version;

      await DataBridge().fetchAppConfig();
      final Map<String, dynamic> cfg = DataBridge.appConfig;

      final String? minRequired = cfg['min_app_version'];
      final String? latestAvailable = cfg['latest_app_version'];
      final String? storeLink = cfg['update_url'];

      if (minRequired == null || latestAvailable == null) return;

      if (_versionIsBehind(installedVersion, minRequired)) {
        if (context.mounted) {
          _showVersionDialog(context, storeLink ?? '', mandatory: true);
        }
      } else if (_versionIsBehind(installedVersion, latestAvailable)) {
        if (context.mounted) {
          _showVersionDialog(context, storeLink ?? '', mandatory: false);
        }
      }
    } catch (e) {
      debugPrint('BuildValidator: error - $e');
    }
  }

  static bool _versionIsBehind(String current, String required) {
    try {
      List<int> curr = current.split('.').map(int.parse).toList();
      List<int> req = required.split('.').map(int.parse).toList();

      for (int i = 0; i < req.length; i++) {
        int c = i < curr.length ? curr[i] : 0;
        if (c < req[i]) return true;
        if (c > req[i]) return false;
      }
    } catch (e) {
      debugPrint('BuildValidator: version compare error: $e');
    }
    return false;
  }

  static void _showVersionDialog(
    BuildContext context,
    String url, {
    required bool mandatory,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (context) => PopScope(
        canPop: !mandatory,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1030),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            mandatory ? '🚨 Update Required' : '✨ New Version Available',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          content: Text(
            mandatory
                ? 'A critical update is required to continue. Please update now.'
                : 'A newer version with improvements is ready for you.',
            style: const TextStyle(color: Color(0xFF9B93B8)),
          ),
          actions: [
            if (!mandatory)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Color(0xFF9B93B8)),
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
