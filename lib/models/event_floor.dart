import 'package:json_annotation/json_annotation.dart';

part 'event_floor.g.dart';

@JsonSerializable()
class EventFloor {
  final String id;
  final String eventSessionId;
  final int floorNumber;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventFloor({
    required this.id,
    required this.eventSessionId,
    required this.floorNumber,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  EventFloor copyWith({
    String? id,
    String? eventSessionId,
    int? floorNumber,
    String? name,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventFloor(
      id: id ?? this.id,
      eventSessionId: eventSessionId ?? this.eventSessionId,
      floorNumber: floorNumber ?? this.floorNumber,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory EventFloor.fromJson(Map<String, dynamic> json) =>
      _$EventFloorFromJson(json);
  Map<String, dynamic> toJson() => _$EventFloorToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventSessionId': eventSessionId,
      'floorNumber': floorNumber,
      'name': name,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EventFloor.fromMap(Map<String, dynamic> map) {
    return EventFloor(
      id: map['id'] as String,
      eventSessionId: map['eventSessionId'] as String,
      floorNumber: map['floorNumber'] as int,
      name: map['name'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
