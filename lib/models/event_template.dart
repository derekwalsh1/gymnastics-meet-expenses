import 'package:flutter/material.dart';

enum EventTemplateType {
  singleDaySingleSession,      // 1 day, 1 session, 1 floor
  singleDayMultiSession,       // 1 day, 2+ sessions, 1 floor each
  multiDaySingleSession,       // 2+ days, 1 session per day, 1 floor
  multiDayMultiSession,        // 2+ days, 2+ sessions per day, 1 floor each
  largeMeetMultiFloor,         // 2+ days, 2+ sessions, 2+ floors
  custom,                      // User-defined structure
}

class EventTemplate {
  final EventTemplateType type;
  final String name;
  final String description;
  final int days;
  final int sessionsPerDay;
  final int floorsPerSession;
  final List<SessionTimeTemplate> sessionTimes;

  EventTemplate({
    required this.type,
    required this.name,
    required this.description,
    required this.days,
    required this.sessionsPerDay,
    required this.floorsPerSession,
    required this.sessionTimes,
  });

  static List<EventTemplate> get predefinedTemplates => [
    EventTemplate(
      type: EventTemplateType.singleDaySingleSession,
      name: 'Quick Meet',
      description: 'Single day, one session, one floor',
      days: 1,
      sessionsPerDay: 1,
      floorsPerSession: 1,
      sessionTimes: [
        SessionTimeTemplate(
          name: 'Main Session',
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
        ),
      ],
    ),
    EventTemplate(
      type: EventTemplateType.singleDayMultiSession,
      name: 'Standard Meet',
      description: 'Single day with morning and afternoon sessions',
      days: 1,
      sessionsPerDay: 2,
      floorsPerSession: 1,
      sessionTimes: [
        SessionTimeTemplate(
          name: 'Morning Session',
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
        ),
        SessionTimeTemplate(
          name: 'Afternoon Session',
          startTime: const TimeOfDay(hour: 13, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
        ),
      ],
    ),
    EventTemplate(
      type: EventTemplateType.multiDaySingleSession,
      name: 'Multi-Day Meet',
      description: 'Multiple days, one session per day',
      days: 2,
      sessionsPerDay: 1,
      floorsPerSession: 1,
      sessionTimes: [
        SessionTimeTemplate(
          name: 'Daily Session',
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
        ),
      ],
    ),
    EventTemplate(
      type: EventTemplateType.multiDayMultiSession,
      name: 'Weekend Meet',
      description: 'Two days with morning and afternoon sessions',
      days: 2,
      sessionsPerDay: 2,
      floorsPerSession: 1,
      sessionTimes: [
        SessionTimeTemplate(
          name: 'Morning Session',
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
        ),
        SessionTimeTemplate(
          name: 'Afternoon Session',
          startTime: const TimeOfDay(hour: 13, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
        ),
      ],
    ),
    EventTemplate(
      type: EventTemplateType.largeMeetMultiFloor,
      name: 'Championship Meet',
      description: 'Multi-day meet with multiple floors per session',
      days: 3,
      sessionsPerDay: 3,
      floorsPerSession: 2,
      sessionTimes: [
        SessionTimeTemplate(
          name: 'Morning Session',
          startTime: const TimeOfDay(hour: 8, minute: 0),
          endTime: const TimeOfDay(hour: 11, minute: 30),
        ),
        SessionTimeTemplate(
          name: 'Midday Session',
          startTime: const TimeOfDay(hour: 12, minute: 30),
          endTime: const TimeOfDay(hour: 16, minute: 0),
        ),
        SessionTimeTemplate(
          name: 'Evening Session',
          startTime: const TimeOfDay(hour: 17, minute: 0),
          endTime: const TimeOfDay(hour: 20, minute: 30),
        ),
      ],
    ),
    EventTemplate(
      type: EventTemplateType.custom,
      name: 'Custom Event',
      description: 'Define your own structure',
      days: 1,
      sessionsPerDay: 1,
      floorsPerSession: 1,
      sessionTimes: [
        SessionTimeTemplate(
          name: 'Session 1',
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
        ),
      ],
    ),
  ];
}

class SessionTimeTemplate {
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  SessionTimeTemplate({
    required this.name,
    required this.startTime,
    required this.endTime,
  });
}
