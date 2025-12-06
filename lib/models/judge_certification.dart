import 'package:json_annotation/json_annotation.dart';

part 'judge_certification.g.dart';

@JsonSerializable()
class JudgeCertification {
  final String id;
  final String judgeId;
  final String judgeLevelId;
  final DateTime? certificationDate;
  final DateTime? expirationDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  JudgeCertification({
    required this.id,
    required this.judgeId,
    required this.judgeLevelId,
    this.certificationDate,
    this.expirationDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JudgeCertification.fromJson(Map<String, dynamic> json) =>
      _$JudgeCertificationFromJson(json);

  Map<String, dynamic> toJson() => _$JudgeCertificationToJson(this);

  factory JudgeCertification.fromMap(Map<String, dynamic> map) {
    return JudgeCertification(
      id: map['id'] as String,
      judgeId: map['judgeId'] as String,
      judgeLevelId: map['judgeLevelId'] as String,
      certificationDate: map['certificationDate'] != null
          ? DateTime.parse(map['certificationDate'] as String)
          : null,
      expirationDate: map['expirationDate'] != null
          ? DateTime.parse(map['expirationDate'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'judgeId': judgeId,
      'judgeLevelId': judgeLevelId,
      'certificationDate': certificationDate?.toIso8601String(),
      'expirationDate': expirationDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  JudgeCertification copyWith({
    String? id,
    String? judgeId,
    String? judgeLevelId,
    DateTime? certificationDate,
    DateTime? expirationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JudgeCertification(
      id: id ?? this.id,
      judgeId: judgeId ?? this.judgeId,
      judgeLevelId: judgeLevelId ?? this.judgeLevelId,
      certificationDate: certificationDate ?? this.certificationDate,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
