import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/conversation_model.dart';
import '../../chat/models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
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
    String conversationId,
  ) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getConversation(
    String conversationId,
  ) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots();
  }

  Future<void> sendMessage({
    required String conversationId,
    String? text,
    String? imageUrl,
    ReplyTo? replyTo,
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
      'deletedFor': [],
      if (replyTo != null) 'replyTo': replyTo.toJson(),
      if (sceneContext != null) 'sceneContext': sceneContext.toJson(),
    };

    await _firestore.collection('messages').doc(messageId).set(messageData);

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': {
        'text': text ?? (imageUrl != null ? '📷 Image' : ''),
        'senderId': senderId,
        'timestamp': Timestamp.fromDate(timestamp),
      },
      'lastReadAt.$senderId': Timestamp.fromDate(timestamp),
      'updatedAt': Timestamp.fromDate(timestamp),
    });
  }

  Future<void> sendImageMessage({
    required String conversationId,
    required String filePath,
    String? caption,
    ReplyTo? replyTo,
  }) async {
    final senderId = currentUserId;
    if (senderId == null) return;

    final messageId = _uuid.v4();
    final extension = filePath.split('.').last.toLowerCase();
    final storagePath = 'chat_images/$conversationId/$messageId.$extension';
    final ref = _storage.ref(storagePath);

    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/$extension'),
    );
    final imageUrl = await ref.getDownloadURL();

    await sendMessage(
      conversationId: conversationId,
      text: caption?.trim().isEmpty == true ? null : caption?.trim(),
      imageUrl: imageUrl,
      replyTo: replyTo,
    );
  }

  Future<String> createConversation(String partnerId) async {
    final conversationId = _uuid.v4();
    final userId = currentUserId!;
    final now = Timestamp.fromDate(DateTime.now());

    await _firestore.collection('conversations').doc(conversationId).set({
      'id': conversationId,
      'participants': [userId, partnerId],
      'lastMessage': {
        'text': 'Connected on LoveLink',
        'senderId': userId,
        'timestamp': now,
      },
      'lastReadAt': {
        userId: now,
        partnerId: Timestamp.fromMillisecondsSinceEpoch(0),
      },
      'pinnedBy': [],
      'hiddenFor': [],
      'createdAt': now,
      'updatedAt': now,
    });

    return conversationId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentConversations() {
    final uid = currentUserId;
    if (uid == null) return const Stream.empty();

    // Fallback for projects where the composite index is not deployed yet.
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  Stream<int> getUnreadCount(ConversationModel conversation) {
    final userId = currentUserId;
    if (userId == null) return Stream.value(0);

    final timestamp = conversation.lastMessage?.timestamp;
    if (timestamp == null || conversation.lastMessage?.senderId == userId) {
      return Stream.value(0);
    }

    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversation.id)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            if (data['senderId'] == userId) return false;
            final readBy = List<String>.from(data['readBy'] as List? ?? []);
            return !readBy.contains(userId);
          }).length;
        });
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

  Future<void> markAsRead(String conversationId, String messageId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final now = FieldValue.serverTimestamp();
    await Future.wait([
      _firestore.collection('messages').doc(messageId).update({
        'readBy': FieldValue.arrayUnion([userId]),
      }),
      _firestore.collection('conversations').doc(conversationId).update({
        'lastReadAt.$userId': now,
      }),
    ]);
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final unreadMessages = await _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      if (doc.data()['senderId'] == userId) continue;
      final readBy = List<String>.from(doc.data()['readBy'] as List? ?? []);
      if (!readBy.contains(userId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }
    }
    batch.update(_firestore.collection('conversations').doc(conversationId), {
      'lastReadAt.$userId': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> setConversationPinned(
    String conversationId,
    bool isPinned,
  ) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'pinnedBy': isPinned
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> hideConversation(String conversationId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _firestore.collection('conversations').doc(conversationId).update({
      'hiddenFor': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> deleteMessageForMe(String messageId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _firestore.collection('messages').doc(messageId).update({
      'deletedFor': FieldValue.arrayUnion([userId]),
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
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data());
  }
}
