class ConversationModel {
  final String id;
  final List<String> participants;
  final LastMessage? lastMessage;
  final List<String> pinnedBy;
  final List<String> hiddenFor;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.pinnedBy = const [],
    this.hiddenFor = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      participants: List<String>.from(json['participants'] as List),
      lastMessage: json['lastMessage'] != null
          ? LastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      pinnedBy: json['pinnedBy'] != null
          ? List<String>.from(json['pinnedBy'] as List)
          : [],
      hiddenFor: json['hiddenFor'] != null
          ? List<String>.from(json['hiddenFor'] as List)
          : [],
      createdAt: (json['createdAt'] as dynamic).toDate() is DateTime
          ? (json['createdAt'] as dynamic).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] as dynamic).toDate() is DateTime
          ? (json['updatedAt'] as dynamic).toDate()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'participants': participants,
    'lastMessage': lastMessage?.toJson(),
    'pinnedBy': pinnedBy,
    'hiddenFor': hiddenFor,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class LastMessage {
  final String? text;
  final String? senderId;
  final DateTime? timestamp;

  const LastMessage({this.text, this.senderId, this.timestamp});

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      text: json['text'] as String?,
      senderId: json['senderId'] as String?,
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] as dynamic).toDate() is DateTime
                ? (json['timestamp'] as dynamic).toDate()
                : DateTime.parse(json['timestamp'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (text != null) 'text': text,
    if (senderId != null) 'senderId': senderId,
    if (timestamp != null) 'timestamp': timestamp?.toIso8601String(),
  };
}
