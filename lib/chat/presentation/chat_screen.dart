import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../models/message_model.dart';
import '../providers/chat_providers.dart';
import '../services/chat_service.dart';
import '../../scene/models/scene_model.dart';
import '../../scene/providers/scene_providers.dart';
import '../../scene/providers/mood_providers.dart';
import '../../memory/services/memory_service.dart';
import '../../gallery/providers/gallery_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();
  final _memoryService = MemoryService();
  final _imagePicker = ImagePicker();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isAnalyzing = false;
  bool _hasText = false;
  bool _showScrollToBottom = false;
  bool _isSearching = false;
  String _searchQuery = '';
  MessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _textController.dispose();
    _scrollController.dispose();
    _chatService.setTypingStatus(widget.conversationId, false);
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final shouldShow = distanceFromBottom > 240;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() => _hasText = false);
    await _chatService.setTypingStatus(widget.conversationId, false);
    await _chatService.sendMessage(
      conversationId: widget.conversationId,
      text: text,
      replyTo: _replyingTo == null ? null : _replyFromMessage(_replyingTo!),
    );
    setState(() => _replyingTo = null);

    _analyzeScene(text);
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return;

    final caption = _textController.text.trim();
    _textController.clear();
    final replyTo = _replyingTo == null
        ? null
        : _replyFromMessage(_replyingTo!);
    setState(() {
      _hasText = false;
      _replyingTo = null;
    });

    await _chatService.sendImageMessage(
      conversationId: widget.conversationId,
      filePath: image.path,
      caption: caption,
      replyTo: replyTo,
    );
    _scrollToBottom();
  }

  ReplyTo _replyFromMessage(MessageModel message) {
    final text = message.type == 'image'
        ? (message.text?.isNotEmpty == true ? message.text! : 'Photo')
        : message.text ?? '';
    return ReplyTo(
      messageId: message.id,
      senderId: message.senderId,
      text: text,
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) _searchQuery = '';
    });
  }

  Future<void> _analyzeScene(String text) async {
    setState(() => _isAnalyzing = true);

    try {
      final scene = await ref.read(sceneProvider.notifier).analyzeMessage(text);
      ref.read(moodProvider.notifier).updateMood(scene);
      ref.read(sceneMemoryProvider.notifier).updateLocation(scene);

      // Save memory for important moments
      if (_memoryService.isImportantMoment(
        MessageModel(
          id: '',
          conversationId: widget.conversationId,
          senderId: _currentUserId,
          text: text,
          timestamp: DateTime.now(),
        ),
      )) {
        await _memoryService.saveMemory(
          title: _memoryService.generateTitle(text),
          scene: scene.scene,
          emotion: scene.emotion,
          quote: text,
          conversationId: widget.conversationId,
        );
      }
    } catch (_) {}

    setState(() => _isAnalyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final sceneState = ref.watch(sceneProvider);
    final moodState = ref.watch(moodProvider);
    final partnerIdAsync = ref.watch(partnerIdProvider(widget.conversationId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: partnerIdAsync.when(
          data: (partnerId) => _ChatHeader(
            partnerId: partnerId,
            conversationId: widget.conversationId,
            currentMood: moodState.currentMood,
            moodColor: _moodColor(moodState.currentMood),
          ),
          loading: () => const _ChatHeaderSkeleton(),
          error: (_, _) => const _ChatHeaderSkeleton(),
        ),
        actions: [
          IconButton(
            tooltip: 'Search messages',
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          if (_isAnalyzing)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final visibleMessages = _searchQuery.trim().isEmpty
                    ? messages
                    : messages.where((message) {
                        return (message.text ?? '').toLowerCase().contains(
                          _searchQuery.trim().toLowerCase(),
                        );
                      }).toList();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && !_isSearching) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                  final hasUnreadIncoming = messages.any((message) {
                    return message.senderId != _currentUserId &&
                        !message.readBy.contains(_currentUserId);
                  });
                  if (hasUnreadIncoming) {
                    _chatService.markConversationAsRead(widget.conversationId);
                  }
                });
                return Stack(
                  children: [
                    if (visibleMessages.isEmpty)
                      Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No messages yet'
                              : 'No matching messages',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: visibleMessages.length,
                        itemBuilder: (context, index) {
                          final message = visibleMessages[index];
                          final showDateDivider =
                              index == 0 ||
                              !_isSameDay(
                                visibleMessages[index - 1].timestamp,
                                message.timestamp,
                              );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateDivider)
                                _DateDivider(date: message.timestamp),
                              _MessageBubble(
                                message: message,
                                isSentByMe: message.senderId == _currentUserId,
                                currentUserId: _currentUserId,
                                onReply: () {
                                  setState(() => _replyingTo = message);
                                  HapticFeedback.selectionClick();
                                },
                                onDelete: () =>
                                    _chatService.deleteMessageForMe(message.id),
                              ),
                            ],
                          );
                        },
                      ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: AnimatedScale(
                        scale: _showScrollToBottom ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: FloatingActionButton.small(
                          heroTag: 'scroll_to_bottom',
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          // Scene suggestion bar
          if (sceneState.currentScene.scene != 'unknown')
            _buildSceneSuggestion(sceneState.currentScene),
          if (_replyingTo != null) _buildReplyPreview(_replyingTo!),
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildSceneSuggestion(SceneModel scene) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSceneImages(scene),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _sceneIcon(scene.scene),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.scene[0].toUpperCase() + scene.scene.substring(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${_emotionLabel(scene.emotion)} ${scene.time ?? ''} ${scene.weather ?? ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Suggest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSceneImages(SceneModel scene) {
    final sceneName = scene.scene;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SceneImageSheet(sceneName: sceneName),
    );
  }

  Widget _buildReplyPreview(MessageModel message) {
    final previewText = message.type == 'image'
        ? (message.text?.isNotEmpty == true ? message.text! : 'Photo')
        : message.text ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderId == _currentUserId
                      ? 'Replying to yourself'
                      : 'Replying',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                onChanged: (value) {
                  final hasText = value.trim().isNotEmpty;
                  if (_hasText != hasText) {
                    setState(() => _hasText = hasText);
                  }
                  _chatService.setTypingStatus(widget.conversationId, hasText);
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: _sendImage,
            ),
            const SizedBox(width: 4),
            Consumer(
              builder: (context, ref, child) {
                return AnimatedScale(
                  scale: _hasText ? 1 : 0.92,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _hasText ? _sendMessage : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case 'romantic':
        return Colors.pink;
      case 'happy':
        return Colors.orange;
      case 'emotional':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'comforting':
        return Colors.green;
      case 'excited':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _sceneIcon(String scene) {
    switch (scene) {
      case 'cafe':
        return Icons.local_cafe;
      case 'bedroom':
        return Icons.bed;
      case 'beach':
        return Icons.beach_access;
      case 'park':
        return Icons.park;
      case 'rain':
        return Icons.water_drop;
      case 'airport':
        return Icons.flight_takeoff;
      case 'sunset':
        return Icons.sunny;
      case 'romantic':
        return Icons.favorite;
      case 'kitchen':
        return Icons.countertops;
      default:
        return Icons.auto_awesome;
    }
  }

  String _emotionLabel(String emotion) {
    switch (emotion) {
      case 'romantic':
        return '❤️ Romantic';
      case 'happy':
        return '😊 Happy';
      case 'emotional':
        return '😢 Emotional';
      case 'angry':
        return '😠 Angry';
      case 'comforting':
        return '🤗 Comforting';
      case 'excited':
        return '🎉 Excited';
      case 'funny':
        return '😂 Funny';
      default:
        return '';
    }
  }
}

class _SceneImageSheet extends ConsumerWidget {
  final String sceneName;

  const _SceneImageSheet({required this.sceneName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(
      sceneImagesProvider({
        'scene': sceneName,
        'tags': [sceneName],
      }),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
              const SizedBox(height: 16),
              Text(
                '$sceneName Scene',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: imagesAsync.when(
                  data: (images) {
                    if (images.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_search,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No images yet for "$sceneName"',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add images in the admin panel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            image.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image),
                            ),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      const Center(child: Text('Failed to load images')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  final String partnerId;
  final String conversationId;
  final String currentMood;
  final Color moodColor;

  const _ChatHeader({
    required this.partnerId,
    required this.conversationId,
    required this.currentMood,
    required this.moodColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerData = ref.watch(partnerDataProvider(partnerId));
    final typingStatus = ref.watch(
      typingStatusProvider((conversationId: conversationId, userId: partnerId)),
    );

    return partnerData.when(
      data: (data) {
        final name = data?['displayName'] as String? ?? 'Partner';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
        final isTyping = typingStatus.value == true;
        final isOnline = data?['isOnline'] == true;
        final subtitle = isTyping ? 'Typing...' : _presenceLabel(data);

        return Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        isOnline ? Icons.circle : Icons.schedule,
                        size: 12,
                        color: isOnline
                            ? Colors.green
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isTyping
                                ? Colors.blue
                                : isOnline
                                ? Colors.green
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      if (isTyping) const _TypingDots(),
                      if (currentMood != 'neutral') ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            currentMood,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: moodColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const _ChatHeaderSkeleton(),
      error: (_, _) => const _ChatHeaderSkeleton(),
    );
  }

  String _presenceLabel(Map<String, dynamic>? data) {
    if (data?['isOnline'] == true) return 'Online';

    final rawLastSeen = data?['lastSeen'];
    final lastSeen = rawLastSeen is Timestamp
        ? rawLastSeen.toDate()
        : rawLastSeen is String
        ? DateTime.tryParse(rawLastSeen)
        : null;

    if (lastSeen == null) return 'End-to-end Encrypted';

    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      final hour = lastSeen.hour.toString().padLeft(2, '0');
      final minute = lastSeen.minute.toString().padLeft(2, '0');
      return 'Last seen today at $hour:$minute';
    }
    if (diff.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }
}

class _ChatHeaderSkeleton extends StatelessWidget {
  const _ChatHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
        SizedBox(width: 10),
        Text(
          'Partner',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(DateTime(date.year, date.month, date.day));
    String label;
    if (diff.inDays == 0) {
      label = 'Today';
    } else if (diff.inDays == 1) {
      label = 'Yesterday';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      label = '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + (index * 0.2)) % 1;
            final opacity = phase < 0.5 ? 0.35 + phase : 1.35 - phase;
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: opacity.clamp(0.35, 1)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isSentByMe;
  final String currentUserId;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _MessageBubble({
    required this.message,
    required this.isSentByMe,
    required this.currentUserId,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = message.type == 'image';

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isSentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isSentByMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isSentByMe ? 16 : 5),
                  bottomRight: Radius.circular(isSentByMe ? 5 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isImage ? 4 : 16,
                vertical: isImage ? 4 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo != null)
                    _ReplySnippet(
                      replyTo: message.replyTo!,
                      isSentByMe: isSentByMe,
                    ),
                  if (isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        message.imageUrl ?? '',
                        width: 240,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 240,
                          height: 180,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 42),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 240,
                            height: 180,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
                    ),
                  if ((message.text ?? '').isNotEmpty) ...[
                    if (isImage) const SizedBox(height: 8),
                    Text(
                      message.text ?? '',
                      style: TextStyle(
                        color: isSentByMe ? Colors.white : null,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (isSentByMe)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Padding(
                      key: ValueKey(message.readBy.length > 1),
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.readBy.length > 1
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: message.readBy.length > 1
                                ? Colors.blue
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            message.readBy.length > 1 ? 'Read' : 'Sent',
                            style: TextStyle(
                              fontSize: 10,
                              color: message.readBy.length > 1
                                  ? Colors.blue
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                onReply();
              },
            ),
            if ((message.text ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text ?? ''));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete for me',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
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
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _ReplySnippet extends StatelessWidget {
  final ReplyTo replyTo;
  final bool isSentByMe;

  const _ReplySnippet({required this.replyTo, required this.isSentByMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (isSentByMe ? Colors.white : Colors.black).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isSentByMe
                ? Colors.white.withValues(alpha: 0.8)
                : Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        replyTo.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.25,
          color: isSentByMe
              ? Colors.white.withValues(alpha: 0.9)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
