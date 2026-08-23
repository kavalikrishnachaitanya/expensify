/// User model representing a user in the app
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? gender;
  final String? photoUrl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.gender,
    this.photoUrl,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      gender: map['gender'],
      photoUrl: map['photoUrl'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'gender': gender,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
    };
  }

  /// Copy with method
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? gender,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
