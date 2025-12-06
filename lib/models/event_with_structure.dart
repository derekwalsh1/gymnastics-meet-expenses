import 'event.dart';
import 'event_day.dart';
import 'event_session.dart';
import 'event_floor.dart';
import 'judge_assignment.dart';

class EventWithStructure {
  final Event event;
  final List<EventDayWithSessions> days;

  EventWithStructure({
    required this.event,
    required this.days,
  });

  // Helper methods
  int get totalDays => days.length;
  
  int get totalSessions => days.fold(0, (sum, day) => sum + day.sessions.length);
  
  int get totalFloors => days.fold(
    0,
    (sum, day) => sum + day.sessions.fold(
      0,
      (sessionSum, session) => sessionSum + session.floors.length,
    ),
  );
  
  int get totalJudges => days.fold(
    0,
    (sum, day) => sum + day.sessions.fold(
      0,
      (sessionSum, session) => sessionSum + session.floors.fold(
        0,
        (floorSum, floor) => floorSum + floor.assignments.length,
      ),
    ),
  );
}

class EventDayWithSessions {
  final EventDay day;
  final List<EventSessionWithFloors> sessions;

  EventDayWithSessions({
    required this.day,
    required this.sessions,
  });
}

class EventSessionWithFloors {
  final EventSession session;
  final List<EventFloorWithAssignments> floors;

  EventSessionWithFloors({
    required this.session,
    required this.floors,
  });
}

class EventFloorWithAssignments {
  final EventFloor floor;
  final List<JudgeAssignment> assignments;

  EventFloorWithAssignments({
    required this.floor,
    required this.assignments,
  });
}
