import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                child: _ConversationTile(
                  key: ValueKey(conversation.id),
                  conversation: conversation,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => _buildErrorState(context, err),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPartnerSheet(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.person_add_alt, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No conversations yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Find your partner to start your\nvisual love story together',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _showAddPartnerSheet(context),
              icon: const Icon(Icons.person_add_alt, size: 20),
              label: const Text('Find Partner'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load conversations',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPartnerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _FindPartnerSheet(),
    );
  }
}

class _FindPartnerSheet extends ConsumerStatefulWidget {
  const _FindPartnerSheet();

  @override
  ConsumerState<_FindPartnerSheet> createState() => _FindPartnerSheetState();
}

class _FindPartnerSheetState extends ConsumerState<_FindPartnerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final lowerQuery = query.trim().toLowerCase();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      final results = <String, Map<String, dynamic>>{};

      // Search by username
      final usernameSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: lowerQuery)
          .where('usernameLower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(10)
          .get();
      for (final doc in usernameSnap.docs) {
        if (doc.data()['uid'] != currentUid) {
          results[doc.id] = doc.data();
        }
      }

      // Also search by email as fallback
      final emailSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: lowerQuery)
          .where('email', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(10)
          .get();
      for (final doc in emailSnap.docs) {
        if (doc.data()['uid'] != currentUid) {
          results[doc.id] = doc.data();
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results.values.toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _startChat(Map<String, dynamic> partnerData) async {
    final partnerId = partnerData['uid'] as String;
    final chatService = ChatService();

    final existingConversationId = await chatService.findPartnerConversation(
      partnerId,
    );

    String conversationId;
    if (existingConversationId != null) {
      conversationId = existingConversationId;
    } else {
      conversationId = await chatService.createConversation(partnerId);
    }

    if (mounted) {
      Navigator.pop(context);
      context.push('/chats/$conversationId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Find Your Partner',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Search by username or email to find and connect',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search username or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _searchUsers,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Type a username to search'
                                  : 'No users found',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                child: Text(
                                  (user['displayName'] as String? ?? '?')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                              title: Text(
                                user['displayName'] as String? ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                user['username'] != null
                                    ? '@${user['username']}'
                                    : user['email'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              trailing: FilledButton.tonalIcon(
                                onPressed: () => _startChat(user),
                                icon: const Icon(Icons.chat, size: 18),
                                label: const Text('Chat'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;

  const _ConversationTile({super.key, required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserId = conversation.participants.firstWhere(
      (id) => id != FirebaseAuth.instance.currentUser?.uid,
      orElse: () => '',
    );
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isPinned =
        currentUserId != null && conversation.pinnedBy.contains(currentUserId);

    final partnerData = ref.watch(partnerDataProvider(otherUserId));
    final unreadCountAsync = ref.watch(unreadCountProvider(conversation));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/chats/${conversation.id}'),
        onLongPress: () => _showConversationActions(
          context,
          ref,
          conversation,
          partnerData.valueOrNull,
          isPinned,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                      data: (data) => Row(
                        children: [
                          Flexible(
                            child: Text(
                              data?['displayName'] as String? ?? 'Partner',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isPinned) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.push_pin,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              data?['username'] != null
                                  ? '@${data!['username']}'
                                  : data?['email']
                                            ?.toString()
                                            .split('@')
                                            .first ??
                                        '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(conversation.updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  unreadCountAsync.when(
                    data: (unreadCount) => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: unreadCount > 0
                          ? Container(
                              key: ValueKey(unreadCount),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : const SizedBox(key: ValueKey(0), height: 20),
                    ),
                    loading: () => const SizedBox(height: 20),
                    error: (_, _) => const SizedBox(height: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showConversationActions(
    BuildContext context,
    WidgetRef ref,
    ConversationModel conversation,
    Map<String, dynamic>? partnerData,
    bool isPinned,
  ) async {
    HapticFeedback.mediumImpact();
    final partnerName = partnerData?['displayName'] as String? ?? 'Partner';
    final chatService = ref.read(chatServiceProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(isPinned ? 'Unpin chat' : 'Pin chat'),
              onTap: () async {
                Navigator.pop(ctx);
                await chatService.setConversationPinned(
                  conversation.id,
                  !isPinned,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Mark as read'),
              onTap: () async {
                Navigator.pop(ctx);
                await chatService.markConversationAsRead(conversation.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share contact'),
              onTap: () {
                Navigator.pop(ctx);
                final username = partnerData?['username'] as String?;
                Clipboard.setData(
                  ClipboardData(
                    text: username != null ? '@$username' : partnerName,
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete from home',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Hides this chat for you only'),
              onTap: () async {
                Navigator.pop(ctx);
                await chatService.hideConversation(conversation.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${time.day}/${time.month}';
  }
}
