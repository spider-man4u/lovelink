class GalleryImageModel {
  final String id;
  final String imageUrl;
  final List<String> tags;
  final String scene;
  final String? emotion;
  final String? weather;
  final String? time;
  final String? activity;

  const GalleryImageModel({
    required this.id,
    required this.imageUrl,
    required this.tags,
    required this.scene,
    this.emotion,
    this.weather,
    this.time,
    this.activity,
  });

  factory GalleryImageModel.fromJson(Map<String, dynamic> json) {
    return GalleryImageModel(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      tags: List<String>.from(json['tags'] as List),
      scene: json['scene'] as String,
      emotion: json['emotion'] as String?,
      weather: json['weather'] as String?,
      time: json['time'] as String?,
      activity: json['activity'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageUrl': imageUrl,
        'tags': tags,
        'scene': scene,
        if (emotion != null) 'emotion': emotion,
        if (weather != null) 'weather': weather,
        if (time != null) 'time': time,
        if (activity != null) 'activity': activity,
      };
}
