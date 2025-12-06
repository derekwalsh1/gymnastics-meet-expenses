import 'package:json_annotation/json_annotation.dart';

part 'judge.g.dart';

@JsonSerializable()
class Judge {
  final String id;
  final String firstName;
  final String lastName;
  final String? notes;
  final String? contactInfo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  Judge({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.notes,
    this.contactInfo,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  String get fullName => '$firstName $lastName';

  Judge copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? notes,
    String? contactInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return Judge(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      notes: notes ?? this.notes,
      contactInfo: contactInfo ?? this.contactInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  factory Judge.fromJson(Map<String, dynamic> json) => _$JudgeFromJson(json);
  Map<String, dynamic> toJson() => _$JudgeToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'notes': notes,
      'contactInfo': contactInfo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isArchived': isArchived ? 1 : 0,
    };
  }

  factory Judge.fromMap(Map<String, dynamic> map) {
    return Judge(
      id: map['id'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      notes: map['notes'] as String?,
      contactInfo: map['contactInfo'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isArchived: (map['isArchived'] as int) == 1,
    );
  }
}
