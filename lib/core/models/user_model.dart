class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? partnerId;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.partnerId,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoURL: json['photoURL'] as String?,
      partnerId: json['partnerId'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null
          ? (json['lastSeen'] as dynamic).toDate() is DateTime
              ? (json['lastSeen'] as dynamic).toDate()
              : DateTime.parse(json['lastSeen'] as String)
          : null,
      createdAt: (json['createdAt'] as dynamic).toDate() is DateTime
          ? (json['createdAt'] as dynamic).toDate()
          : DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (partnerId != null) 'partnerId': partnerId,
        'isOnline': isOnline,
        if (lastSeen != null) 'lastSeen': lastSeen?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}
