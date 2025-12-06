import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final EventLocation location;
  final String description;
  final double? totalBudget;
  final String? associationId;
  final EventStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.description,
    this.totalBudget,
    this.associationId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Event copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    EventLocation? location,
    String? description,
    double? totalBudget,
    String? associationId,
    EventStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      description: description ?? this.description,
      totalBudget: totalBudget ?? this.totalBudget,
      associationId: associationId ?? this.associationId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'locationVenueName': location.venueName,
      'locationAddress': location.address,
      'locationCity': location.city,
      'locationState': location.state,
      'locationZipCode': location.zipCode,
      'description': description,
      'totalBudget': totalBudget,
      'associationId': associationId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      name: map['name'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      location: EventLocation(
        venueName: map['locationVenueName'] as String,
        address: map['locationAddress'] as String,
        city: map['locationCity'] as String,
        state: map['locationState'] as String,
        zipCode: map['locationZipCode'] as String,
      ),
      description: map['description'] as String,
      totalBudget: map['totalBudget'] as double?,
      associationId: map['associationId'] as String?,
      status: EventStatus.values.firstWhere((e) => e.name == map['status']),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

@JsonSerializable()
class EventLocation {
  final String venueName;
  final String address;
  final String city;
  final String state;
  final String zipCode;

  EventLocation({
    required this.venueName,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
  });

  factory EventLocation.fromJson(Map<String, dynamic> json) =>
      _$EventLocationFromJson(json);
  Map<String, dynamic> toJson() => _$EventLocationToJson(this);
}

enum EventStatus {
  upcoming,
  ongoing,
  completed,
  archived,
}
