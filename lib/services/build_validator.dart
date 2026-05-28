import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:url_launcher/url_launcher.dart';

class BuildValidator {
  static Future<void> checkVersion(BuildContext context) async {
    try {
      // 1. Get Current Version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 2. Fetch App Config (includes Version Info)
      await DataBridge().fetchAppConfig();
      final Map<String, dynamic> config = DataBridge.appConfig;

      final String? minVersion = config['min_app_version'];
      final String? latestVersion = config['latest_app_version'];
      final String? updateUrl = config['update_url'];

      if (minVersion == null || latestVersion == null) return;

      // 3. Compare
      if (_isVersionLower(currentVersion, minVersion)) {
        // MANDATORY UPDATE
        if (context.mounted) {
          _showUpdateDialog(context, updateUrl ?? '', isMandatory: true);
        }
      } else if (_isVersionLower(currentVersion, latestVersion)) {
        // OPTIONAL UPDATE
        if (context.mounted) {
          _showUpdateDialog(context, updateUrl ?? '', isMandatory: false);
        }
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
    }
  }

  static bool _isVersionLower(String current, String required) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> requiredParts = required.split('.').map(int.parse).toList();

      for (int i = 0; i < requiredParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (currentPart < requiredParts[i]) return true;
        if (currentPart > requiredParts[i]) return false;
      }
    } catch (e) {
      debugPrint('Version Comparison Error: $e');
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String url, {
    required bool isMandatory,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => PopScope(
        canPop: !isMandatory,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Update Available',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            isMandatory
                ? 'A critical update is required to continue using the app. Please update to the latest version.'
                : 'A new version of the app is available with new features and fixes.',
          ),
          actions: [
            if (!isMandatory)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
            ElevatedButton(
              onPressed: () async {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
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


