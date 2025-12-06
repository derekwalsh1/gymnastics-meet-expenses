import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../services/database_service.dart';

class EventRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  final _uuid = const Uuid();

  // Create
  Future<Event> createEvent({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required EventLocation location,
    required String description,
    double? totalBudget,
    String? associationId,
    EventStatus status = EventStatus.upcoming,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    final event = Event(
      id: _uuid.v4(),
      name: name,
      startDate: startDate,
      endDate: endDate,
      location: location,
      description: description,
      totalBudget: totalBudget,
      associationId: associationId,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('events', event.toMap());
    return event;
  }

  // Read
  Future<Event?> getEventById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Event.fromMap(maps.first);
  }

  Future<List<Event>> getAllEvents({EventStatus? status}) async {
    final db = await _dbService.database;
    
    final maps = status != null
        ? await db.query(
            'events',
            where: 'status = ?',
            whereArgs: [status.name],
            orderBy: 'startDate DESC',
          )
        : await db.query(
            'events',
            orderBy: 'startDate DESC',
          );

    final events = maps.map((map) => Event.fromMap(map)).toList();
    
    // Auto-update status based on current date
    await _updateEventStatuses(events);
    
    return events;
  }

  Future<List<Event>> getEventsByAssociation(String associationId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'events',
      where: 'associationId = ?',
      whereArgs: [associationId],
      orderBy: 'startDate DESC',
    );

    final events = maps.map((map) => Event.fromMap(map)).toList();
    
    // Auto-update status based on current date
    await _updateEventStatuses(events);
    
    return events;
  }

  Future<List<Event>> getUpcomingEvents() async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();
    
    final maps = await db.query(
      'events',
      where: 'startDate >= ? AND status != ?',
      whereArgs: [now, EventStatus.archived.name],
      orderBy: 'startDate ASC',
    );

    final events = maps.map((map) => Event.fromMap(map)).toList();
    
    // Auto-update status based on current date
    await _updateEventStatuses(events);
    
    return events;
  }
  
  /// Auto-update event statuses based on current date
  Future<void> _updateEventStatuses(List<Event> events) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    for (final event in events) {
      // Skip archived events
      if (event.status == EventStatus.archived) continue;
      
      final start = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      final end = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
      
      EventStatus correctStatus;
      if (today.isAfter(end)) {
        correctStatus = EventStatus.completed;
      } else if (today.isBefore(start)) {
        correctStatus = EventStatus.upcoming;
      } else {
        // Today is between start and end (inclusive)
        correctStatus = EventStatus.ongoing;
      }
      
      // Update if status is incorrect
      if (event.status != correctStatus) {
        await updateEventStatus(event.id, correctStatus);
      }
    }
  }

  Future<List<Event>> getPastEvents() async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();
    
    final maps = await db.query(
      'events',
      where: 'endDate < ?',
      whereArgs: [now],
      orderBy: 'startDate DESC',
    );

    return maps.map((map) => Event.fromMap(map)).toList();
  }

  // Update
  Future<void> updateEvent(Event event) async {
    final db = await _dbService.database;
    final updatedEvent = event.copyWith(updatedAt: DateTime.now());

    await db.update(
      'events',
      updatedEvent.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> updateEventStatus(String id, EventStatus status) async {
    final db = await _dbService.database;
    
    await db.update(
      'events',
      {
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete
  Future<void> deleteEvent(String id) async {
    final db = await _dbService.database;
    await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Archive
  Future<void> archiveEvent(String id) async {
    await updateEventStatus(id, EventStatus.archived);
  }
  
  // Unarchive - restores event to appropriate status based on dates
  Future<void> unarchiveEvent(String id) async {
    final event = await getEventById(id);
    if (event == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    final end = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
    
    EventStatus correctStatus;
    if (today.isAfter(end)) {
      correctStatus = EventStatus.completed;
    } else if (today.isBefore(start)) {
      correctStatus = EventStatus.upcoming;
    } else {
      correctStatus = EventStatus.ongoing;
    }
    
    await updateEventStatus(id, correctStatus);
  }

  // Helper methods
  Future<int> getEventCount({EventStatus? status}) async {
    final db = await _dbService.database;
    
    final result = status != null
        ? await db.rawQuery(
            'SELECT COUNT(*) as count FROM events WHERE status = ?',
            [status.name],
          )
        : await db.rawQuery('SELECT COUNT(*) as count FROM events');
    
    return result.first['count'] as int;
  }
}
