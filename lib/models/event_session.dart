import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event_session.g.dart';

@JsonSerializable()
class EventSession {
  final String id;
  final String eventDayId;
  final int sessionNumber;
  final String name;
  @JsonKey(fromJson: _timeOfDayFromString, toJson: _timeOfDayToString)
  final TimeOfDay startTime;
  @JsonKey(fromJson: _timeOfDayFromString, toJson: _timeOfDayToString)
  final TimeOfDay endTime;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventSession({
    required this.id,
    required this.eventDayId,
    required this.sessionNumber,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper methods
  Duration get duration {
    final start = Duration(hours: startTime.hour, minutes: startTime.minute);
    final end = Duration(hours: endTime.hour, minutes: endTime.minute);
    return end - start;
  }

  double get durationInHours {
    return duration.inMinutes / 60.0;
  }

  EventSession copyWith({
    String? id,
    String? eventDayId,
    int? sessionNumber,
    String? name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventSession(
      id: id ?? this.id,
      eventDayId: eventDayId ?? this.eventDayId,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory EventSession.fromJson(Map<String, dynamic> json) =>
      _$EventSessionFromJson(json);
  Map<String, dynamic> toJson() => _$EventSessionToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventDayId': eventDayId,
      'sessionNumber': sessionNumber,
      'name': name,
      'startTime': _timeOfDayToString(startTime),
      'endTime': _timeOfDayToString(endTime),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EventSession.fromMap(Map<String, dynamic> map) {
    return EventSession(
      id: map['id'] as String,
      eventDayId: map['eventDayId'] as String,
      sessionNumber: map['sessionNumber'] as int,
      name: map['name'] as String,
      startTime: _timeOfDayFromString(map['startTime'] as String),
      endTime: _timeOfDayFromString(map['endTime'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  // TimeOfDay serialization helpers
  static TimeOfDay _timeOfDayFromString(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _timeOfDayToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
