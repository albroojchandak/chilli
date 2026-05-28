import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chilli/models/profile.dart';

class FirestoreRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Create or update user in Firestore
  Future<void> createUser({
    required String username,
    required String gender,
    required String language,
    String? avatarUrl,
    String? audioUrl,
    int? coins,
    String? email, // ✅ Added email parameter
  }) async {
    try {
      var user = _auth.currentUser;

      // If there's no signed-in user, sign in anonymously so we can
      // still create a user document and proceed without blocking.
      if (user == null) {
        debugPrint('No authenticated user found — signing in anonymously');
        final anonResult = await _auth.signInAnonymously();
        user = anonResult.user;
        if (user == null) {
          throw Exception('Failed to sign in anonymously');
        }
      }

      final phoneNumber = user.phoneNumber ?? ''; // Define here used later
      int startingCoins = coins ?? 10;

      if (coins == null) {
        if (phoneNumber.contains('9755449682')) {
          startingCoins = 10000;
        }
      }

      // Create new user in Firestore (Updated to include email & avatar)
      final minimalData = {
        'uid': user.uid,
        'username': username,
        'gender': gender.toLowerCase(),
        'language': language,
        'phoneNumber': phoneNumber,
        'email': email ?? user.email ?? '', // lowercase
        'Email': email ?? user.email ?? '', // Uppercase (alias)
        'avatarUrl': avatarUrl, // Include avatar
        'coins': startingCoins, // Include starting coins
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _usersCollection.doc(user.uid).set(minimalData);
      debugPrint(
        'User created successfully: ${user.uid} with $startingCoins coins',
      );
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  // Get current user data
  Future<Profile?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _usersCollection.doc(user.uid).get();
      if (!doc.exists) return null;

      return Profile.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Get user by ID
  Future<Profile?> getUserById(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return null;

      return Profile.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  // Stream of all users (for home screen) - Filtered in Dart for maximum reliability
  Stream<List<Profile>> getAllUsers({String? targetGender}) {
    return _usersCollection.snapshots().map((snapshot) {
      final currentUid = _auth.currentUser?.uid;
      final target = targetGender?.toLowerCase();

      print('🔥 Firestore Snapshot: ${snapshot.docs.length} users found in DB');

      final list = snapshot.docs
          .map((doc) => Profile.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) {
            final isNotMe = user.uid != currentUid;
            if (target == null) return isNotMe;
            return isNotMe && user.gender.toLowerCase() == target;
          })
          .toList();

      print('✅ Final Filtered List: ${list.length} users (Filter: $target)');
      return list;
    });
  }

  // Get users list (one-time fetch) - Filtered in Dart for maximum reliability
  Future<List<Profile>> getUsersList({String? targetGender}) async {
    try {
      final snapshot = await _usersCollection.get();
      final currentUid = _auth.currentUser?.uid;
      final target = targetGender?.toLowerCase();

      return snapshot.docs
          .map((doc) => Profile.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) {
            final isNotMe = user.uid != currentUid;
            if (target == null) return isNotMe;
            return isNotMe && user.gender.toLowerCase() == target;
          })
          .toList();
    } catch (e) {
      debugPrint('Error getting users list: $e');
      return [];
    }
  }

  // Update user online status and lastActive (SKIPPED for Firestore as per user request)
  Future<void> updateOnlineStatus(bool isOnline) async {
    // Moved to Realtime Database
    debugPrint('ℹ️ Firestore updateOnlineStatus skipped (using RTDB)');
  }

  // ✅ Update last active timestamp (SKIPPED for Firestore as per user request)
  Future<void> updateLastActive() async {
    // Moved to Realtime Database
    debugPrint('ℹ️ Firestore updateLastActive skipped (using RTDB)');
  }

  // ✅ Update user status (online/offline/busy) (SKIPPED for Firestore as per user request)
  Future<void> updateUserStatus(String status) async {
    // Moved to Realtime Database
    debugPrint('ℹ️ Firestore updateUserStatus skipped (using RTDB)');
  }

  // Update FCM Token (Still useful in Firestore for notifications)
  Future<void> updateFCMToken(String? token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _usersCollection.doc(user.uid).update({'fcmToken': token});
      debugPrint('FCM Token updated in Firestore');
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Update user coins (increment) (SKIPPED for Firestore as per user request)
  Future<void> updateCoins(num coins) async {
    // Moved to Realtime Database
    debugPrint('ℹ️ Firestore updateCoins skipped (using RTDB)');
  }

  // ✅ Set user coins (direct value, not increment) (SKIPPED for Firestore as per user request)
  Future<void> setCoins(num coins) async {
    // Moved to Realtime Database
    debugPrint('ℹ️ Firestore setCoins skipped (using RTDB)');
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking if user exists: $e');
      return false;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? username,
    String? avatarUrl,
    String? language,
    String? gender,
    String? audioUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      Map<String, dynamic> updates = {};
      if (username != null) updates['username'] = username;
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
      if (language != null) updates['language'] = language;
      if (gender != null) updates['gender'] = gender;
      if (audioUrl != null) updates['audioUrl'] = audioUrl;

      if (updates.isNotEmpty) {
        await _usersCollection.doc(user.uid).update(updates);
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
}


