import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedSceneImages() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('scene_images_seeded') == true) return;

    final batch = _firestore.batch();

    for (final entry in _sceneImages.entries) {
      final id = entry.key;
      final data = entry.value;
      batch.set(
        _firestore.collection('scene_images').doc(id),
        data,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    await prefs.setBool('scene_images_seeded', true);
  }

  static const _sceneImages = <String, Map<String, dynamic>>{
    // Cafe
    'curated_cafe_1': {
      'id': 'curated_cafe_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=600&q=80',
      'tags': ['cafe', 'coffee', 'warm', 'romantic'],
      'scene': 'cafe',
      'emotion': 'romantic',
      'time': 'morning',
    },
    'curated_cafe_2': {
      'id': 'curated_cafe_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=600&q=80',
      'tags': ['cafe', 'coffee', 'morning', 'sunlight'],
      'scene': 'cafe',
      'time': 'morning',
    },
    'curated_cafe_3': {
      'id': 'curated_cafe_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=600&q=80',
      'tags': ['cafe', 'coffee', 'rain', 'window'],
      'scene': 'cafe',
      'weather': 'rainy',
    },
    'curated_cafe_4': {
      'id': 'curated_cafe_4',
      'imageUrl':
          'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=600&q=80',
      'tags': ['cafe', 'coffee', 'evening', 'lights'],
      'scene': 'cafe',
      'time': 'evening',
    },
    'curated_cafe_5': {
      'id': 'curated_cafe_5',
      'imageUrl':
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&q=80',
      'tags': ['cafe', 'coffee', 'latte', 'heart'],
      'scene': 'cafe',
      'emotion': 'romantic',
    },

    // Bedroom
    'curated_bedroom_1': {
      'id': 'curated_bedroom_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1522771739014-7ebf622b2a8f?w=600&q=80',
      'tags': ['bedroom', 'bed', 'cozy', 'warm', 'morning'],
      'scene': 'bedroom',
      'time': 'morning',
      'emotion': 'romantic',
    },
    'curated_bedroom_2': {
      'id': 'curated_bedroom_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1598928506311-c55ez9e0e5f7?w=600&q=80',
      'tags': ['bedroom', 'cozy', 'night', 'lights'],
      'scene': 'bedroom',
      'time': 'night',
      'emotion': 'romantic',
    },
    'curated_bedroom_3': {
      'id': 'curated_bedroom_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1540518614846-7eded433c457?w=600&q=80',
      'tags': ['bedroom', 'romantic', 'candle', 'rose'],
      'scene': 'bedroom',
      'emotion': 'romantic',
    },
    'curated_bedroom_4': {
      'id': 'curated_bedroom_4',
      'imageUrl':
          'https://images.unsplash.com/photo-1616046229478-9901c5536a45?w=600&q=80',
      'tags': ['bedroom', 'sunrise', 'light', 'peaceful'],
      'scene': 'bedroom',
      'time': 'morning',
      'emotion': 'happy',
    },
    'curated_bedroom_5': {
      'id': 'curated_bedroom_5',
      'imageUrl':
          'https://images.unsplash.com/photo-1582582624459-3f4c1b9db2b3?w=600&q=80',
      'tags': ['bedroom', 'rain', 'window', 'cozy'],
      'scene': 'bedroom',
      'weather': 'rainy',
      'emotion': 'comforting',
    },

    // Beach
    'curated_beach_1': {
      'id': 'curated_beach_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&q=80',
      'tags': ['beach', 'ocean', 'sunset', 'romantic'],
      'scene': 'beach',
      'time': 'evening',
      'emotion': 'romantic',
    },
    'curated_beach_2': {
      'id': 'curated_beach_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?w=600&q=80',
      'tags': ['beach', 'sunset', 'couple', 'silhouette'],
      'scene': 'beach',
      'time': 'evening',
      'emotion': 'romantic',
    },
    'curated_beach_3': {
      'id': 'curated_beach_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1519046904884-53103b34b689?w=600&q=80',
      'tags': ['beach', 'sea', 'waves', 'ocean'],
      'scene': 'beach',
      'emotion': 'happy',
    },
    'curated_beach_4': {
      'id': 'curated_beach_4',
      'imageUrl':
          'https://images.unsplash.com/photo-1505228395891-9a51e7e86bf6?w=600&q=80',
      'tags': ['beach', 'walk', 'couple', 'sunset'],
      'scene': 'beach',
      'activity': 'walking',
      'time': 'evening',
      'emotion': 'romantic',
    },
    'curated_beach_5': {
      'id': 'curated_beach_5',
      'imageUrl':
          'https://images.unsplash.com/photo-1532619187609-e3a0fa5e1a39?w=600&q=80',
      'tags': ['beach', 'driftwood', 'sunset', 'romantic'],
      'scene': 'beach',
      'time': 'evening',
      'emotion': 'romantic',
    },

    // Park
    'curated_park_1': {
      'id': 'curated_park_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1448375240586-882707db888b?w=600&q=80',
      'tags': ['park', 'forest', 'sunlight', 'nature'],
      'scene': 'park',
      'time': 'morning',
      'emotion': 'happy',
    },
    'curated_park_2': {
      'id': 'curated_park_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1490750967868-88aa4f44baee?w=600&q=80',
      'tags': ['park', 'walk', 'flowers', 'spring'],
      'scene': 'park',
      'activity': 'walking',
      'emotion': 'happy',
    },
    'curated_park_3': {
      'id': 'curated_park_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1519331379826-f10be5486c6f?w=600&q=80',
      'tags': ['park', 'bench', 'lake', 'sunset'],
      'scene': 'park',
      'time': 'evening',
      'emotion': 'romantic',
    },
    'curated_park_4': {
      'id': 'curated_park_4',
      'imageUrl':
          'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=600&q=80',
      'tags': ['park', 'garden', 'flowers', 'path'],
      'scene': 'park',
      'emotion': 'happy',
    },
    'curated_park_5': {
      'id': 'curated_park_5',
      'imageUrl':
          'https://images.unsplash.com/photo-1564419320508-ba5fb8c0f5c9?w=600&q=80',
      'tags': ['park', 'trees', 'fog', 'morning', 'mystical'],
      'scene': 'park',
      'time': 'morning',
      'emotion': 'happy',
    },

    // Rain
    'curated_rain_1': {
      'id': 'curated_rain_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1501691223387-dd0500403074?w=600&q=80',
      'tags': ['rain', 'window', 'city', 'night'],
      'scene': 'rain',
      'weather': 'rainy',
      'time': 'night',
      'emotion': 'emotional',
    },
    'curated_rain_2': {
      'id': 'curated_rain_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1519692933481-e162a57d6721?w=600&q=80',
      'tags': ['rain', 'street', 'lights', 'night'],
      'scene': 'rain',
      'weather': 'rainy',
      'time': 'night',
      'emotion': 'emotional',
    },
    'curated_rain_3': {
      'id': 'curated_rain_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1428592953211-077101b2021b?w=600&q=80',
      'tags': ['rain', 'umbrella', 'street', 'walk'],
      'scene': 'rain',
      'weather': 'rainy',
      'activity': 'walking',
      'emotion': 'romantic',
    },
    'curated_rain_4': {
      'id': 'curated_rain_4',
      'imageUrl':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&q=80',
      'tags': ['rain', 'coffee', 'window', 'cozy'],
      'scene': 'rain',
      'weather': 'rainy',
      'emotion': 'comforting',
    },
    'curated_rain_5': {
      'id': 'curated_rain_5',
      'imageUrl':
          'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=600&q=80',
      'tags': ['rain', 'car', 'window', 'drops'],
      'scene': 'rain',
      'weather': 'rainy',
      'emotion': 'emotional',
    },

    // Sunset
    'curated_sunset_1': {
      'id': 'curated_sunset_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1506152983158-b4a74a01c721?w=600&q=80',
      'tags': ['sunset', 'sky', 'clouds', 'romantic'],
      'scene': 'sunset',
      'time': 'evening',
      'emotion': 'romantic',
    },
    'curated_sunset_2': {
      'id': 'curated_sunset_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1473073899705-e7b1055a7419?w=600&q=80',
      'tags': ['sunset', 'ocean', 'horizon', 'golden'],
      'scene': 'sunset',
      'time': 'evening',
      'emotion': 'romantic',
    },
    'curated_sunset_3': {
      'id': 'curated_sunset_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=600&q=80',
      'tags': ['sunset', 'mountains', 'silhouette', 'couple'],
      'scene': 'sunset',
      'time': 'evening',
      'emotion': 'romantic',
    },

    // Airport
    'curated_airport_1': {
      'id': 'curated_airport_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=600&q=80',
      'tags': ['airport', 'plane', 'travel', 'departure'],
      'scene': 'airport',
      'emotion': 'emotional',
    },
    'curated_airport_2': {
      'id': 'curated_airport_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=600&q=80',
      'tags': ['airport', 'reunion', 'hug', 'couple'],
      'scene': 'airport',
      'emotion': 'emotional',
    },
    'curated_airport_3': {
      'id': 'curated_airport_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1556388158-158ea5ccacbd?w=600&q=80',
      'tags': ['airport', 'runway', 'sunset', 'plane'],
      'scene': 'airport',
      'time': 'evening',
      'emotion': 'emotional',
    },

    // Kitchen
    'curated_kitchen_1': {
      'id': 'curated_kitchen_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=600&q=80',
      'tags': ['kitchen', 'cooking', 'dinner', 'romantic'],
      'scene': 'kitchen',
      'activity': 'cooking',
      'emotion': 'romantic',
    },
    'curated_kitchen_2': {
      'id': 'curated_kitchen_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1551218808-94e220e084d2?w=600&q=80',
      'tags': ['kitchen', 'dinner', 'candle', 'romantic'],
      'scene': 'kitchen',
      'activity': 'cooking',
      'emotion': 'romantic',
    },
    'curated_kitchen_3': {
      'id': 'curated_kitchen_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1460899960812-f6ee1ecaf117?w=600&q=80',
      'tags': ['kitchen', 'breakfast', 'morning', 'sunlight'],
      'scene': 'kitchen',
      'time': 'morning',
      'emotion': 'happy',
    },

    // Romantic (generic)
    'curated_romantic_1': {
      'id': 'curated_romantic_1',
      'imageUrl':
          'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=600&q=80',
      'tags': ['romantic', 'couple', 'date', 'candle'],
      'scene': 'romantic',
      'emotion': 'romantic',
    },
    'curated_romantic_2': {
      'id': 'curated_romantic_2',
      'imageUrl':
          'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=600&q=80',
      'tags': ['romantic', 'couple', 'hug', 'love'],
      'scene': 'romantic',
      'emotion': 'romantic',
    },
    'curated_romantic_3': {
      'id': 'curated_romantic_3',
      'imageUrl':
          'https://images.unsplash.com/photo-1464695714655-48a7bbf6fdfd?w=600&q=80',
      'tags': ['romantic', 'couple', 'sunset', 'silhouette'],
      'scene': 'romantic',
      'time': 'evening',
      'emotion': 'romantic',
    },
    'curated_romantic_4': {
      'id': 'curated_romantic_4',
      'imageUrl':
          'https://images.unsplash.com/photo-1529333166437-7750a6dd5a70?w=600&q=80',
      'tags': ['romantic', 'flowers', 'rose', 'love'],
      'scene': 'romantic',
      'emotion': 'romantic',
    },
    'curated_romantic_5': {
      'id': 'curated_romantic_5',
      'imageUrl':
          'https://images.unsplash.com/photo-1510076857177-7470076d4098?w=600&q=80',
      'tags': ['romantic', 'candle', 'dinner', 'hearts'],
      'scene': 'romantic',
      'emotion': 'romantic',
    },
  };
}
