import 'package:uuid/uuid.dart';
import '../models/event_floor.dart';
import '../services/database_service.dart';
import 'judge_assignment_repository.dart';

class EventFloorRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  final _uuid = const Uuid();

  // Create
  Future<EventFloor> createEventFloor({
    required String eventSessionId,
    required int floorNumber,
    required String name,
    String? notes,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    final eventFloor = EventFloor(
      id: _uuid.v4(),
      eventSessionId: eventSessionId,
      floorNumber: floorNumber,
      name: name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('event_floors', eventFloor.toMap());
    return eventFloor;
  }

  // Read
  Future<EventFloor?> getEventFloorById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_floors',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return EventFloor.fromMap(maps.first);
  }

  Future<List<EventFloor>> getEventFloorsBySessionId(String eventSessionId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_floors',
      where: 'eventSessionId = ?',
      whereArgs: [eventSessionId],
      orderBy: 'floorNumber ASC',
    );

    return maps.map((map) => EventFloor.fromMap(map)).toList();
  }

  Future<List<EventFloor>> getAllEventFloors() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_floors',
      orderBy: 'floorNumber ASC',
    );

    return maps.map((map) => EventFloor.fromMap(map)).toList();
  }

  // Update
  Future<void> updateEventFloor(EventFloor eventFloor) async {
    final db = await _dbService.database;
    final updatedEventFloor = eventFloor.copyWith(updatedAt: DateTime.now());

    await db.update(
      'event_floors',
      updatedEventFloor.toMap(),
      where: 'id = ?',
      whereArgs: [eventFloor.id],
    );
  }

  // Delete
  Future<void> deleteEventFloor(String id) async {
    final db = await _dbService.database;
    await db.delete(
      'event_floors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper methods
  Future<int> getEventFloorCount(String eventSessionId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM event_floors WHERE eventSessionId = ?',
      [eventSessionId],
    );
    return result.first['count'] as int;
  }

  // Get floors for a specific event (across all days and sessions)
  Future<List<EventFloor>> getEventFloorsByEventId(String eventId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT ef.* 
      FROM event_floors ef
      INNER JOIN event_sessions es ON ef.eventSessionId = es.id
      INNER JOIN event_days ed ON es.eventDayId = ed.id
      WHERE ed.eventId = ?
      ORDER BY ed.dayNumber ASC, es.sessionNumber ASC, ef.floorNumber ASC
    ''', [eventId]);

    return maps.map((map) => EventFloor.fromMap(map)).toList();
  }

  // Clone a floor with its judge assignment
  Future<EventFloor> cloneEventFloor({
    required String eventFloorId,
    String? newEventSessionId,
    bool includeJudgeAssignments = true,
  }) async {
    final db = await _dbService.database;
    
    // Get the original floor
    final originalFloor = await getEventFloorById(eventFloorId);
    if (originalFloor == null) {
      throw Exception('Event floor not found');
    }

    // Use the same session if not specified
    final targetSessionId = newEventSessionId ?? originalFloor.eventSessionId;

    // Get the next floor number for this session
    final existingFloors = await getEventFloorsBySessionId(targetSessionId);
    final nextFloorNumber = existingFloors.isEmpty 
        ? 1 
        : existingFloors.map((f) => f.floorNumber).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now();
    
    // Create the new floor
    final newFloor = EventFloor(
      id: _uuid.v4(),
      eventSessionId: targetSessionId,
      floorNumber: nextFloorNumber,
      name: originalFloor.name,
      notes: originalFloor.notes,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('event_floors', newFloor.toMap());

    // Clone judge assignment if requested
    if (includeJudgeAssignments) {
      final assignmentRepo = JudgeAssignmentRepository();
      final assignments = await assignmentRepo.getAssignmentsByFloorId(eventFloorId);
      
      for (final assignment in assignments) {
        await assignmentRepo.cloneAssignment(
          assignmentId: assignment.id,
          newEventFloorId: newFloor.id,
        );
      }
    }

    return newFloor;
  }
}
