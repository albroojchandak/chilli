import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chilli/theme/palette.dart';
import 'package:chilli/screens/auth_screen.dart';
import 'package:chilli/screens/home_screen.dart';
import 'package:chilli/screens/onboard_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:chilli/locale/lang_bundle.dart';
import 'package:chilli/services/push_receiver.dart';
import 'package:chilli/services/data_bridge.dart';
import 'package:chilli/services/fb_reporter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:google_sign_in/google_sign_in.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageWithColor(Colors.black);
    debugPrint('Screen protection enabled');
  } catch (e) {
    debugPrint('Screen protection error: $e');
  }

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized');
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
      debugPrint('App Check activated');
    } catch (e) {
      debugPrint('App Check error: $e');
    }
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('Firebase already initialized');
    } else {
      debugPrint('Firebase error: $e');
      rethrow;
    }
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  debugPrint('Background FCM handler registered');

  try {
    await PushReceiver().initialize();
  } catch (e) {
    debugPrint('FCM init error: $e');
  }

  try {
    await FbInsightsReporter().setup();
    debugPrint('Facebook Events initialized');
  } catch (e) {
    debugPrint('Facebook Events error: $e');
  }

  try {
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '278527617965-4dsk3c4eri7f0p8ojvv6hpo8mpmt716r.apps.googleusercontent.com',
    );
    debugPrint('GoogleSignIn initialized');
  } catch (e) {
    debugPrint('GoogleSignIn init error: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ChilliApp());
}

class ChilliApp extends StatefulWidget {
  const ChilliApp({super.key});

  @override
  State<ChilliApp> createState() => _ChilliAppState();
}

class _ChilliAppState extends State<ChilliApp> {
  @override
  void initState() {
    super.initState();
    _initSecurityListeners();
  }

  void _initSecurityListeners() async {
    ScreenProtector.addListener(
      () {
        debugPrint('Screenshot detected');

        final user = FirebaseAuth.instance.currentUser;
        if (user?.email == 'nurxianpvltd@gmail.com') {
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text(
                'Screenshots are restricted for security reasons.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      (isCaptured) {
        debugPrint('Screen recording changed: $isCaptured');

        final user = FirebaseAuth.instance.currentUser;
        if (user?.email == 'nurxianpvltd@gmail.com') {
          return;
        }

        if (isCaptured && mounted) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text(
                'Screen recording detected. Please stop to protect privacy.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Color(0xFFEF4444),
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
      navigatorKey: navigatorKey,
      title: 'Chilli',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        LangBundle.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('hi', ''),
        Locale('ta', ''),
        Locale('te', ''),
        Locale('mr', ''),
        Locale('bn', ''),
        Locale('gu', ''),
        Locale('kn', ''),
        Locale('ml', ''),
        Locale('pa', ''),
        Locale('or', ''),
        Locale('as', ''),
      ],
      locale: const Locale('en', ''),
      theme: ThemeData(
        primaryColor: AppPalette.primary,
        scaffoldBackgroundColor: AppPalette.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.primary,
          primary: AppPalette.primary,
          secondary: AppPalette.secondary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const SessionRouter(),
      routes: {
        '/login': (context) => const AuthScreen(),
        '/home': (context) => const ChilliHomeScreen(),
        '/user_info': (context) => const ProfileSetupScreen(),
      },
    );
  }
}

class SessionRouter extends StatefulWidget {
  const SessionRouter({super.key});

  @override
  State<SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends State<SessionRouter> {
  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user?.email == 'nurxianpvltd@gmail.com') {
      debugPrint('Admin user: disabling screen protection');
      await ScreenProtector.preventScreenshotOff();
    } else {
      debugPrint('Standard user: ensuring screen protection is ON');
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageWithColor(Colors.black);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const AuthScreen();
          } else {
            return FutureBuilder<bool>(
              future: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final cached = prefs.getString('user_data');
                  if (cached != null) {
                    final dynamic decoded = jsonDecode(cached);
                    if (decoded is Map<String, dynamic> &&
                        decoded['uid'] == user.uid) {
                      debugPrint('SessionRouter: using cached profile');
                      await DataBridge().cacheUserData(
                        Map<String, dynamic>.from(decoded),
                      );
                      return true;
                    }
                  }

                  debugPrint('SessionRouter: no cache, checking Firestore');
                  final doc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get();
                  if (doc.exists) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['uid'] = user.uid;
                    await DataBridge().cacheUserData(data);
                    return true;
                  }
                  return false;
                } catch (e) {
                  debugPrint('SessionRouter error: $e');
                  return false;
                }
              }(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0F0A1E),
                    body: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  );
                }
                if (userSnapshot.hasData && userSnapshot.data == true) {
                  return const ChilliHomeScreen();
                }
                return const ProfileSetupScreen();
              },
            );
          }
        }
        return const Scaffold(
          backgroundColor: Color(0xFF0F0A1E),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          ),
        );
      },
    );
  }
}
