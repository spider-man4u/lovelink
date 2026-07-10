import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scene_model.dart';

// Mood state tracking
class MoodState {
  final String currentMood;
  final Map<String, int> moodHistory;
  final List<String> moodTimeline;

  const MoodState({
    this.currentMood = 'neutral',
    this.moodHistory = const {},
    this.moodTimeline = const [],
  });

  MoodState copyWith({
    String? currentMood,
    Map<String, int>? moodHistory,
    List<String>? moodTimeline,
  }) {
    return MoodState(
      currentMood: currentMood ?? this.currentMood,
      moodHistory: moodHistory ?? this.moodHistory,
      moodTimeline: moodTimeline ?? this.moodTimeline,
    );
  }
}

class MoodNotifier extends StateNotifier<MoodState> {
  MoodNotifier() : super(const MoodState());

  void updateMood(SceneModel scene) {
    final emotion = scene.emotion;
    if (emotion == 'neutral') return;

    final newHistory = Map<String, int>.from(state.moodHistory);
    newHistory[emotion] = (newHistory[emotion] ?? 0) + 1;

    final newTimeline = [...state.moodTimeline, emotion];

    // Find dominant mood
    String dominant = emotion;
    int maxCount = 0;
    for (final entry in newHistory.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        dominant = entry.key;
      }
    }

    state = MoodState(
      currentMood: dominant,
      moodHistory: newHistory,
      moodTimeline: newTimeline,
    );
  }
}

final moodProvider = StateNotifierProvider<MoodNotifier, MoodState>((ref) {
  return MoodNotifier();
});

// Scene memory - tracks location continuity
class SceneMemoryState {
  final String? currentLocation;
  final List<String> locationHistory;

  const SceneMemoryState({
    this.currentLocation,
    this.locationHistory = const [],
  });

  SceneMemoryState copyWith({
    String? currentLocation,
    List<String>? locationHistory,
  }) {
    return SceneMemoryState(
      currentLocation: currentLocation ?? this.currentLocation,
      locationHistory: locationHistory ?? this.locationHistory,
    );
  }
}

class SceneMemoryNotifier extends StateNotifier<SceneMemoryState> {
  SceneMemoryNotifier() : super(const SceneMemoryState());

  void updateLocation(SceneModel scene) {
    if (scene.scene == 'unknown') return;

    final newHistory = List<String>.from(state.locationHistory);
    if (state.currentLocation != null &&
        state.currentLocation != scene.scene) {
      newHistory.add(state.currentLocation!);
    }

    state = SceneMemoryState(
      currentLocation: scene.scene,
      locationHistory: newHistory,
    );
  }
}

final sceneMemoryProvider =
    StateNotifierProvider<SceneMemoryNotifier, SceneMemoryState>((ref) {
  return SceneMemoryNotifier();
});
