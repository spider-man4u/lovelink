import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/gallery_service.dart';
import '../models/gallery_image_model.dart';

final galleryServiceProvider = Provider<GalleryService>((ref) {
  return GalleryService();
});

final sceneImagesProvider =
    FutureProvider.family<List<GalleryImageModel>, Map<String, dynamic>>(
  (ref, params) {
    final galleryService = ref.watch(galleryServiceProvider);
    return galleryService.searchImages(
      scene: params['scene'] as String?,
      emotion: params['emotion'] as String?,
      weather: params['weather'] as String?,
      time: params['time'] as String?,
      activity: params['activity'] as String?,
      tags: params['tags'] as List<String>?,
    );
  },
);
