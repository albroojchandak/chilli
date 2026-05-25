import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
// import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chilli/config/theme_colors.dart';
import 'package:chilli/pages/diagnostics_page.dart' show DiagnosticsPage;
import 'package:chilli/pages/auth_page.dart';
import 'package:chilli/pages/main_page.dart';
import 'package:chilli/pages/user_details_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ For localization
import 'package:chilli/localization/locale_manager.dart'; // ✅ Custom localizations
import 'package:chilli/core_services/push_notification_service.dart';
import 'package:chilli/core_services/http_service.dart';
import 'package:chilli/core_services/fb_analytics_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:screen_protector/screen_protector.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent screenshots and screen recording
  try {
    await ScreenProtector.preventScreenshotOff();
    debugPrint('🔓 Screen protection disabled');
  } catch (e) {
    debugPrint('❌ Error disabling screen protection: $e');
  }

  // Initialize Firebase before running the app
  // ✅ Try to initialize, but ignore if already initialized by FlutterFire plugins
  try {
    await Firebase.initializeApp(
      // options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized in main()');
    // Install debug App Check provider for development to avoid
    // "No AppCheckProvider installed" errors. Remove or replace
    // with Play Integrity / DeviceCheck in production.
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
      debugPrint('✅ Firebase App Check debug provider installed');
    } catch (e) {
      debugPrint('⚠️ App Check install failed (dev only): $e');
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('✅ Firebase already initialized by FlutterFire plugins');
    } else {
      debugPrint('❌ Firebase initialization error: $e');
      rethrow;
    }
  }

  // ✅ CRITICAL: Register background handler FIRST, before runApp()
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  debugPrint('✅ Background FCM handler registered in main()');

  // ✅ Initialize FCM Early (registers background handler)
  try {
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint("Error initializing FCM in main: $e");
  }

  // ✅ Initialize Facebook App Events Tracking
  try {
    await FbAnalyticsService().initialize();
    debugPrint('✅ Facebook App Events initialized');
  } catch (e) {
    debugPrint('❌ Error initializing Facebook tracking: $e');
  }

  // Set status bar color
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    _setupScreenProtection();
  }

  void _setupScreenProtection() async {
    return; // Disabled as per user request
    // Listen for screenshot events (iOS/Android)
    ScreenProtector.addListener(
      () {
        // Screenshot detected
        debugPrint('📸 Screenshot detected!');

        // Skip for specific user
        final user = FirebaseAuth.instance.currentUser;
        if (user?.email == 'inflyratechnew@gmail.com') {
          debugPrint('🔓 Screenshot allowed for admin user.');
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text(
                'Screenshots are restricted for security reasons.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      (isCaptured) {
        // Screen recording detected
        debugPrint('📹 Screen recording state changed: $isCaptured');

        // Skip for specific user
        final user = FirebaseAuth.instance.currentUser;
        if (user?.email == 'inflyratechnew@gmail.com') {
          debugPrint('🔓 Screen recording allowed for admin user.');
          return;
        }

        if (isCaptured && mounted) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text(
                'Screen recording detected! Please stop recording to protect privacy.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ Global Navigation Key
      title: 'chilli',
      debugShowCheckedModeBanner: false,
      // ✅ Localization Configuration
      localizationsDelegates: const [
        LocaleManager.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('hi', ''), // Hindi - हिंदी
        Locale('ta', ''), // Tamil - தமிழ்
        Locale('te', ''), // Telugu - తెలుగు
        Locale('mr', ''), // Marathi - मराठी
        Locale('bn', ''), // Bengali - বাংলা
        Locale('gu', ''), // Gujarati - ગુજરાતી
        Locale('kn', ''), // Kannada - ಕನ್ನಡ
        Locale('ml', ''), // Malayalam - മലയാളം
        Locale('pa', ''), // Punjabi - ਪੰਜਾਬੀ
        Locale('or', ''), // Odia - ଓଡ଼ିଆ
        Locale('as', ''), // Assamese - অসমীয়া
      ],
      locale: const Locale('en', ''), // Default: English
      theme: ThemeData(
        primaryColor: ThemeColors.primary,
        scaffoldBackgroundColor: ThemeColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ThemeColors.primary,
          primary: ThemeColors.primary,
          secondary: ThemeColors.secondary,
        ),
        useMaterial3: true,
      ),
      home:
          //  DiagnosticsPage()
          const AuthWrapper(),
      routes: {
        '/login': (context) => const AuthPage(),
        '/home': (context) => const MainPage(),
        '/user_info': (context) => const UserDetailsPage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Listen to changes to toggle security
    FirebaseAuth.instance.authStateChanges().listen(_handleScreenSecurity);
  }

  Future<void> _handleScreenSecurity(User? user) async {
    debugPrint('🔓 Ensuring screen protection is OFF for all users');
    await ScreenProtector.preventScreenshotOff();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const AuthPage();
          } else {
            // ✅ Local-First Auth Check
            return FutureBuilder<bool>(
              future: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final cached = prefs.getString('user_data');
                  if (cached != null) {
                    final dynamic decoded = jsonDecode(cached);
                    if (decoded is Map<String, dynamic> &&
                        decoded['uid'] == user.uid) {
                      debugPrint(
                        '🚀 AuthWrapper: Using Cached User Profile (Offline Ready)',
                      );
                      // Ensure HttpService memory cache is initialized
                      await HttpService().cacheUserData(
                        Map<String, dynamic>.from(decoded),
                      );
                      return true;
                    }
                  }

                  // Fallback to Firestore (Only if no cache)
                  debugPrint(
                    '☁️ AuthWrapper: Cache miss, checking Firestore...',
                  );
                  final doc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get();
                  if (doc.exists) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['uid'] = user.uid; // Ensure UID present
                    await HttpService().cacheUserData(data);
                    return true;
                  }
                  return false;
                } catch (e) {
                  debugPrint('❌ AuthWrapper Error: $e');
                  return false;
                }
              }(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (userSnapshot.hasData && userSnapshot.data == true) {
                  return const MainPage();
                }
                // No profile (Local or Remote) -> Registration
                return const UserDetailsPage();
              },
            );
          }
        }
        // Show loading while checking auth state
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
