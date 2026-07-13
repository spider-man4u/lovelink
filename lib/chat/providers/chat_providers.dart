import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getRecentConversations().map((snapshot) {
    final conversations = snapshot.docs.map((doc) {
      return ConversationModel.fromJson(doc.data());
    }).toList();

    final currentUserId = chatService.currentUserId;
    final visible = conversations.where((conversation) {
      return currentUserId == null ||
          !conversation.hiddenFor.contains(currentUserId);
    }).toList();

    visible.sort((a, b) {
      final aPinned =
          currentUserId != null && a.pinnedBy.contains(currentUserId);
      final bPinned =
          currentUserId != null && b.pinnedBy.contains(currentUserId);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return visible;
  });
});

final messagesProvider = StreamProvider.family<List<MessageModel>, String>((
  ref,
  conversationId,
) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getMessages(conversationId).map((snapshot) {
    final currentUserId = chatService.currentUserId;
    return snapshot.docs
        .map((doc) {
          return MessageModel.fromJson(doc.data());
        })
        .where((message) {
          return currentUserId == null ||
              !message.deletedFor.contains(currentUserId);
        })
        .toList();
  });
});

final typingStatusProvider =
    StreamProvider.family<bool, ({String conversationId, String userId})>((
      ref,
      params,
    ) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.getTypingStatus(params.conversationId, params.userId);
    });

final partnerDataProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.getUserData(uid);
    });

final partnerIdProvider = StreamProvider.family<String, String>((
  ref,
  conversationId,
) {
  final chatService = ref.watch(chatServiceProvider);
  final currentUserId = chatService.currentUserId;
  return chatService.getConversation(conversationId).map((snapshot) {
    final data = snapshot.data();
    if (data == null) return '';
    final conversation = ConversationModel.fromJson(data);
    return conversation.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  });
});

final unreadCountProvider = StreamProvider.family<int, ConversationModel>((
  ref,
  conversation,
) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getUnreadCount(conversation);
});
