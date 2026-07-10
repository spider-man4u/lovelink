import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/memory_providers.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(memoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: memoriesAsync.when(
        data: (memories) {
          if (memories.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index];
              return _MemoryCard(memory: memory, index: index);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildEmptyState(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Your story awaits',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Special moments from your conversations\nwill appear here automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 32),
          Icon(
            Icons.favorite_rounded,
            size: 28,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ],
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
            // Image area
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _emotionColor(emotion).withValues(alpha: 0.6),
                    _emotionColor(emotion).withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  _sceneIcon(scene),
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.8),
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
                          color: _emotionColor(emotion).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          emotion.toUpperCase(),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(date),
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
        return Colors.grey;
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
