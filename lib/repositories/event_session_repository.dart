import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/event_session.dart';
import '../services/database_service.dart';
import 'event_floor_repository.dart';

class EventSessionRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  final _uuid = const Uuid();

  // Create
  Future<EventSession> createEventSession({
    required String eventDayId,
    required int sessionNumber,
    required String name,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? notes,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    final eventSession = EventSession(
      id: _uuid.v4(),
      eventDayId: eventDayId,
      sessionNumber: sessionNumber,
      name: name,
      startTime: startTime,
      endTime: endTime,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('event_sessions', eventSession.toMap());
    return eventSession;
  }

  // Read
  Future<EventSession?> getEventSessionById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return EventSession.fromMap(maps.first);
  }

  Future<List<EventSession>> getEventSessionsByDayId(String eventDayId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_sessions',
      where: 'eventDayId = ?',
      whereArgs: [eventDayId],
      orderBy: 'sessionNumber ASC',
    );

    return maps.map((map) => EventSession.fromMap(map)).toList();
  }

  Future<List<EventSession>> getAllEventSessions() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_sessions',
      orderBy: 'sessionNumber ASC',
    );

    return maps.map((map) => EventSession.fromMap(map)).toList();
  }

  // Update
  Future<void> updateEventSession(EventSession eventSession) async {
    final db = await _dbService.database;
    final updatedEventSession = eventSession.copyWith(updatedAt: DateTime.now());

    await db.update(
      'event_sessions',
      updatedEventSession.toMap(),
      where: 'id = ?',
      whereArgs: [eventSession.id],
    );
  }

  // Delete
  Future<void> deleteEventSession(String id) async {
    final db = await _dbService.database;
    await db.delete(
      'event_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clone a session with all its floors and judge assignments
  Future<EventSession> cloneEventSession({
    required String eventSessionId,
    String? newEventDayId,
    bool includeJudgeAssignments = true,
  }) async {
    final db = await _dbService.database;
    
    // Get the original session
    final originalSession = await getEventSessionById(eventSessionId);
    if (originalSession == null) {
      throw Exception('Event session not found');
    }

    // Use the same day if not specified
    final targetDayId = newEventDayId ?? originalSession.eventDayId;

    // Get the next session number for this day
    final existingSessions = await getEventSessionsByDayId(targetDayId);
    final nextSessionNumber = existingSessions.isEmpty 
        ? 1 
        : existingSessions.map((s) => s.sessionNumber).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now();
    
    // Create the new session
    final newSession = EventSession(
      id: _uuid.v4(),
      eventDayId: targetDayId,
      sessionNumber: nextSessionNumber,
      name: originalSession.name,
      startTime: originalSession.startTime,
      endTime: originalSession.endTime,
      notes: originalSession.notes,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('event_sessions', newSession.toMap());

    // Clone all floors
    final floorRepo = EventFloorRepository();
    final floors = await floorRepo.getEventFloorsBySessionId(eventSessionId);
    
    for (final floor in floors) {
      await floorRepo.cloneEventFloor(
        eventFloorId: floor.id,
        newEventSessionId: newSession.id,
        includeJudgeAssignments: includeJudgeAssignments,
      );
    }

    return newSession;
  }

  // Helper methods
  Future<int> getEventSessionCount(String eventDayId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM event_sessions WHERE eventDayId = ?',
      [eventDayId],
    );
    return result.first['count'] as int;
  }

  // Get sessions for a specific event (across all days)
  Future<List<EventSession>> getEventSessionsByEventId(String eventId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT es.* 
      FROM event_sessions es
      INNER JOIN event_days ed ON es.eventDayId = ed.id
      WHERE ed.eventId = ?
      ORDER BY ed.dayNumber ASC, es.sessionNumber ASC
    ''', [eventId]);

    return maps.map((map) => EventSession.fromMap(map)).toList();
  }
}
