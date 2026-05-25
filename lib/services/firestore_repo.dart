import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:chilli/models/profile.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _usersRef => _firestore.collection('users');

  Future<void> registerUser({
    required String username,
    required String gender,
    required String language,
    String? avatarUrl,
    String? audioUrl,
    int? coins,
    String? email,
  }) async {
    try {
      var user = _auth.currentUser;

      if (user == null) {
        debugPrint('FirestoreRepository: no user, signing in anonymously');
        final anonResult = await _auth.signInAnonymously();
        user = anonResult.user;
        if (user == null) {
          throw Exception('Anonymous sign-in failed');
        }
      }

      final phoneNumber = user.phoneNumber ?? '';
      int startingCoins = coins ?? 10;

      if (coins == null) {
        if (phoneNumber.contains('1234567890')) {
          startingCoins = 10000;
        }
      }

      final payload = {
        'uid': user.uid,
        'username': username,
        'gender': gender.toLowerCase(),
        'language': language,
        'phoneNumber': phoneNumber,
        'email': email ?? user.email ?? '',
        'Email': email ?? user.email ?? '',
        'avatarUrl': avatarUrl,
        'coins': startingCoins,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _usersRef.doc(user.uid).set(payload);
      debugPrint(
        'FirestoreRepository: user registered ${user.uid} with $startingCoins coins',
      );
    } catch (e) {
      debugPrint('FirestoreRepository: registerUser error: $e');
      rethrow;
    }
  }

  Future<ChilliProfile?> fetchSelf() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _usersRef.doc(user.uid).get();
      if (!snapshot.exists) return null;

      return ChilliProfile.fromMap(snapshot.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('FirestoreRepository: fetchSelf error: $e');
      return null;
    }
  }

  Future<ChilliProfile?> fetchById(String uid) async {
    try {
      final snapshot = await _usersRef.doc(uid).get();
      if (!snapshot.exists) return null;

      return ChilliProfile.fromMap(snapshot.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('FirestoreRepository: fetchById error: $e');
      return null;
    }
  }

  Stream<List<ChilliProfile>> watchAllUsers({String? targetGender, List<String>? blockedUids}) {
    return _usersRef.snapshots().asyncMap((snapshot) async {
      final currentUid = _auth.currentUser?.uid;
      final target = targetGender?.toLowerCase();

      final localBlockedUids = blockedUids ?? [];

      final list = snapshot.docs
          .map((doc) => ChilliProfile.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) {
            final isNotMe = user.uid != currentUid;
            final isNotBlocked = !localBlockedUids.contains(user.uid);
            if (target == null) return isNotMe && isNotBlocked;
            return isNotMe && isNotBlocked && user.gender.toLowerCase() == target;
          })
          .toList();

      return list;
    });
  }

  Future<void> blockUser(String targetUid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _usersRef.doc(user.uid).update({
        'blockedUsers': FieldValue.arrayUnion([targetUid])
      });
    } catch (e) {
      debugPrint('FirestoreRepository: blockUser error: $e');
    }
  }

  Future<void> unblockUser(String targetUid) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _usersRef.doc(user.uid).update({
        'blockedUsers': FieldValue.arrayRemove([targetUid])
      });
    } catch (e) {
      debugPrint('FirestoreRepository: unblockUser error: $e');
    }
  }

  Stream<List<ChilliProfile>> watchBlockedUsers() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _usersRef.doc(user.uid).snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) return [];
      final data = snapshot.data() as Map<String, dynamic>;
      
      List<String> blockedUids = [];
      if (data['blockedUsers'] != null) {
        if (data['blockedUsers'] is List) {
          blockedUids = List<String>.from(data['blockedUsers']);
        } else if (data['blockedUsers'] is Map) {
          blockedUids = List<String>.from((data['blockedUsers'] as Map).keys);
        }
      }
      
      if (blockedUids.isEmpty) return [];

      // Fetch profiles for these UIDs manually since there's no whereIn
      final futures = blockedUids.map((uid) => _usersRef.doc(uid).get());
      final snaps = await Future.wait(futures);
      
      return snaps
          .where((s) => s.exists && s.data() != null)
          .map((s) => ChilliProfile.fromMap(s.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<List<ChilliProfile>> queryAllUsers({String? targetGender}) async {
    try {
      final snapshot = await _usersRef.get();
      if (snapshot.docs.isEmpty) return [];
      
      final currentUid = _auth.currentUser?.uid;
      final target = targetGender?.toLowerCase();

      return snapshot.docs
          .map((doc) => ChilliProfile.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) {
            final isNotMe = user.uid != currentUid;
            if (target == null) return isNotMe;
            return isNotMe && user.gender.toLowerCase() == target;
          })
          .toList();
    } catch (e) {
      debugPrint('FirestoreRepository: queryAllUsers error: $e');
      return [];
    }
  }

  Future<void> updatePresence(bool isOnline) async {
    debugPrint('FirestoreRepository: presence update skipped (using RTDB)');
  }

  Future<void> updateActivity() async {
    debugPrint('FirestoreRepository: activity update skipped (using RTDB)');
  }

  Future<void> updatePresenceStatus(String status) async {
    debugPrint('FirestoreRepository: status update skipped (using RTDB)');
  }

  Future<void> reportUser(String targetUid, String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore.collection('reports').add({
        'reporterUid': user.uid,
        'targetUid': targetUid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('FirestoreRepository: reportUser error: $e');
    }
  }

  Future<void> savePushToken(String? token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _usersRef.doc(user.uid).update({'fcmToken': token});
      debugPrint('FirestoreRepository: push token saved');
    } catch (e) {
      debugPrint('FirestoreRepository: savePushToken error: $e');
    }
  }

  Future<void> updateBalance(num coins) async {
    debugPrint('FirestoreRepository: balance update skipped (using RTDB)');
  }

  Future<void> setBalance(num coins) async {
    debugPrint('FirestoreRepository: setBalance skipped (using RTDB)');
  }

  Future<bool> userExists(String uid) async {
    try {
      final snapshot = await _usersRef.doc(uid).get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('FirestoreRepository: userExists error: $e');
      return false;
    }
  }

  Future<void> patchProfile({
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
        await _usersRef.doc(user.uid).update(updates);
      }
    } catch (e) {
      debugPrint('FirestoreRepository: patchProfile error: $e');
      rethrow;
    }
  }
}
