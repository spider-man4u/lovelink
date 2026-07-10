import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/memory_service.dart';

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});

final memoriesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(memoryServiceProvider);
  return service.getMemories().map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).toList();
  });
});
