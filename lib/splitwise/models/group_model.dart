/// Group model representing an expense group
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final List<String> memberIds;
  final Map<String, String> memberNames; // userId -> displayName
  final String createdBy;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.memberIds,
    required this.memberNames,
    required this.createdBy,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      memberNames: Map<String, String>.from(map['memberNames'] ?? {}),
      createdBy: map['createdBy'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  /// Copy with method
  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? memberIds,
    Map<String, String>? memberNames,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      memberNames: memberNames ?? this.memberNames,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
