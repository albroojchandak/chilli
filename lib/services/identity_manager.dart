import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

class IdentityManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isGoogleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _isGoogleSignInInitialized = true;
    }
  }

  // Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(String) onAutoRetrievalTimeout,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    int? forceResendingToken,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: onVerificationCompleted,
        verificationFailed: onVerificationFailed,
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('IdentityManager: codeSent triggered. ID: $verificationId');
          try {
            onCodeSent(verificationId, resendToken);
          } catch (e) {
            debugPrint('Error inside onCodeSent callback: $e');
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onAutoRetrievalTimeout(verificationId);
        },
        forceResendingToken: forceResendingToken,
      );
    } catch (e) {
      debugPrint('Error verifying phone number: $e');
      rethrow;
    }
  }

  // Verify OTP
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Attempt to sign in
      final userCredential = await _auth.signInWithCredential(credential);

      // Verify the sign-in was successful
      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User is null after sign in',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Auth Error - Code: ${e.code}, Message: ${e.message}',
      );
      rethrow;
    } on TypeError catch (e) {
      // Handle the PigeonUserDetails type cast error
      debugPrint('TypeError in Firebase Auth (PigeonUserDetails bug): $e');

      // Check if user is actually signed in despite the error
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        debugPrint('User is signed in despite error. Proceeding...');
        // Return a mock UserCredential since auth actually succeeded
        return Future.value(_createMockUserCredential(currentUser));
      }

      // If not signed in, rethrow as a Firebase error
      throw FirebaseAuthException(
        code: 'type-error',
        message: 'Authentication type error. Please try again.',
      );
    } catch (e) {
      debugPrint('Unexpected error signing in with OTP: $e');
      rethrow;
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();
      
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email'],
      );

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final GoogleSignInClientAuthorization? authz = await googleUser.authorizationClient.authorizationForScopes(['email']);

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return null;
    }
  }

  // Helper method to create a mock UserCredential when the actual one fails
  UserCredential _createMockUserCredential(User user) {
    // This is a workaround - we know the user is signed in
    // We just need to return something that won't crash
    return _MockUserCredential(user);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out of Google: $e');
    }
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // 1. Try Local Cache
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        try {
          final dynamic decoded = jsonDecode(userDataString);
          if (decoded is Map<String, dynamic> && decoded['uid'] == user.uid) {
            final data = Map<String, dynamic>.from(decoded);
            _remapUserData(data); // ✅ Use unified remapping Logic

            debugPrint('Protocol: Using Cached User Data (Offline Ready)');
            return data;
          }
        } catch (e) {
          debugPrint('Cache decode error: $e');
        }
      }

      // 2. Fallback to Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _remapUserData(data); // Refactored remapping
          // Update cache silently
          data['uid'] = user.uid;
          prefs.setString('user_data', jsonEncode(data));
        }
        return data;
      } else {
        // ❌ Direct Doc ID lookup failed.
        // 🔍 Fallback: Query by Phone Number (Handle UID mismatch/migration)
        final phone = user.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          // 🔍 Try multiple phone formats to maximize match chance
          final List<String> formats = [phone];
          if (phone.startsWith('+')) {
            formats.add(phone.substring(1)); // e.g. 919876543210
            if (phone.startsWith('+91')) {
              formats.add(phone.substring(3)); // e.g. 9876543210
              formats.add('0${phone.substring(3)}'); // e.g. 09876543210
            }
          }

          debugPrint('🔍 Auto-Linking: Searching formats: $formats');

          for (final p in formats) {
            final querySnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('phoneNumber', isEqualTo: p)
                .limit(1)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              // Found match! Break loop and process.
              final doc = querySnapshot.docs.first;
              final data = doc.data();
              debugPrint('✅ Found existing account by phone ($p): ${doc.id}');

              _remapUserData(data); // Remap fields
              data['uid'] = user.uid; // Unify UID
              prefs.setString('user_data', jsonEncode(data));
              return data;
            }
          }
          // If loop finishes with no match, return null implied.
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Helper for field remapping
  void _remapUserData(Map<String, dynamic> data) {
    if (data['username'] == null && data['Name'] != null)
      data['username'] = data['Name'];
    if (data['Name'] == null && data['username'] != null)
      data['Name'] = data['username'];
    if (data['gender'] == null && data['Gender'] != null)
      data['gender'] = data['Gender'];
    if (data['avatarUrl'] == null && data['ProfilePicture'] != null)
      data['avatarUrl'] = data['ProfilePicture'];
    if (data['email'] == null && data['Email'] != null)
      data['email'] = data['Email'];
    if (data['Email'] == null && data['email'] != null)
      data['Email'] = data['email'];

    // ✅ Fallback to FirebaseAuth email if both are missing
    final user = _auth.currentUser;
    if ((data['email'] == null || data['email'].toString().isEmpty) &&
        user?.email != null) {
      data['email'] = user!.email;
      data['Email'] = user.email;
    }

    // ✅ Remap Phone Number
    if (data['phoneNumber'] == null && data['phonenumber'] != null)
      data['phoneNumber'] = data['phonenumber'];
    if (data['phonenumber'] == null && data['phoneNumber'] != null)
      data['phonenumber'] = data['phoneNumber'];

    // ✅ Sanitize Timestamps for JSON encoding (Critical for SharedPreferences)
    for (var key in data.keys.toList()) {
      final value = data[key];
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      }
    }
  }

  // ✅ Update LOCAL user data (Merge Only)
  Future<void> updateLocalData(Map<String, dynamic> updates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userDataString = prefs.getString('user_data');
      Map<String, dynamic> data = {};

      if (userDataString != null) {
        data = jsonDecode(userDataString);
      }

      // Merge updates
      data.addAll(updates);

      // Sanitize just in case
      _remapUserData(data);

      await prefs.setString('user_data', jsonEncode(data));
      debugPrint('✅ Local user data updated: ${updates.keys}');
    } catch (e) {
      debugPrint('❌ Error updating local data: $e');
    }
  }

  // Update user data from Firestore (refresh)
  Future<void> updateData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Force reload user data from Firestore and Cache it
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _remapUserData(data); // ✅ Remap & Sanitize
          data['uid'] = user.uid;

          final prefs = await SharedPreferences.getInstance();

          // ✅ Preserve Local-Only Fields (Avatar, FCM) if missing in Firestore
          final String? existingJson = prefs.getString('user_data');
          if (existingJson != null) {
            final existingMap = jsonDecode(existingJson);
            if (data['avatarUrl'] == null && existingMap['avatarUrl'] != null) {
              data['avatarUrl'] = existingMap['avatarUrl'];
            }
            if (data['fcmToken'] == null && existingMap['fcmToken'] != null) {
              data['fcmToken'] = existingMap['fcmToken'];
            }
          }

          await prefs.setString('user_data', jsonEncode(data));
          debugPrint(
            'Protocol: User data refreshed from Firestore and Cached.',
          );
        }
      } else {
        debugPrint(
          'Protocol: Update failed - User document missing in Firestore.',
        );
      }
    } catch (e) {
      debugPrint('Error updating user data: $e');
    }
  }
}

// Mock UserCredential class to work around PigeonUserDetails bug
class _MockUserCredential implements UserCredential {
  final User _user;

  _MockUserCredential(this._user);

  @override
  User? get user => _user;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;

  @override
  AuthCredential? get credential => null;
}

