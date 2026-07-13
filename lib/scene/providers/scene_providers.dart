import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_config.dart';
import '../models/scene_model.dart';
import '../services/scene_detection_service.dart';
import '../services/unsplash_service.dart';

final sceneServiceProvider = Provider<SceneDetectionService>((ref) {
  return SceneDetectionService(ApiConfig.geminiApiKey);
});

final unsplashServiceProvider = Provider<UnsplashService>((ref) {
  return UnsplashService(ApiConfig.unsplashAccessKey);
});

class SceneState {
  final SceneModel currentScene;
  final List<SceneModel> sceneHistory;
  final SceneModel? previousScene;

  const SceneState({
    this.currentScene = const SceneModel(scene: 'unknown', emotion: 'neutral'),
    this.sceneHistory = const [],
    this.previousScene,
  });

  SceneState copyWith({
    SceneModel? currentScene,
    List<SceneModel>? sceneHistory,
    SceneModel? previousScene,
  }) {
    return SceneState(
      currentScene: currentScene ?? this.currentScene,
      sceneHistory: sceneHistory ?? this.sceneHistory,
      previousScene: previousScene ?? this.previousScene,
    );
  }

  bool get hasSceneChanged =>
      previousScene != null && previousScene!.scene != currentScene.scene;
}

class SceneNotifier extends StateNotifier<SceneState> {
  final SceneDetectionService _service;

  SceneNotifier(this._service) : super(const SceneState());

  Future<SceneModel> analyzeMessage(String text) async {
    final scene = await _service.analyzeMessage(text);

    state = SceneState(
      currentScene: scene,
      sceneHistory: [...state.sceneHistory, scene],
      previousScene: state.currentScene.scene != 'unknown'
          ? state.currentScene
          : null,
    );

    return scene;
  }

  bool get shouldSuggestImage {
    if (!state.hasSceneChanged) return false;

    final importantScenes = [
      'romantic', 'bedroom', 'airport', 'rain',
      'sunset', 'sunrise', 'beach', 'proposal',
    ];

    return state.currentScene.scene != 'unknown' &&
        (importantScenes.contains(state.currentScene.scene) ||
            state.currentScene.emotion != 'neutral');
  }
}

final sceneProvider = StateNotifierProvider<SceneNotifier, SceneState>((ref) {
  final service = ref.watch(sceneServiceProvider);
  return SceneNotifier(service);
});
