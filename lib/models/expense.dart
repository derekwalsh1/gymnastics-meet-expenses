import 'package:json_annotation/json_annotation.dart';

part 'expense.g.dart';

@JsonSerializable()
class Expense {
  final String id;
  final String eventId;
  final String? judgeId;
  final String? sessionId;
  final ExpenseCategory category;
  
  // Category-specific fields
  final double? distance; // For mileage
  final double? mileageRate; // For mileage
  final MealType? mealType; // For meals/per diem
  final double? perDiemRate; // For meals/per diem
  final String? transportationType; // For transportation
  final DateTime? checkInDate; // For lodging
  final DateTime? checkOutDate; // For lodging
  final int? numberOfNights; // For lodging
  
  // Common fields
  final double amount;
  final bool isAutoCalculated;
  final DateTime date;
  final String description;
  final String? receiptPhotoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.eventId,
    this.judgeId,
    this.sessionId,
    required this.category,
    this.distance,
    this.mileageRate,
    this.mealType,
    this.perDiemRate,
    this.transportationType,
    this.checkInDate,
    this.checkOutDate,
    this.numberOfNights,
    required this.amount,
    this.isAutoCalculated = false,
    required this.date,
    required this.description,
    this.receiptPhotoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  Expense copyWith({
    String? id,
    String? eventId,
    String? judgeId,
    String? sessionId,
    ExpenseCategory? category,
    double? distance,
    double? mileageRate,
    MealType? mealType,
    double? perDiemRate,
    String? transportationType,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? numberOfNights,
    double? amount,
    bool? isAutoCalculated,
    DateTime? date,
    String? description,
    String? receiptPhotoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      judgeId: judgeId ?? this.judgeId,
      sessionId: sessionId ?? this.sessionId,
      category: category ?? this.category,
      distance: distance ?? this.distance,
      mileageRate: mileageRate ?? this.mileageRate,
      mealType: mealType ?? this.mealType,
      perDiemRate: perDiemRate ?? this.perDiemRate,
      transportationType: transportationType ?? this.transportationType,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      numberOfNights: numberOfNights ?? this.numberOfNights,
      amount: amount ?? this.amount,
      isAutoCalculated: isAutoCalculated ?? this.isAutoCalculated,
      date: date ?? this.date,
      description: description ?? this.description,
      receiptPhotoPath: receiptPhotoPath ?? this.receiptPhotoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) => _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'judgeId': judgeId,
      'sessionId': sessionId,
      'category': category.name,
      'distance': distance,
      'mileageRate': mileageRate,
      'mealType': mealType?.name,
      'perDiemRate': perDiemRate,
      'transportationType': transportationType,
      'checkInDate': checkInDate?.toIso8601String(),
      'checkOutDate': checkOutDate?.toIso8601String(),
      'numberOfNights': numberOfNights,
      'amount': amount,
      'isAutoCalculated': isAutoCalculated ? 1 : 0,
      'date': date.toIso8601String(),
      'description': description,
      'receiptPhotoPath': receiptPhotoPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      eventId: map['eventId'] as String,
      judgeId: map['judgeId'] as String?,
      sessionId: map['sessionId'] as String?,
      category: ExpenseCategory.values.firstWhere((e) => e.name == map['category']),
      distance: map['distance'] as double?,
      mileageRate: map['mileageRate'] as double?,
      mealType: map['mealType'] != null 
          ? MealType.values.firstWhere((e) => e.name == map['mealType'])
          : null,
      perDiemRate: map['perDiemRate'] as double?,
      transportationType: map['transportationType'] as String?,
      checkInDate: map['checkInDate'] != null 
          ? DateTime.parse(map['checkInDate'] as String)
          : null,
      checkOutDate: map['checkOutDate'] != null
          ? DateTime.parse(map['checkOutDate'] as String)
          : null,
      numberOfNights: map['numberOfNights'] as int?,
      amount: map['amount'] as double,
      isAutoCalculated: (map['isAutoCalculated'] as int) == 1,
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String,
      receiptPhotoPath: map['receiptPhotoPath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

enum ExpenseCategory {
  judgeFees,
  mileage,
  mealsPerDiem,
  tolls,
  airfare,
  transportation,
  parking,
  lodging,
  other,
}

enum MealType {
  breakfast,
  lunch,
  dinner,
  fullDay,
}
