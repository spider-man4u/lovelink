class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final String type;
  final DateTime timestamp;
  final List<String> readBy;
  final SceneContext? sceneContext;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.type = 'text',
    required this.timestamp,
    this.readBy = const [],
    this.sceneContext,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String?,
      imageUrl: json['imageUrl'] as String?,
      type: json['type'] as String? ?? 'text',
      timestamp: (json['timestamp'] as dynamic).toDate() is DateTime
          ? (json['timestamp'] as dynamic).toDate()
          : DateTime.parse(json['timestamp'] as String),
      readBy: json['readBy'] != null
          ? List<String>.from(json['readBy'] as List)
          : [],
      sceneContext: json['sceneContext'] != null
          ? SceneContext.fromJson(json['sceneContext'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text ?? '',
        if (imageUrl != null) 'imageUrl': imageUrl,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'readBy': readBy,
        if (sceneContext != null) 'sceneContext': sceneContext!.toJson(),
      };
}

class SceneContext {
  final String? scene;
  final String? emotion;
  final String? weather;
  final String? time;
  final String? activity;
  final List<String> tags;

  const SceneContext({
    this.scene,
    this.emotion,
    this.weather,
    this.time,
    this.activity,
    this.tags = const [],
  });

  factory SceneContext.fromJson(Map<String, dynamic> json) {
    return SceneContext(
      scene: json['scene'] as String?,
      emotion: json['emotion'] as String?,
      weather: json['weather'] as String?,
      time: json['time'] as String?,
      activity: json['activity'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (scene != null) 'scene': scene,
        if (emotion != null) 'emotion': emotion,
        if (weather != null) 'weather': weather,
        if (time != null) 'time': time,
        if (activity != null) 'activity': activity,
        'tags': tags,
      };
}
