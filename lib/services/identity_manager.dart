import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

class IdentityManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendPhoneCode({
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
          debugPrint('IdentityManager: codeSent id=$verificationId');
          try {
            onCodeSent(verificationId, resendToken);
          } catch (e) {
            debugPrint('IdentityManager: onCodeSent callback error: $e');
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onAutoRetrievalTimeout(verificationId);
        },
        forceResendingToken: forceResendingToken,
      );
    } catch (e) {
      debugPrint('IdentityManager: sendPhoneCode error: $e');
      rethrow;
    }
  }

  Future<UserCredential> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User is null after sign in',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('IdentityManager: FirebaseAuth error ${e.code}: ${e.message}');
      rethrow;
    } on TypeError catch (e) {
      debugPrint('IdentityManager: TypeError (PigeonUserDetails): $e');

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        debugPrint('IdentityManager: user still signed in, proceeding');
        return Future.value(_buildMockCredential(currentUser));
      }

      throw FirebaseAuthException(
        code: 'type-error',
        message: 'Authentication type error. Please try again.',
      );
    } catch (e) {
      debugPrint('IdentityManager: unexpected error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> loginWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('IdentityManager: Google login error: $e');
      return null;
    }
  }

  UserCredential _buildMockCredential(User user) {
    return _FallbackCredential(user);
  }

  Future<void> logout() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('IdentityManager: Google signout error: $e');
    }
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  User? get activeUser => _auth.currentUser;

  Future<Map<String, dynamic>?> loadProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('user_data');
      if (cached != null) {
        try {
          final dynamic decoded = jsonDecode(cached);
          if (decoded is Map<String, dynamic> && decoded['uid'] == user.uid) {
            final data = Map<String, dynamic>.from(decoded);
            _normalizeFields(data);
            debugPrint('IdentityManager: using cached profile');
            return data;
          }
        } catch (e) {
          debugPrint('IdentityManager: cache decode error: $e');
        }
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _normalizeFields(data);
          data['uid'] = user.uid;

          // Preserve local coins
          final String? existingJson = prefs.getString('user_data');
          if (existingJson != null) {
            final existingMap = jsonDecode(existingJson);
            if (existingMap['coins'] != null) {
              data['coins'] = existingMap['coins'];
            }
          }

          prefs.setString('user_data', jsonEncode(data));
        }
        return data;
      } else {
        final phone = user.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          final List<String> formats = [phone];
          if (phone.startsWith('+')) {
            formats.add(phone.substring(1));
            if (phone.startsWith('+91')) {
              formats.add(phone.substring(3));
              formats.add('0${phone.substring(3)}');
            }
          }

          debugPrint('IdentityManager: searching formats: $formats');

          for (final p in formats) {
            final querySnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('phoneNumber', isEqualTo: p)
                .limit(1)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              final doc = querySnapshot.docs.first;
              final data = doc.data();
              debugPrint('IdentityManager: found by phone ($p): ${doc.id}');

              _normalizeFields(data);
              data['uid'] = user.uid;

              // Preserve local coins
              final String? existingJson = prefs.getString('user_data');
              if (existingJson != null) {
                final existingMap = jsonDecode(existingJson);
                if (existingMap['coins'] != null) {
                  data['coins'] = existingMap['coins'];
                }
              }

              prefs.setString('user_data', jsonEncode(data));
              return data;
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('IdentityManager: loadProfile error: $e');
      return null;
    }
  }

  void _normalizeFields(Map<String, dynamic> data) {
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

    final user = _auth.currentUser;
    if ((data['email'] == null || data['email'].toString().isEmpty) &&
        user?.email != null) {
      data['email'] = user!.email;
      data['Email'] = user.email;
    }

    if (data['phoneNumber'] == null && data['phonenumber'] != null)
      data['phoneNumber'] = data['phonenumber'];
    if (data['phonenumber'] == null && data['phoneNumber'] != null)
      data['phonenumber'] = data['phoneNumber'];

    for (var key in data.keys.toList()) {
      final value = data[key];
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      }
    }
  }

  Future<void> patchLocalProfile(Map<String, dynamic> updates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existing = prefs.getString('user_data');
      Map<String, dynamic> data = {};

      if (existing != null) {
        data = jsonDecode(existing);
      }

      data.addAll(updates);
      _normalizeFields(data);

      await prefs.setString('user_data', jsonEncode(data));
      debugPrint('IdentityManager: local profile patched: ${updates.keys}');
    } catch (e) {
      debugPrint('IdentityManager: patchLocalProfile error: $e');
    }
  }

  Future<void> refreshFromRemote() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _normalizeFields(data);
          data['uid'] = user.uid;

          final prefs = await SharedPreferences.getInstance();

          final String? existingJson = prefs.getString('user_data');
          if (existingJson != null) {
            final existingMap = jsonDecode(existingJson);
            if (data['avatarUrl'] == null && existingMap['avatarUrl'] != null) {
              data['avatarUrl'] = existingMap['avatarUrl'];
            }
            if (data['fcmToken'] == null && existingMap['fcmToken'] != null) {
              data['fcmToken'] = existingMap['fcmToken'];
            }
            if (existingMap['coins'] != null) {
              data['coins'] = existingMap['coins'];
            }
          }

          await prefs.setString('user_data', jsonEncode(data));
          debugPrint('IdentityManager: profile refreshed from remote');
        }
      } else {
        debugPrint('IdentityManager: remote profile not found');
      }
    } catch (e) {
      debugPrint('IdentityManager: refreshFromRemote error: $e');
    }
  }
}

class _FallbackCredential implements UserCredential {
  final User _user;

  _FallbackCredential(this._user);

  @override
  User? get user => _user;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;

  @override
  AuthCredential? get credential => null;
}
