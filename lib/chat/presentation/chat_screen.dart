import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _chatService.setTypingStatus(widget.conversationId, false);
    super.dispose();
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
    await _chatService.sendMessage(
      conversationId: widget.conversationId,
      text: text,
    );

    _analyzeScene(text);
    _scrollToBottom();
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.person, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Partner', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    const Icon(Icons.lock, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    const Text('Encrypted',
                        style: TextStyle(fontSize: 11, color: Colors.green)),
                    if (moodState.currentMood != 'neutral') ...[
                      const SizedBox(width: 8),
                      Text(
                        moodState.currentMood,
                        style: TextStyle(
                          fontSize: 11,
                          color: _moodColor(moodState.currentMood),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
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
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      isSentByMe: message.senderId == _currentUserId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          // Scene suggestion bar
          if (sceneState.currentScene.scene != 'unknown')
            _buildSceneSuggestion(sceneState.currentScene),
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
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: 4,
                minLines: 1,
                onChanged: (value) {
                  _chatService.setTypingStatus(
                    widget.conversationId,
                    value.isNotEmpty,
                  );
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: () {},
            ),
            const SizedBox(width: 4),
            Consumer(
              builder: (context, ref, child) {
                return IconButton(
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _sendMessage,
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
      sceneImagesProvider({'scene': sceneName, 'tags': [sceneName]}),
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
                            Icon(Icons.image_search,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('No images yet for "$sceneName"',
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Add images in the admin panel',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
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
                            errorBuilder: (_, __, ___) => Container(
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
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Failed to load images')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isSentByMe;

  const _MessageBubble({
    required this.message,
    required this.isSentByMe,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = message.type == 'image';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isSentByMe ? 18 : 4),
                bottomRight: Radius.circular(isSentByMe ? 4 : 18),
              ),
            ),
            padding: EdgeInsets.all(isImage ? 4 : 14),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 200,
                      color: Colors.grey.shade300,
                      child: const Center(child: Icon(Icons.image, size: 48)),
                    ),
                  )
                : Text(
                    message.text ?? '',
                    style: TextStyle(
                      color: isSentByMe ? Colors.white : null,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              if (isSentByMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    message.readBy.length > 1
                        ? Icons.done_all
                        : Icons.done,
                    size: 14,
                    color: message.readBy.length > 1
                        ? Colors.blue
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ],
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
