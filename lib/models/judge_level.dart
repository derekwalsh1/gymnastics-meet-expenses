import 'package:json_annotation/json_annotation.dart';

part 'judge_level.g.dart';

@JsonSerializable()
class JudgeLevel {
  final String id;
  final String association;
  final String level;
  final double defaultHourlyRate;
  final int sortOrder; // For display ordering
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  JudgeLevel({
    required this.id,
    required this.association,
    required this.level,
    required this.defaultHourlyRate,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  String get displayName => '$association $level';

  JudgeLevel copyWith({
    String? id,
    String? association,
    String? level,
    double? defaultHourlyRate,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return JudgeLevel(
      id: id ?? this.id,
      association: association ?? this.association,
      level: level ?? this.level,
      defaultHourlyRate: defaultHourlyRate ?? this.defaultHourlyRate,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  factory JudgeLevel.fromJson(Map<String, dynamic> json) => _$JudgeLevelFromJson(json);
  Map<String, dynamic> toJson() => _$JudgeLevelToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'association': association,
      'level': level,
      'defaultHourlyRate': defaultHourlyRate,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isArchived': isArchived ? 1 : 0,
    };
  }

  factory JudgeLevel.fromMap(Map<String, dynamic> map) {
    return JudgeLevel(
      id: map['id'] as String,
      association: map['association'] as String,
      level: map['level'] as String,
      defaultHourlyRate: map['defaultHourlyRate'] as double,
      sortOrder: map['sortOrder'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isArchived: (map['isArchived'] as int) == 1,
    );
  }
}
