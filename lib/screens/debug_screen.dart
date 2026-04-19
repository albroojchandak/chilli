import 'package:flutter/material.dart';
import '../services/data_bridge.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Tools'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 20),
              const Text(
                'Firestore Setup',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Developer Tools',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Initialize Firestore Config',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Creates app_config documents with default values',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {

                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 10),
                                Text('Confirm'),
                              ],
                            ),
                            content: const Text(
                              'This will create/overwrite the following documents:\n\n'
                              '• app_config/pricing\n'
                              '• app_config/payment\n'
                              '• app_config/version\n\n'
                              'Continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text('Initialize'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) return;

                        if (!context.mounted) return;

                        try {

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          await DataBridge().initializeFirestoreConfig();

                          if (!context.mounted) return;

                          Navigator.pop(context);

                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 10),
                                  Text('Success!'),
                                ],
                              ),
                              content: const Text(
                                'Firestore config initialized successfully!\n\n'
                                'Next steps:\n'
                                '1. Open Firestore Console\n'
                                '2. Edit app_config/payment\n'
                                '3. Add your payment credentials\n'
                                '4. Adjust pricing if needed',
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;

                          Navigator.pop(context);

                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.error, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('Error'),
                                ],
                              ),
                              content: Text(
                                'Failed to initialize config:\n\n$e\n\n'
                                'Make sure:\n'
                                '• Firestore rules allow write access\n'
                                '• You have internet connection\n'
                                '• Firebase is properly configured',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Run Initialization'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red),
                    SizedBox(height: 8),
                    Text(
                      'Important Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Only run this ONCE\n'
                      '• Will overwrite existing config\n'
                      '• Check console for detailed logs\n'
                      '• Verify Firestore rules allow writes',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

