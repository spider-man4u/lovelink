import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/chat_service.dart';
import '../providers/chat_providers.dart';
import '../models/conversation_model.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LoveLink'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.timeline_outlined),
            onPressed: () => context.push('/timeline'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: conversations.length,
            itemBuilder: (context, index) =>
                _ConversationTile(conversation: conversations[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildEmptyState(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startNewChat(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat with your partner',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _startNewChat(BuildContext context) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Chat'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: "Partner's email",
            hintText: 'Enter your partner email address',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _findOrCreateConversation(context, emailController.text.trim());
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _findOrCreateConversation(
      BuildContext context, String partnerEmail) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: partnerEmail)
          .get();

      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
        return;
      }

      final partnerId = snapshot.docs.first.id;
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      if (partnerId == currentUserId) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot chat with yourself')),
          );
        }
        return;
      }

      final chatService = ChatService();
      final existingConversationId =
          await chatService.findPartnerConversation(partnerId);

      String conversationId;
      if (existingConversationId != null) {
        conversationId = existingConversationId;
      } else {
        conversationId = await chatService.createConversation(partnerId);
      }

      if (context.mounted) {
        context.push('/chats/$conversationId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserId = conversation.participants.firstWhere(
      (id) => id != FirebaseAuth.instance.currentUser?.uid,
      orElse: () => '',
    );

    final partnerData = ref.watch(partnerDataProvider(otherUserId));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/chats/${conversation.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: partnerData.when(
                  data: (data) => Text(
                    (data?['displayName'] as String? ?? 'P')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  loading: () => const Icon(Icons.person, size: 24),
                  error: (_, _) => const Icon(Icons.person, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    partnerData.when(
                      data: (data) => Text(
                        data?['displayName'] as String? ?? 'Partner',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      loading: () => const Text('Loading...'),
                      error: (_, _) => const Text('Partner'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage?.text ?? 'Start chatting!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTime(conversation.updatedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${time.day}/${time.month}';
  }
}
