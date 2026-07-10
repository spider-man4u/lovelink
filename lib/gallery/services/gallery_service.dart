import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gallery_image_model.dart';

class GalleryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<GalleryImageModel>> searchImages({
    String? scene,
    String? emotion,
    String? weather,
    String? time,
    String? activity,
    List<String>? tags,
  }) async {
    var query = _firestore.collection('scene_images').limit(20);

    if (scene != null) {
      query = query.where('scene', isEqualTo: scene);
    }
    if (emotion != null) {
      query = query.where('emotion', isEqualTo: emotion);
    }
    if (weather != null) {
      query = query.where('weather', isEqualTo: weather);
    }

    final snapshot = await query.get();
    final results = snapshot.docs
        .map((doc) => GalleryImageModel.fromJson(doc.data()))
        .toList();

    // Sort by tag match score if tags provided
    if (tags != null && tags.isNotEmpty) {
      results.sort((a, b) {
        final aScore = _tagMatchScore(a, tags);
        final bScore = _tagMatchScore(b, tags);
        return bScore.compareTo(aScore);
      });
    }

    return results;
  }

  int _tagMatchScore(GalleryImageModel image, List<String> queryTags) {
    int score = 0;
    for (final tag in queryTags) {
      if (image.tags.any((t) => t.toLowerCase().contains(tag.toLowerCase()))) {
        score++;
      }
    }
    return score;
  }

  Future<List<GalleryImageModel>> getImagesByScene(String scene) async {
    final snapshot = await _firestore
        .collection('scene_images')
        .where('scene', isEqualTo: scene)
        .get();
    return snapshot.docs
        .map((doc) => GalleryImageModel.fromJson(doc.data()))
        .toList();
  }
}
