import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:chilli/models/profile.dart';
import 'package:chilli/utils/avatar_store.dart';
import 'dart:async';

class PresenceRepo {
  late final DatabaseReference _db;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  PresenceRepo() {
    // Explicitly use the database URL from FirebaseOptions to ensure correct instance
    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://nurxian-default-rtdb.firebaseio.com/',
    ).ref();

    // Enable logging for debugging connection issues
    if (kDebugMode) {
      FirebaseDatabase.instance.setLoggingEnabled(true);
    }
  }

  // Sync user profile to RTDB (Split: Static Data -> usersProfile)
  Future<void> syncUserProfile(Profile user) async {
    try {
      // ✅ Write static profile data to 'usersProfile'
      final profileRef = _db.child('usersProfile').child(user.uid);
      final profileMap = user.toRTDBMap();
      await profileRef.set(profileMap);

      // ✅ Update dynamic presence ONLY in userPresence node
      await _db.child('userPresence').child(user.uid).update({
        's': user.status.isNotEmpty ? user.status : 'online',
        'la': ServerValue.timestamp,
      });

      debugPrint(
        '✅ Static Profile -> usersProfile, Dynamic Status -> userPresence',
      );
    } catch (e) {
      debugPrint('❌ Error syncing user profile: $e');
    }
  }

  // Update specific fields in RTDB (Both Nodes)
  Future<void> updateFields(String uid, Map<String, dynamic> updates) async {
    try {
      await _db.child('users').child(uid).update(updates);
      // If profile exists, update corresponding short keys
      final profileUpdates = <String, dynamic>{};
      if (updates.containsKey('username'))
        profileUpdates['n'] = updates['username'];
      if (updates.containsKey('avatarUrl'))
        profileUpdates['a'] = updates['avatarUrl'];

      if (profileUpdates.isNotEmpty) {
        await _db.child('usersProfile').child(uid).update(profileUpdates);
      }

      // Update dynamic lastActive in userPresence if provided
      if (updates.containsKey('lastActive')) {
        final la = updates['lastActive'];
        final ts = la is DateTime ? la.millisecondsSinceEpoch : la;
        await _db.child('userPresence').child(uid).update({'la': ts});
      }
    } catch (e) {
      debugPrint('❌ Error updating fields in RTDB: $e');
    }
  }

  // Update ONLY last active timestamp (Optimized)
  Future<void> updateLastActive() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final ts = ServerValue.timestamp;
      await _db.child('userPresence').child(user.uid).update({'la': ts});
    } catch (e) {
      debugPrint('❌ Error updating lastActive: $e');
    }
  }

  // Update user status (Split: Dynamic Data -> userPresence)
  Future<void> updateUserStatus(String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final presenceRef = _db.child('userPresence').child(user.uid);

      if (status == 'offline') {
        debugPrint('🔴 Setting status to offline in userPresence: ${user.uid}');
        await presenceRef.update({'s': 'offline'});
      } else {
        debugPrint(
          '🔄 Updating status to "$status" in userPresence for user: ${user.uid}',
        );

        await presenceRef.update({
          's': status, // 's' = status
        });

        // ✅ DISABLED: Keep user ALWAYS visible in presence for incoming calls
        // await presenceRef.onDisconnect().remove();
      }

      debugPrint('✅ Status updated in userPresence: $status');
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
    }
  }

  // Update user coins in RTDB
  Future<void> updateCoins(num coins) async {
    // Disabled: User requested offline coin management only - No RTDB sync
    /*
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.child('users').child(user.uid).update({'coins': coins});
      debugPrint('💰 Coins updated in RTDB: $coins');
    } catch (e) {
      debugPrint('❌ Error updating coins in RTDB: $e');
    }
    */
  }

  // Stream of users (Merges usersProfile + userPresence)
  Stream<List<Profile>> getAllUsers({String? targetGender}) {
    debugPrint(
      '📡 getAllUsers MERGED stream requested (target: $targetGender)',
    );

    final controller = StreamController<List<Profile>>();
    List<Profile> cachedUsers = [];
    Map<String, Map<String, dynamic>> presenceInfoMap =
        {}; // ✅ Store full presence data
    bool isProfilesLoaded = false;

    // 1. Listen to Profiles (Filtered)
    Query profileQuery = _db.child('usersProfile');
    if (targetGender != null) {
      String dbGender = targetGender.toLowerCase();
      debugPrint('🔍 Filtering users by gender: $dbGender');
      profileQuery = profileQuery
          .orderByChild('g')
          .equalTo(dbGender)
          .limitToLast(1000);
    } else {
      debugPrint('🔍 No gender filter - showing all users');
      profileQuery = profileQuery.limitToLast(1000);
    }

    void emitMergedList() {
      // Don't emit until we have at least tried to load profiles
      if (!isProfilesLoaded && cachedUsers.isEmpty) return;

      final now = DateTime.now();
      final List<Profile> mergedUsers = [];

      for (var user in cachedUsers) {
        // dynamic status lookup
        final pData = Map<dynamic, dynamic>.from(
          presenceInfoMap[user.uid] ?? {'s': 'offline'},
        );
        String status = pData['s']?.toString() ?? 'offline';

        // ✅ LAST ACTIVE CHECK (30 MINS) - Filter out of UI, but don't delete from DB (Function will handle DB)
        final lastActiveTs =
            pData['la'] ?? user.lastActive?.millisecondsSinceEpoch;
        DateTime? lastActiveDate;

        if (lastActiveTs != null) {
          lastActiveDate = DateTime.fromMillisecondsSinceEpoch(lastActiveTs);
          final diff = now.difference(lastActiveDate);

          // ✅ If last active is more than 15 minutes ago, mark as offline regardless of stored status
          if (diff.inMinutes > 15 &&
              (status == 'online' || status == 'active')) {
            status = 'offline';
          }

          // REMOVED: 30-minute filter to ensure all users are displayed
        } else {
          // ✅ No lastActive data means user is offline
          status = 'offline';
          // ✅ Add a dummy lastActiveDate so the user still shows up and can be sorted
          lastActiveDate = now.subtract(const Duration(days: 7));
        }

        mergedUsers.add(
          user.copyWith(status: status, lastActive: lastActiveDate),
        );
      }

      // ✅ SORT: Active/Online first, then Busy, then Offline
      mergedUsers.sort((a, b) {
        // 1. Status priority (online/active > busy > offline)
        int statusWeight(String s) {
          final lowerStatus = s.toLowerCase();
          if (lowerStatus == 'online' || lowerStatus == 'active')
            return 3; // Highest priority
          if (lowerStatus == 'busy') return 2; // Medium priority
          return 1; // Lowest priority (offline)
        }

        int sA = statusWeight(a.status);
        int sB = statusWeight(b.status);

        // ✅ CRITICAL: Sort by status weight DESCENDING (higher weight = appears first)
        // Online(3) > Busy(2) > Offline(1)
        if (sA != sB)
          return sA.compareTo(sB) * -1; // Multiply by -1 for descending

        // Then sort by last active within each status group (newest first)
        final laA = a.lastActive?.millisecondsSinceEpoch ?? 0;
        final laB = b.lastActive?.millisecondsSinceEpoch ?? 0;
        return laB.compareTo(laA); // Descending: Most recent first
      });

      controller.add(mergedUsers);
    }

    // Sub 1: Profiles
    final profileSub = profileQuery.onValue.listen((event) {
      final profileMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final currentUid = _auth.currentUser?.uid;
      final List<Profile> users = [];

      profileMap.forEach((key, val) {
        if (val is Map) {
          final data = Map<String, dynamic>.from(val);

          // Avatar fix - Replace old Dicebear with new Pinterest avatars
          if (data['a'] != null) {
            String avatar = data['a'].toString();
            if (AvatarStore.isOldAvatar(avatar)) {
              final gender = data['g']?.toString() ?? 'male';
              data['avatarUrl'] = AvatarStore.getRandomAvatar(gender);
              data['a'] = data['avatarUrl'];
            }
          }

          try {
            // Default status will be offline until merged
            final user = Profile.fromMap(data);
            if (user.uid != currentUid) {
              users.add(user);
            }
          } catch (e) {
            // ignore
          }
        }
      });

      cachedUsers = users;
      isProfilesLoaded = true;
      emitMergedList();
    });

    // Sub 2: Presence (Listen to ALL status changes for now)
    final presenceSub = _db.child('userPresence').onValue.listen((event) {
      final pMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      presenceInfoMap.clear();

      pMap.forEach((k, v) {
        if (v is Map) {
          presenceInfoMap[k.toString()] = Map<String, dynamic>.from(v);
        }
      });

      emitMergedList();
    });

    controller.onCancel = () {
      profileSub.cancel();
      presenceSub.cancel();
    };

    return controller.stream;
  }

  // Get users list (One-time fetch with Join)
  Future<List<Profile>> getUsersList({String? targetGender}) async {
    try {
      Query query = _db.child('usersProfile');

      if (targetGender != null) {
        String dbGender = targetGender.toLowerCase();
        // REMOVED capitalization to match stored data format (lowercase)
        query = query.orderByChild('g').equalTo(dbGender).limitToLast(1000);
      } else {
        query = query.limitToLast(1000);
      }

      // Fetch Profiles
      final snapshot = await query.get();
      if (snapshot.value == null) return [];
      final usersMap = snapshot.value as Map?;
      if (usersMap == null) return [];

      // Fetch Presence
      final presenceSnapshot = await _db.child('userPresence').get();
      final presenceMap = presenceSnapshot.value as Map? ?? {};
      final presenceMapStrKeys = presenceMap.map(
        (key, value) => MapEntry(key.toString(), value),
      ); // Normalize keys

      final currentUid = _auth.currentUser?.uid;

      final List<Profile> users = [];
      usersMap.forEach((key, value) {
        try {
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            final uidStr = key.toString();

            // Merge Presence
            String status = 'offline';
            int? lastActiveTs;

            if (presenceMapStrKeys.containsKey(uidStr)) {
              final pData = Map<String, dynamic>.from(
                presenceMapStrKeys[uidStr] as Map,
              );
              status = pData['s']?.toString() ?? 'offline';
              lastActiveTs = pData['la']; // ✅ Added: Merge lastActive timestamp

              // ✅ Validate status based on lastActive
              if (lastActiveTs != null) {
                final lastActiveDate = DateTime.fromMillisecondsSinceEpoch(
                  lastActiveTs,
                );
                final diff = DateTime.now().difference(lastActiveDate);

                // If last active is more than 15 minutes ago, mark as offline
                if (diff.inMinutes > 15 &&
                    (status == 'online' || status == 'active')) {
                  status = 'offline';
                }
              } else {
                // No lastActive data means user is offline
                if (status == 'online' || status == 'active') {
                  status = 'offline';
                }
              }
            }

            data['s'] = status;
            data['la'] = lastActiveTs;

            // Avatar fix - Replace old Dicebear with new Pinterest avatars
            if (data['a'] != null) {
              String avatar = data['a'].toString();
              if (AvatarStore.isOldAvatar(avatar)) {
                final gender = data['g']?.toString() ?? 'male';
                data['avatarUrl'] = AvatarStore.getRandomAvatar(gender);
                data['a'] = data['avatarUrl'];
              }
            }

            final user = Profile.fromMap(data);

            if (user.uid != currentUid) {
              users.add(user);
            }
          }
        } catch (e) {
          debugPrint('❌ Error parsing user from RTDB: $e');
        }
      });

      return users;
    } catch (e) {
      debugPrint('❌ Error getting users list from RTDB: $e');
      return [];
    }
  }
}


