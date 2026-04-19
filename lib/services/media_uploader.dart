import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class MediaUploader {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadVoiceClip(File audioFile, String userId) async {
    try {
      final ref = _storage.ref().child('voice_intros/$userId.m4a');
      final task = ref.putFile(audioFile);
      final snapshot = await task;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('MediaUploader: voice clip uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('MediaUploader: uploadVoiceClip error: $e');
      if (e.toString().contains('404') ||
          e.toString().contains('object-not-found')) {
        debugPrint('MediaUploader: storage bucket not found');
      }
      return null;
    }
  }

  Future<String?> uploadAvatar(String userId, File imageFile) async {
    try {
      debugPrint('MediaUploader: uploading avatar for $userId');

      final ref = _storage.ref().child('user_avatars/$userId.jpg');
      final task = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await task;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('MediaUploader: avatar uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('MediaUploader: uploadAvatar error: $e');

      if (e.toString().contains('404') ||
          e.toString().contains('object-not-found') ||
          e.toString().contains('storage/bucket-not-found')) {
        debugPrint('MediaUploader: bucket not found');
      } else if (e.toString().contains('unauthorized') ||
          e.toString().contains('permission-denied')) {
        debugPrint('MediaUploader: permission denied');
      } else if (e.toString().contains('network')) {
        debugPrint('MediaUploader: network error');
      }

      return null;
    }
  }
}
