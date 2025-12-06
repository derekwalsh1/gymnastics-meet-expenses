import 'package:json_annotation/json_annotation.dart';

part 'judge_assignment.g.dart';

@JsonSerializable()
class JudgeAssignment {
  final String id;
  final String eventFloorId;
  
  // Judge snapshot data (copied when assigned)
  final String judgeId;
  final String judgeFirstName;
  final String judgeLastName;
  final String judgeAssociation;
  final String judgeLevel;
  final String? judgeContactInfo;
  
  // Assignment details
  final String? role;
  final double hourlyRate;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  JudgeAssignment({
    required this.id,
    required this.eventFloorId,
    required this.judgeId,
    required this.judgeFirstName,
    required this.judgeLastName,
    required this.judgeAssociation,
    required this.judgeLevel,
    this.judgeContactInfo,
    this.role,
    required this.hourlyRate,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper methods
  String get judgeFullName => '$judgeFirstName $judgeLastName';

  JudgeAssignment copyWith({
    String? id,
    String? eventFloorId,
    String? judgeId,
    String? judgeFirstName,
    String? judgeLastName,
    String? judgeAssociation,
    String? judgeLevel,
    String? judgeContactInfo,
    String? role,
    double? hourlyRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JudgeAssignment(
      id: id ?? this.id,
      eventFloorId: eventFloorId ?? this.eventFloorId,
      judgeId: judgeId ?? this.judgeId,
      judgeFirstName: judgeFirstName ?? this.judgeFirstName,
      judgeLastName: judgeLastName ?? this.judgeLastName,
      judgeAssociation: judgeAssociation ?? this.judgeAssociation,
      judgeLevel: judgeLevel ?? this.judgeLevel,
      judgeContactInfo: judgeContactInfo ?? this.judgeContactInfo,
      role: role ?? this.role,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory JudgeAssignment.fromJson(Map<String, dynamic> json) =>
      _$JudgeAssignmentFromJson(json);
  Map<String, dynamic> toJson() => _$JudgeAssignmentToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventFloorId': eventFloorId,
      'judgeId': judgeId,
      'judgeFirstName': judgeFirstName,
      'judgeLastName': judgeLastName,
      'judgeAssociation': judgeAssociation,
      'judgeLevel': judgeLevel,
      'judgeContactInfo': judgeContactInfo,
      'role': role,
      'hourlyRate': hourlyRate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory JudgeAssignment.fromMap(Map<String, dynamic> map) {
    return JudgeAssignment(
      id: map['id'] as String,
      eventFloorId: map['eventFloorId'] as String,
      judgeId: map['judgeId'] as String,
      judgeFirstName: map['judgeFirstName'] as String,
      judgeLastName: map['judgeLastName'] as String,
      judgeAssociation: map['judgeAssociation'] as String,
      judgeLevel: map['judgeLevel'] as String,
      judgeContactInfo: map['judgeContactInfo'] as String?,
      role: map['role'] as String?,
      hourlyRate: map['hourlyRate'] as double,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
