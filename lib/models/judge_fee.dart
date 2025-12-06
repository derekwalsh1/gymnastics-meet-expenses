import 'package:json_annotation/json_annotation.dart';

part 'judge_fee.g.dart';

enum FeeType {
  @JsonValue('session_rate')
  sessionRate,    // Auto-calculated: hourlyRate × session hours
  @JsonValue('meet_referee')
  meetReferee,    // Fixed bonus
  @JsonValue('head_judge')
  headJudge,      // Fixed bonus
  @JsonValue('custom')
  custom,         // User-defined
}

@JsonSerializable()
class JudgeFee {
  final String id;
  final String judgeAssignmentId;
  final FeeType feeType;
  final String description;
  final double amount;
  final double? hours;
  final bool isAutoCalculated;
  final bool isTaxable; // Always true for fees
  final DateTime createdAt;
  final DateTime updatedAt;

  JudgeFee({
    required this.id,
    required this.judgeAssignmentId,
    required this.feeType,
    required this.description,
    required this.amount,
    this.hours,
    required this.isAutoCalculated,
    this.isTaxable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  JudgeFee copyWith({
    String? id,
    String? judgeAssignmentId,
    FeeType? feeType,
    String? description,
    double? amount,
    double? hours,
    bool? isAutoCalculated,
    bool? isTaxable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JudgeFee(
      id: id ?? this.id,
      judgeAssignmentId: judgeAssignmentId ?? this.judgeAssignmentId,
      feeType: feeType ?? this.feeType,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      hours: hours ?? this.hours,
      isAutoCalculated: isAutoCalculated ?? this.isAutoCalculated,
      isTaxable: isTaxable ?? this.isTaxable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory JudgeFee.fromJson(Map<String, dynamic> json) =>
      _$JudgeFeeFromJson(json);
  Map<String, dynamic> toJson() => _$JudgeFeeToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'judgeAssignmentId': judgeAssignmentId,
      'feeType': feeType.name,
      'description': description,
      'amount': amount,
      'hours': hours,
      'isAutoCalculated': isAutoCalculated ? 1 : 0,
      'isTaxable': isTaxable ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory JudgeFee.fromMap(Map<String, dynamic> map) {
    return JudgeFee(
      id: map['id'] as String,
      judgeAssignmentId: map['judgeAssignmentId'] as String,
      feeType: FeeType.values.firstWhere((e) => e.name == map['feeType']),
      description: map['description'] as String,
      amount: map['amount'] as double,
      hours: map['hours'] as double?,
      isAutoCalculated: (map['isAutoCalculated'] as int) == 1,
      isTaxable: (map['isTaxable'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
