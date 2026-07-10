import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../chat/models/message_model.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> saveMemory({
    required String title,
    required String scene,
    required String emotion,
    String? imageUrl,
    String? quote,
    String? conversationId,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    await _firestore.collection('memories').add({
      'id': _uuid.v4(),
      'userId': userId,
      'title': title,
      'scene': scene,
      'emotion': emotion,
      'imageUrl': imageUrl ?? '',
      'quote': quote ?? '',
      'conversationId': conversationId ?? '',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMemories() {
    final userId = _userId;
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('memories')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteMemory(String memoryId) async {
    await _firestore.collection('memories').doc(memoryId).delete();
  }

  bool isImportantMoment(MessageModel message) {
    final text = message.text?.toLowerCase() ?? '';
    final importantKeywords = [
      'love you', 'happy birthday', 'anniversary', 'propos',
      'marry', 'miss you', 'forever', 'promise', 'special',
      'first date', 'reunion', 'airport', 'surprise', 'gift',
      'i love', 'beautiful', 'wonderful', 'perfect',
    ];
    return importantKeywords.any((k) => text.contains(k));
  }

  String generateTitle(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('happy birthday')) return '🎂 Birthday';
    if (lower.contains('love you') || lower.contains('i love')) return '❤️ Love';
    if (lower.contains('miss you')) return '💔 Miss You';
    if (lower.contains('anniversary')) return '🎉 Anniversary';
    if (lower.contains('propos')) return '💍 Proposal';
    if (lower.contains('kiss')) return '💋 Kiss';
    if (lower.contains('hug')) return '🤗 Hug';
    if (lower.contains('date')) return '🌹 Date';
    if (lower.contains('airport') || lower.contains('reunion'))
      return '✈️ Reunion';
    if (lower.contains('rain')) return '🌧️ Rain Walk';
    if (lower.contains('beach')) return '🏖️ Beach Day';
    if (lower.contains('cafe') || lower.contains('coffee'))
      return '☕ Coffee Date';
    if (lower.contains('sunset')) return '🌅 Sunset';
    if (lower.contains('dinner')) return '🍽️ Dinner';
    if (lower.contains('gift') || lower.contains('surprise'))
      return '🎁 Surprise';
    return '💫 Special Moment';
  }
}
