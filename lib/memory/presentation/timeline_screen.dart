import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/memory_providers.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _filterEmotion = 'all';

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Timeline'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: memoriesAsync.when(
        data: (memories) {
          final filtered = _filterEmotion == 'all'
              ? memories
              : memories.where((memory) {
                  final emotion =
                      (memory['emotion'] as String?) ?? ''.toLowerCase();
                  return emotion == _filterEmotion;
                }).toList();

          if (filtered.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final memory = filtered[index];
              return _AnimatedMemoryCard(memory: memory, index: index);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildEmptyState(context),
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
                Icons.auto_stories_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your story awaits',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Special moments from your conversations\nwill appear here automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final emotions = [
      'all',
      'romantic',
      'happy',
      'emotional',
      'excited',
      'comforting',
      'funny',
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Filter by emotion',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                children: emotions.map((emotion) {
                  final isSelected = _filterEmotion == emotion;
                  return FilterChip(
                    label: Text(
                      emotion == 'all'
                          ? 'All'
                          : emotion[0].toUpperCase() + emotion.substring(1),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filterEmotion = emotion);
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMemoryCard extends StatefulWidget {
  final Map<String, dynamic> memory;
  final int index;

  const _AnimatedMemoryCard({required this.memory, required this.index});

  @override
  State<_AnimatedMemoryCard> createState() => _AnimatedMemoryCardState();
}

class _AnimatedMemoryCardState extends State<_AnimatedMemoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _MemoryCard(memory: widget.memory, index: widget.index),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final Map<String, dynamic> memory;
  final int index;

  const _MemoryCard({required this.memory, required this.index});

  @override
  Widget build(BuildContext context) {
    final title = memory['title'] as String? ?? 'Memory';
    final scene = memory['scene'] as String? ?? '';
    final emotion = memory['emotion'] as String? ?? '';
    final quote = memory['quote'] as String? ?? '';
    final timestamp = memory['createdAt'] as dynamic;
    final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _emotionColor(emotion).withValues(alpha: 0.7),
                    _emotionColor(emotion).withValues(alpha: 0.25),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  _sceneIcon(scene),
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _emotionColor(emotion).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          emotion.isNotEmpty
                              ? emotion[0].toUpperCase() + emotion.substring(1)
                              : '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _emotionColor(emotion),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (quote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"$quote"',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _emotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
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
      case 'funny':
        return Colors.amber;
      default:
        return Colors.pink;
    }
  }

  IconData _sceneIcon(String scene) {
    switch (scene.toLowerCase()) {
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
      case 'library':
        return Icons.local_library;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.favorite_border;
    }
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
