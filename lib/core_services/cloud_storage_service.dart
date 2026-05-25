import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class CloudStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload audio voice intro
  Future<String?> uploadAudio(File audioFile, String userId) async {
    try {
      final ref = _storage.ref().child('voice_intros/$userId.m4a');
      final task = ref.putFile(audioFile);
      final snapshot = await task;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Audio uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading audio: $e');
      if (e.toString().contains('404') ||
          e.toString().contains('object-not-found')) {
        debugPrint(
          '🚨 CRITICAL: Firebase Storage Bucket not found or not initialized.',
        );
        debugPrint(
          '👉 ACTION REQUIRED: Go to Firebase Console > Storage and click "Get Started" to create the bucket.',
        );
      }
      return null;
    }
  }

  // Upload profile image
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      debugPrint('📤 Uploading profile image for user: $userId');
      debugPrint('📁 Image file path: ${imageFile.path}');
      debugPrint('📏 Image file size: ${imageFile.lengthSync()} bytes');

      final ref = _storage.ref().child('user_avatars/$userId.jpg');
      final task = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await task;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');

      if (e.toString().contains('404') ||
          e.toString().contains('object-not-found') ||
          e.toString().contains('storage/bucket-not-found')) {
        debugPrint(
          '🚨 CRITICAL: Firebase Storage Bucket not found or not initialized.',
        );
        debugPrint(
          '👉 ACTION REQUIRED: Go to Firebase Console > Storage and click "Get Started" to create the bucket.',
        );
      } else if (e.toString().contains('unauthorized') ||
          e.toString().contains('permission-denied')) {
        debugPrint('🚨 PERMISSION ERROR: Check Firebase Storage Rules.');
      } else if (e.toString().contains('network')) {
        debugPrint('🚨 NETWORK ERROR: Check internet connection.');
      }

      return null;
    }
  }
}
