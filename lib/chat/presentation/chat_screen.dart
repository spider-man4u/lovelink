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
import '../../gallery/models/gallery_image_model.dart';

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
  bool _isFirstLoad = true;

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

      // Pre-cache Unsplash scene images in background
      if (scene.scene != 'unknown') {
        ref.read(unsplashServiceProvider).searchSceneImages(scene);
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
                  if (_scrollController.hasClients) {
                    if (_isFirstLoad) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                      _isFirstLoad = false;
                    }
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
                                onReact: (emoji) =>
                                    _chatService.addReaction(message.id, emoji),
                                onRemoveReact: (emoji) =>
                                    _chatService.removeReaction(message.id, emoji),
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

class _SceneImageSheet extends ConsumerStatefulWidget {
  final String sceneName;

  const _SceneImageSheet({required this.sceneName});

  @override
  ConsumerState<_SceneImageSheet> createState() => _SceneImageSheetState();
}

class _SceneImageSheetState extends ConsumerState<_SceneImageSheet> {
  List<GalleryImageModel>? _unsplashResults;
  bool _isSearchingUnsplash = false;

  Future<void> _searchUnsplash() async {
    if (_isSearchingUnsplash) return;
    setState(() => _isSearchingUnsplash = true);
    try {
      final unsplash = ref.read(unsplashServiceProvider);
      final scene = SceneModel(
        scene: widget.sceneName,
        emotion: 'neutral',
        tags: [widget.sceneName],
      );
      final results = await unsplash.searchSceneImages(scene);
      setState(() => _unsplashResults = results);
    } catch (_) {
      setState(() => _unsplashResults = []);
    }
    setState(() => _isSearchingUnsplash = false);
  }

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(
      sceneImagesProvider({
        'scene': widget.sceneName,
        'tags': [widget.sceneName],
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
                '${widget.sceneName} Scene',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: imagesAsync.when(
                  data: (cached) {
                    final display = _unsplashResults ?? cached;
                    if (display.isEmpty) {
                      if (_isSearchingUnsplash) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Searching images from Unsplash...'),
                            ],
                          ),
                        );
                      }
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
                              'No images yet for "${widget.sceneName}"',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: _searchUnsplash,
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('Search Unsplash'),
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
                      itemCount: display.length,
                      itemBuilder: (context, index) {
                        final image = display[index];
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
                  loading: () {
                    if (_isSearchingUnsplash) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Searching images from Unsplash...'),
                          ],
                        ),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                  error: (_, _) {
                    if (_unsplashResults != null && _unsplashResults!.isNotEmpty) {
                      return GridView.builder(
                        controller: scrollController,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _unsplashResults!.length,
                        itemBuilder: (context, index) {
                          final image = _unsplashResults![index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              image.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      );
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 12),
                          const Text('Failed to load images'),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: _searchUnsplash,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Try Unsplash'),
                          ),
                        ],
                      ),
                    );
                  },
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

class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isSentByMe;
  final String currentUserId;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final ValueChanged<String> onReact;
  final ValueChanged<String> onRemoveReact;

  const _MessageBubble({
    required this.message,
    required this.isSentByMe,
    required this.currentUserId,
    required this.onReply,
    required this.onDelete,
    required this.onReact,
    required this.onRemoveReact,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showReactions = false;

  static const _reactionEmojis = ['💖', '😂', '😢', '😡', '👍'];

  void _toggleReactions() {
    HapticFeedback.mediumImpact();
    setState(() => _showReactions = !_showReactions);
  }

  void _handleReact(String emoji) {
    final reactedBy = widget.message.reactions[emoji] ?? [];
    if (reactedBy.contains(widget.currentUserId)) {
      widget.onRemoveReact(emoji);
    } else {
      widget.onReact(emoji);
    }
    setState(() => _showReactions = false);
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.message.type == 'image';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: widget.isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Dismissible(
            key: ValueKey('reply_${widget.message.id}'),
            direction: DismissDirection.horizontal,
            background: Container(
              alignment: widget.isSentByMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.reply,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            confirmDismiss: (direction) async {
              widget.onReply();
              return false;
            },
            child: GestureDetector(
              onLongPress: _toggleReactions,
              child: Column(
                crossAxisAlignment: widget.isSentByMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Reaction strip (shown on long-press)
                  if (_showReactions)
                    _ReactionStrip(
                      emojis: _reactionEmojis,
                      messageReactions: widget.message.reactions,
                      currentUserId: widget.currentUserId,
                      onReact: _handleReact,
                      onMore: () {
                        setState(() => _showReactions = false);
                        _showActions(context);
                      },
                    ),
                  const SizedBox(height: 2),
                  // Message bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSentByMe
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(widget.isSentByMe ? 16 : 5),
                        bottomRight: Radius.circular(widget.isSentByMe ? 5 : 16),
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
                        if (widget.message.replyTo != null)
                          _ReplySnippet(
                            replyTo: widget.message.replyTo!,
                            isSentByMe: widget.isSentByMe,
                          ),
                        if (isImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              widget.message.imageUrl ?? '',
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
                        if ((widget.message.text ?? '').isNotEmpty) ...[
                          if (isImage) const SizedBox(height: 8),
                          Text(
                            widget.message.text ?? '',
                            style: TextStyle(
                              color: widget.isSentByMe ? Colors.white : null,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Reaction chips
                  if (widget.message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _ReactionChips(
                        reactions: widget.message.reactions,
                        currentUserId: widget.currentUserId,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(widget.message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      if (widget.isSentByMe)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Padding(
                            key: ValueKey(widget.message.readBy.length > 1),
                            padding: const EdgeInsets.only(left: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.message.readBy.length > 1
                                      ? Icons.done_all
                                      : Icons.done,
                                  size: 14,
                                  color: widget.message.readBy.length > 1
                                      ? Colors.blue
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.message.readBy.length > 1 ? 'Read' : 'Sent',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: widget.message.readBy.length > 1
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
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final ctx = context;
    await showModalBottomSheet<void>(
      context: ctx,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(c);
                widget.onReply();
              },
            ),
            if ((widget.message.text ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.message.text ?? ''));
                  Navigator.pop(c);
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
                Navigator.pop(c);
                widget.onDelete();
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

class _ReactionStrip extends StatelessWidget {
  final List<String> emojis;
  final Map<String, List<String>> messageReactions;
  final String currentUserId;
  final ValueChanged<String> onReact;
  final VoidCallback onMore;

  const _ReactionStrip({
    required this.emojis,
    required this.messageReactions,
    required this.currentUserId,
    required this.onReact,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...emojis.map((emoji) {
              final reactedBy = messageReactions[emoji] ?? [];
              final isActive = reactedBy.contains(currentUserId);
              return GestureDetector(
                onTap: () => onReact(emoji),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }),
            const SizedBox(width: 4),
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onMore,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String currentUserId;

  const _ReactionChips({
    required this.reactions,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: reactions.entries
          .where((e) => e.value.isNotEmpty)
          .map((entry) {
        final isActive = entry.value.contains(currentUserId);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.6)
                : Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            '${entry.key} ${entry.value.length}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
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
