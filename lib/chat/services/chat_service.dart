import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../chat/models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> getConversations() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(
      String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendMessage({
    required String conversationId,
    String? text,
    String? imageUrl,
    SceneContext? sceneContext,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) return;

    final messageId = _uuid.v4();
    final timestamp = DateTime.now();

    final messageData = {
      'id': messageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text ?? '',
      'imageUrl': imageUrl ?? '',
      'type': imageUrl != null ? 'image' : 'text',
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': [senderId],
      if (sceneContext != null) 'sceneContext': sceneContext.toJson(),
    };

    await _firestore.collection('messages').doc(messageId).set(messageData);

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': {
        'text': text ?? (imageUrl != null ? '📷 Image' : ''),
        'senderId': senderId,
        'timestamp': Timestamp.fromDate(timestamp),
      },
      'updatedAt': Timestamp.fromDate(timestamp),
    });
  }

  Future<String> createConversation(String partnerId) async {
    final conversationId = _uuid.v4();
    final userId = currentUserId!;

    await _firestore.collection('conversations').doc(conversationId).set({
      'id': conversationId,
      'participants': [userId, partnerId],
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    return conversationId;
  }

  Stream<bool> getTypingStatus(String conversationId, String userId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('typing')
        .doc(userId)
        .snapshots()
        .map((snap) => snap.data()?['isTyping'] == true);
  }

  Future<void> setTypingStatus(String conversationId, bool isTyping) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('typing')
        .doc(userId)
        .set({'isTyping': isTyping, 'userId': userId});
  }

  Future<void> markAsRead(
      String conversationId, String messageId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _firestore.collection('messages').doc(messageId).update({
      'readBy': FieldValue.arrayUnion([userId]),
    });
  }

  Future<String?> findPartnerConversation(String partnerId) async {
    final userId = currentUserId!;
    final snapshot = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .get();

    for (final doc in snapshot.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(partnerId)) {
        return doc.id;
      }
    }
    return null;
  }

  Stream<Map<String, dynamic>?> getUserData(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (snap) => snap.data(),
        );
  }
}
