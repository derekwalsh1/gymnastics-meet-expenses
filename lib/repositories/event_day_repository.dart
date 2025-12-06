import 'package:uuid/uuid.dart';
import '../models/event_day.dart';
import '../services/database_service.dart';

class EventDayRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  final _uuid = const Uuid();

  // Create
  Future<EventDay> createEventDay({
    required String eventId,
    required int dayNumber,
    required DateTime date,
    String? notes,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    final eventDay = EventDay(
      id: _uuid.v4(),
      eventId: eventId,
      dayNumber: dayNumber,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('event_days', eventDay.toMap());
    return eventDay;
  }

  // Read
  Future<EventDay?> getEventDayById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_days',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return EventDay.fromMap(maps.first);
  }

  Future<List<EventDay>> getEventDaysByEventId(String eventId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_days',
      where: 'eventId = ?',
      whereArgs: [eventId],
      orderBy: 'dayNumber ASC',
    );

    return maps.map((map) => EventDay.fromMap(map)).toList();
  }

  Future<List<EventDay>> getAllEventDays() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_days',
      orderBy: 'date ASC',
    );

    return maps.map((map) => EventDay.fromMap(map)).toList();
  }

  // Update
  Future<void> updateEventDay(EventDay eventDay) async {
    final db = await _dbService.database;
    final updatedEventDay = eventDay.copyWith(updatedAt: DateTime.now());

    await db.update(
      'event_days',
      updatedEventDay.toMap(),
      where: 'id = ?',
      whereArgs: [eventDay.id],
    );
  }

  // Delete
  Future<void> deleteEventDay(String id) async {
    final db = await _dbService.database;
    await db.delete(
      'event_days',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper methods
  Future<int> getEventDayCount(String eventId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM event_days WHERE eventId = ?',
      [eventId],
    );
    return result.first['count'] as int;
  }
}
