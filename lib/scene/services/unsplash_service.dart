import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/scene_model.dart';
import '../../gallery/models/gallery_image_model.dart';

class UnsplashService {
  final String accessKey;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UnsplashService(this.accessKey);

  Future<List<GalleryImageModel>> searchSceneImages(SceneModel scene) async {
    final query = _buildQuery(scene);
    final cached = await _getCached(scene.scene);
    if (cached.length >= 5) return cached;

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.unsplash.com/search/photos'
          '?query=$query&per_page=10&orientation=squarish',
        ),
        headers: {'Authorization': 'Client-ID $accessKey'},
      );

      if (response.statusCode != 200) {
        return cached;
      }

      final data = jsonDecode(response.body);
      final results = data['results'] as List<dynamic>? ?? [];
      final images = <GalleryImageModel>[];

      final batch = _firestore.batch();

      for (final r in results) {
        final id = 'unsplash_${r['id']}';
        final urls = r['urls'] as Map<String, dynamic>? ?? {};
        final imageUrl = urls['regular'] as String? ?? '';
        final rawTags = r['tags'] as List<dynamic>? ?? [];
        final alt = r['alt_description'] as String? ?? '';
        final tags = <String>[
          scene.scene,
          scene.emotion,
          if (scene.activity != null) scene.activity!,
          ...rawTags
              .map((t) => (t is Map ? t['title'] : t?.toString()) ?? '')
              .where((t) => t.isNotEmpty)
              .take(5),
          ...alt.split(' ').where((w) => w.length > 2),
        ];

        final image = GalleryImageModel(
          id: id,
          imageUrl: imageUrl,
          tags: tags.toSet().toList(),
          scene: scene.scene,
          emotion: scene.emotion != 'neutral' ? scene.emotion : null,
          time: scene.time,
          activity: scene.activity,
        );

        images.add(image);
        batch.set(
          _firestore.collection('scene_images').doc(id),
          image.toJson(),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      return images;
    } catch (_) {
      return cached;
    }
  }

  String _buildQuery(SceneModel scene) {
    final parts = <String>[scene.scene];
    if (scene.emotion != 'neutral') parts.add(scene.emotion);
    if (scene.activity != null) parts.add(scene.activity!);
    return parts.join('+');
  }

  Future<List<GalleryImageModel>> _getCached(String sceneName) async {
    final snapshot = await _firestore
        .collection('scene_images')
        .where('scene', isEqualTo: sceneName)
        .limit(10)
        .get();
    return snapshot.docs
        .map((doc) => GalleryImageModel.fromJson(doc.data()))
        .toList();
  }
}
