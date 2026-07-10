import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final conversationsProvider = StreamProvider<List<ConversationModel>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getConversations().map((snapshot) {
    return snapshot.docs.map((doc) {
      return ConversationModel.fromJson(doc.data());
    }).toList();
  });
});

final messagesProvider = StreamProvider.family<List<MessageModel>, String>(
  (ref, conversationId) {
    final chatService = ref.watch(chatServiceProvider);
    return chatService.getMessages(conversationId).map((snapshot) {
      return snapshot.docs.map((doc) {
        return MessageModel.fromJson(doc.data());
      }).toList();
    });
  },
);

final typingStatusProvider =
    StreamProvider.family<bool, ({String conversationId, String userId})>(
  (ref, params) {
    final chatService = ref.watch(chatServiceProvider);
    return chatService.getTypingStatus(params.conversationId, params.userId);
  },
);

final partnerDataProvider =
    StreamProvider.family<Map<String, dynamic>?, String>(
  (ref, uid) {
    final chatService = ref.watch(chatServiceProvider);
    return chatService.getUserData(uid);
  },
);
