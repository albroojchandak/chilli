import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:chilli/models/profile.dart';
import 'package:chilli/utils/avatar_store.dart';
import 'dart:async';

class PresenceRepository {
  late final DatabaseReference _db;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  PresenceRepository() {
    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://knect-84f31-default-rtdb.firebaseio.com/',
    ).ref();

    if (kDebugMode) {
      FirebaseDatabase.instance.setLoggingEnabled(true);
    }
  }

  Future<void> pushProfileData(ChilliProfile user) async {
    try {
      final profileRef = _db.child('usersProfile').child(user.uid);
      final profileMap = user.toRTDBMap();
      await profileRef.set(profileMap);

      await _db.child('userPresence').child(user.uid).update({
        's': user.status.isNotEmpty ? user.status : 'online',
        'la': ServerValue.timestamp,
      });

      debugPrint('PresenceRepository: profile pushed and presence updated');
    } catch (e) {
      debugPrint('PresenceRepository: pushProfileData error: $e');
    }
  }

  Future<void> patchFields(String uid, Map<String, dynamic> updates) async {
    try {
      await _db.child('users').child(uid).update(updates);
      final profileUpdates = <String, dynamic>{};
      if (updates.containsKey('username'))
        profileUpdates['n'] = updates['username'];
      if (updates.containsKey('avatarUrl'))
        profileUpdates['a'] = updates['avatarUrl'];

      if (profileUpdates.isNotEmpty) {
        await _db.child('usersProfile').child(uid).update(profileUpdates);
      }

      if (updates.containsKey('lastActive')) {
        final la = updates['lastActive'];
        final ts = la is DateTime ? la.millisecondsSinceEpoch : la;
        await _db.child('userPresence').child(uid).update({'la': ts});
      }
    } catch (e) {
      debugPrint('PresenceRepository: patchFields error: $e');
    }
  }

  Future<void> refreshTimestamp() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final ts = ServerValue.timestamp;
      await _db.child('userPresence').child(user.uid).update({'la': ts});
    } catch (e) {
      debugPrint('PresenceRepository: refreshTimestamp error: $e');
    }
  }

  Future<void> setStatus(String status) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final presenceRef = _db.child('userPresence').child(user.uid);

      if (status == 'offline') {
        debugPrint('PresenceRepository: setting offline for ${user.uid}');
        await presenceRef.update({'s': 'offline'});
      } else {
        debugPrint('PresenceRepository: setting "$status" for ${user.uid}');

        await presenceRef.update({'s': status});
      }

      debugPrint('PresenceRepository: status set to $status');
    } catch (e) {
      debugPrint('PresenceRepository: setStatus error: $e');
    }
  }

  Future<void> syncBalance(num coins) async {}

  Stream<List<ChilliProfile>> watchUsers({String? targetGender}) {
    debugPrint(
      'PresenceRepository: watchUsers requested (target: $targetGender)',
    );

    final controller = StreamController<List<ChilliProfile>>();
    List<ChilliProfile> cachedUsers = [];
    Map<String, Map<String, dynamic>> presenceInfoMap = {};
    bool isProfilesLoaded = false;

    Query profileQuery = _db.child('usersProfile');
    if (targetGender != null) {
      String dbGender = targetGender.toLowerCase();
      debugPrint('PresenceRepository: filtering by gender: $dbGender');
      profileQuery = profileQuery
          .orderByChild('g')
          .equalTo(dbGender)
          .limitToLast(1000);
    } else {
      debugPrint('PresenceRepository: no gender filter');
      profileQuery = profileQuery.limitToLast(1000);
    }

    void emitMerged() {
      if (!isProfilesLoaded && cachedUsers.isEmpty) return;

      final now = DateTime.now();
      final List<ChilliProfile> mergedUsers = [];

      for (var user in cachedUsers) {
        final pData = Map<dynamic, dynamic>.from(
          presenceInfoMap[user.uid] ?? {'s': 'offline'},
        );
        String status = pData['s']?.toString() ?? 'offline';

        final lastActiveTs =
            pData['la'] ?? user.lastActive?.millisecondsSinceEpoch;
        DateTime? lastActiveDate;

        if (lastActiveTs != null) {
          lastActiveDate = DateTime.fromMillisecondsSinceEpoch(lastActiveTs);
          final diff = now.difference(lastActiveDate);

          if (diff.inMinutes > 15 &&
              (status == 'online' || status == 'active')) {
            status = 'offline';
          }

          if (diff.inMinutes > 30) continue;
        } else {
          if (status == 'online' || status == 'active') {
            status = 'offline';
          }
          continue;
        }

        mergedUsers.add(
          user.copyWith(status: status, lastActive: lastActiveDate),
        );
      }

      mergedUsers.sort((a, b) {
        int statusWeight(String s) {
          final lowerStatus = s.toLowerCase();
          if (lowerStatus == 'online' || lowerStatus == 'active') return 3;
          if (lowerStatus == 'busy') return 2;
          return 1;
        }

        int sA = statusWeight(a.status);
        int sB = statusWeight(b.status);

        if (sA != sB) return sA.compareTo(sB) * -1;

        final laA = a.lastActive?.millisecondsSinceEpoch ?? 0;
        final laB = b.lastActive?.millisecondsSinceEpoch ?? 0;
        return laB.compareTo(laA);
      });

      controller.add(mergedUsers);
    }

    final profileSub = profileQuery.onValue.listen((event) {
      final profileMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final currentUid = _auth.currentUser?.uid;
      final List<ChilliProfile> users = [];

      profileMap.forEach((key, val) {
        if (val is Map) {
          final data = Map<String, dynamic>.from(val);

          if (data['a'] != null) {
            String avatar = data['a'].toString();
            if (AvatarVault.isLegacyAvatar(avatar)) {
              final gender = data['g']?.toString() ?? 'male';
              data['avatarUrl'] = AvatarVault.resolveRandom(gender);
              data['a'] = data['avatarUrl'];
            }
          }

          try {
            final user = ChilliProfile.fromMap(data);
            if (user.uid != currentUid) {
              users.add(user);
            }
          } catch (e) {}
        }
      });

      cachedUsers = users;
      isProfilesLoaded = true;
      emitMerged();
    });

    final presenceSub = _db.child('userPresence').onValue.listen((event) {
      final pMap = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      presenceInfoMap.clear();

      pMap.forEach((k, v) {
        if (v is Map) {
          presenceInfoMap[k.toString()] = Map<String, dynamic>.from(v);
        }
      });

      emitMerged();
    });

    controller.onCancel = () {
      profileSub.cancel();
      presenceSub.cancel();
    };

    return controller.stream;
  }

  Future<List<ChilliProfile>> queryUsers({String? targetGender}) async {
    try {
      Query query = _db.child('usersProfile');

      if (targetGender != null) {
        String dbGender = targetGender.toLowerCase();
        query = query.orderByChild('g').equalTo(dbGender).limitToLast(1000);
      } else {
        query = query.limitToLast(1000);
      }

      final snapshot = await query.get();
      if (snapshot.value == null) return [];
      final usersMap = snapshot.value as Map?;
      if (usersMap == null) return [];

      final presenceSnapshot = await _db.child('userPresence').get();
      final presenceMap = presenceSnapshot.value as Map? ?? {};
      final presenceMapStrKeys = presenceMap.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      final currentUid = _auth.currentUser?.uid;

      final List<ChilliProfile> users = [];
      usersMap.forEach((key, value) {
        try {
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            final uidStr = key.toString();

            String status = 'offline';
            int? lastActiveTs;

            if (presenceMapStrKeys.containsKey(uidStr)) {
              final pData = Map<String, dynamic>.from(
                presenceMapStrKeys[uidStr] as Map,
              );
              status = pData['s']?.toString() ?? 'offline';
              lastActiveTs = pData['la'];

              if (lastActiveTs != null) {
                final lastActiveDate = DateTime.fromMillisecondsSinceEpoch(
                  lastActiveTs,
                );
                final diff = DateTime.now().difference(lastActiveDate);

                if (diff.inMinutes > 15 &&
                    (status == 'online' || status == 'active')) {
                  status = 'offline';
                }
              } else {
                if (status == 'online' || status == 'active') {
                  status = 'offline';
                }
              }
            }

            data['s'] = status;
            data['la'] = lastActiveTs;

            if (data['a'] != null) {
              String avatar = data['a'].toString();
              if (AvatarVault.isLegacyAvatar(avatar)) {
                final gender = data['g']?.toString() ?? 'male';
                data['avatarUrl'] = AvatarVault.resolveRandom(gender);
                data['a'] = data['avatarUrl'];
              }
            }

            final user = ChilliProfile.fromMap(data);

            if (user.uid != currentUid) {
              users.add(user);
            }
          }
        } catch (e) {
          debugPrint('PresenceRepository: parse error: $e');
        }
      });

      return users;
    } catch (e) {
      debugPrint('PresenceRepository: queryUsers error: $e');
      return [];
    }
  }
}
