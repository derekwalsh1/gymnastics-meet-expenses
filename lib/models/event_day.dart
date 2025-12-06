import 'package:json_annotation/json_annotation.dart';

part 'event_day.g.dart';

@JsonSerializable()
class EventDay {
  final String id;
  final String eventId;
  final int dayNumber;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventDay({
    required this.id,
    required this.eventId,
    required this.dayNumber,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  EventDay copyWith({
    String? id,
    String? eventId,
    int? dayNumber,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventDay(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory EventDay.fromJson(Map<String, dynamic> json) =>
      _$EventDayFromJson(json);
  Map<String, dynamic> toJson() => _$EventDayToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'dayNumber': dayNumber,
      'date': date.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EventDay.fromMap(Map<String, dynamic> map) {
    return EventDay(
      id: map['id'] as String,
      eventId: map['eventId'] as String,
      dayNumber: map['dayNumber'] as int,
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
