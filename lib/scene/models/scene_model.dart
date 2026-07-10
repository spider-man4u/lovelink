class SceneModel {
  final String scene;
  final String emotion;
  final String? weather;
  final String? time;
  final String? activity;
  final List<String> tags;

  const SceneModel({
    required this.scene,
    required this.emotion,
    this.weather,
    this.time,
    this.activity,
    this.tags = const [],
  });

  factory SceneModel.fromJson(Map<String, dynamic> json) {
    return SceneModel(
      scene: json['scene'] as String,
      emotion: json['emotion'] as String,
      weather: json['weather'] as String?,
      time: json['time'] as String?,
      activity: json['activity'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'scene': scene,
        'emotion': emotion,
        if (weather != null) 'weather': weather,
        if (time != null) 'time': time,
        if (activity != null) 'activity': activity,
        'tags': tags,
      };
}
