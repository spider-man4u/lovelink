// Admin tool: Upload scene images to Firebase Storage + Firestore
//
// Usage:
//   dart run lib/gallery/admin/upload_images.dart --dir=./images --tags=bedroom,warm,cozy
//
// Or run the Flutter-based UI tool:
//   flutter run -t lib/gallery/admin/uploader_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AdminImageUploader {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  /// Upload a single image with metadata
  Future<void> uploadImage({
    required String filePath,
    required String scene,
    required List<String> tags,
    String? emotion,
    String? weather,
    String? time,
    String? activity,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('File not found: $filePath');
      return;
    }

    final fileName = '${_uuid.v4()}.jpg';
    final storagePath = 'scene_images/$scene/$fileName';

    debugPrint('Uploading $filePath -> $storagePath');

    try {
      // Upload to Firebase Storage
      final task = await _storage.ref(storagePath).putFile(file);
      final downloadUrl = await task.ref.getDownloadURL();

      // Save metadata to Firestore
      await _firestore.collection('scene_images').add({
        'id': _uuid.v4(),
        'imageUrl': downloadUrl,
        'scene': scene,
        'tags': tags,
        // ignore: use_null_aware_elements
        if (emotion != null) 'emotion': emotion,
        // ignore: use_null_aware_elements
        if (weather != null) 'weather': weather,
        // ignore: use_null_aware_elements
        if (time != null) 'time': time,
        // ignore: use_null_aware_elements
        if (activity != null) 'activity': activity,
        'createdAt': DateTime.now().toIso8601String(),
      });

      debugPrint('Uploaded successfully: $scene/$fileName');
    } catch (e) {
      debugPrint('Upload failed: $e');
    }
  }

  /// Bulk upload from a directory structure:
  /// images/
  ///   bedroom/
  ///     img1.jpg
  ///     img2.jpg
  ///   cafe/
  ///     img1.jpg
  Future<void> bulkUploadFromDirectory({
    required String directoryPath,
    Map<String, List<String>>? sceneTags,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) {
      debugPrint('Directory not found: $directoryPath');
      return;
    }

    final folders = dir.listSync().whereType<Directory>();
    for (final folder in folders) {
      final scene = folder.path.split('/').last;
      final tags = sceneTags?[scene] ?? [scene];

      final images = folder.listSync().whereType<File>();
      for (final image in images) {
        if (image.path.endsWith('.jpg') ||
            image.path.endsWith('.png') ||
            image.path.endsWith('.jpeg')) {
          await uploadImage(
            filePath: image.path,
            scene: scene,
            tags: tags,
          );
        }
      }
    }
  }
}
