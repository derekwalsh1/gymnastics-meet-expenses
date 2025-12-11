import 'package:uuid/uuid.dart';
import '../models/judge_assignment.dart';
import '../models/judge_with_level.dart';
import '../models/judge_fee.dart';
import '../services/database_service.dart';
import 'event_floor_repository.dart';
import 'event_session_repository.dart';
import 'judge_fee_repository.dart';

class JudgeAssignmentRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  final _uuid = const Uuid();

  // Create assignment with judge snapshot and auto-create session fee
  Future<JudgeAssignment> createAssignment({
    required String eventFloorId,
    required JudgeWithLevels judge,
    required String association,
    String? role,
    double? customHourlyRate,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    // Get the judge's level for this association
    final levels = judge.levelsFor(association);
    if (levels.isEmpty) {
      throw Exception('Judge does not have certification for $association');
    }
    final level = levels.first;

    final assignment = JudgeAssignment(
      id: _uuid.v4(),
      eventFloorId: eventFloorId,
      judgeId: judge.judge.id,
      judgeFirstName: judge.judge.firstName,
      judgeLastName: judge.judge.lastName,
      judgeAssociation: association,
      judgeLevel: level.level,
      judgeContactInfo: judge.judge.contactInfo,
      role: role,
      hourlyRate: customHourlyRate ?? level.defaultHourlyRate,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('judge_assignments', assignment.toMap());

    // Auto-create session fee
    try {
      final floorRepo = EventFloorRepository();
      final sessionRepo = EventSessionRepository();
      final feeRepo = JudgeFeeRepository();

      final floor = await floorRepo.getEventFloorById(eventFloorId);
      if (floor != null) {
        final session = await sessionRepo.getEventSessionById(floor.eventSessionId);
        if (session != null) {
          final sessionHours = session.durationInHours;
          final amount = assignment.hourlyRate * sessionHours;

          await feeRepo.createFee(
            judgeAssignmentId: assignment.id,
            feeType: FeeType.sessionRate,
            description: 'Session fee for ${session.name}',
            amount: amount,
            hours: sessionHours,
            isAutoCalculated: true,
            isTaxable: true,
          );
        }
      }
    } catch (e) {
      print('Warning: Failed to auto-create session fee: $e');
      // Don't fail the assignment if fee creation fails
    }

    return assignment;
  }

  // Read
  Future<JudgeAssignment?> getAssignmentById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return JudgeAssignment.fromMap(maps.first);
  }

  Future<List<JudgeAssignment>> getAssignmentsByFloorId(String eventFloorId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_assignments',
      where: 'eventFloorId = ?',
      whereArgs: [eventFloorId],
      orderBy: 'judgeLastName ASC, judgeFirstName ASC',
    );

    return maps.map((map) => JudgeAssignment.fromMap(map)).toList();
  }

  Future<List<JudgeAssignment>> getAssignmentsBySessionId(String eventSessionId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT ja.* 
      FROM judge_assignments ja
      INNER JOIN event_floors ef ON ja.eventFloorId = ef.id
      WHERE ef.eventSessionId = ?
      ORDER BY ef.floorNumber ASC, ja.judgeLastName ASC, ja.judgeFirstName ASC
    ''', [eventSessionId]);

    return maps.map((map) => JudgeAssignment.fromMap(map)).toList();
  }

  Future<List<JudgeAssignment>> getAssignmentsByEventId(String eventId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT ja.* 
      FROM judge_assignments ja
      INNER JOIN event_floors ef ON ja.eventFloorId = ef.id
      INNER JOIN event_sessions es ON ef.eventSessionId = es.id
      INNER JOIN event_days ed ON es.eventDayId = ed.id
      WHERE ed.eventId = ?
      ORDER BY ed.dayNumber ASC, es.sessionNumber ASC, ef.floorNumber ASC, 
               ja.judgeLastName ASC, ja.judgeFirstName ASC
    ''', [eventId]);

    return maps.map((map) => JudgeAssignment.fromMap(map)).toList();
  }

  Future<List<JudgeAssignment>> getAssignmentsByJudgeId(String judgeId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_assignments',
      where: 'judgeId = ?',
      whereArgs: [judgeId],
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => JudgeAssignment.fromMap(map)).toList();
  }

  // Update
  Future<void> updateAssignment(JudgeAssignment assignment) async {
    final db = await _dbService.database;
    final updatedAssignment = assignment.copyWith(updatedAt: DateTime.now());

    await db.update(
      'judge_assignments',
      updatedAssignment.toMap(),
      where: 'id = ?',
      whereArgs: [assignment.id],
    );
  }

  // Delete
  Future<void> deleteAssignment(String id) async {
    final db = await _dbService.database;
    
    // Delete associated fees first
    final feeRepo = JudgeFeeRepository();
    await feeRepo.deleteFeesForAssignment(id);
    
    // Then delete the assignment
    await db.delete(
      'judge_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Conflict detection - check if judge is already assigned to another floor at the same time
  Future<bool> hasConflict({
    required String judgeId,
    required String eventSessionId,
    String? excludeAssignmentId,
  }) async {
    final db = await _dbService.database;
    
    // Get all floors for this session
    final floorMaps = await db.query(
      'event_floors',
      where: 'eventSessionId = ?',
      whereArgs: [eventSessionId],
    );

    if (floorMaps.isEmpty) return false;

    final floorIds = floorMaps.map((m) => m['id'] as String).toList();

    // Check if judge is assigned to any floor in this session
    final whereClause = excludeAssignmentId != null
        ? 'judgeId = ? AND eventFloorId IN (${floorIds.map((_) => '?').join(',')}) AND id != ?'
        : 'judgeId = ? AND eventFloorId IN (${floorIds.map((_) => '?').join(',')})';

    final whereArgs = excludeAssignmentId != null
        ? [judgeId, ...floorIds, excludeAssignmentId]
        : [judgeId, ...floorIds];

    final conflictMaps = await db.query(
      'judge_assignments',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return conflictMaps.isNotEmpty;
  }

  // Get available judges for a session (not already assigned to another floor at same time)
  Future<List<String>> getAvailableJudgeIds(String eventSessionId) async {
    final db = await _dbService.database;
    
    // Get all judges
    final allJudgeMaps = await db.query('judges', where: 'isArchived = 0');
    final allJudgeIds = allJudgeMaps.map((m) => m['id'] as String).toSet();

    // Get judges already assigned to this session
    final assignedMaps = await db.rawQuery('''
      SELECT DISTINCT ja.judgeId
      FROM judge_assignments ja
      INNER JOIN event_floors ef ON ja.eventFloorId = ef.id
      WHERE ef.eventSessionId = ?
    ''', [eventSessionId]);

    final assignedJudgeIds = assignedMaps.map((m) => m['judgeId'] as String).toSet();

    // Return available judges (all - assigned)
    return allJudgeIds.difference(assignedJudgeIds).toList();
  }

  // Get judge assignments for a specific judge and event (for financial tracking)
  Future<List<JudgeAssignment>> getJudgeEventAssignments({
    required String judgeId,
    required String eventId,
  }) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT ja.* 
      FROM judge_assignments ja
      INNER JOIN event_floors ef ON ja.eventFloorId = ef.id
      INNER JOIN event_sessions es ON ef.eventSessionId = es.id
      INNER JOIN event_days ed ON es.eventDayId = ed.id
      WHERE ja.judgeId = ? AND ed.eventId = ?
      ORDER BY ed.dayNumber ASC, es.sessionNumber ASC, ef.floorNumber ASC
    ''', [judgeId, eventId]);

    return maps.map((map) => JudgeAssignment.fromMap(map)).toList();
  }

  // Helper methods
  Future<int> getAssignmentCount(String eventFloorId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM judge_assignments WHERE eventFloorId = ?',
      [eventFloorId],
    );
    return result.first['count'] as int;
  }

  Future<int> getSessionAssignmentCount(String eventSessionId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM judge_assignments ja
      INNER JOIN event_floors ef ON ja.eventFloorId = ef.id
      WHERE ef.eventSessionId = ?
    ''', [eventSessionId]);
    return result.first['count'] as int;
  }

  Future<int> getEventAssignmentCount(String eventId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM judge_assignments ja
      INNER JOIN event_floors ef ON ja.eventFloorId = ef.id
      INNER JOIN event_sessions es ON ef.eventSessionId = es.id
      INNER JOIN event_days ed ON es.eventDayId = ed.id
      WHERE ed.eventId = ?
    ''', [eventId]);
    return result.first['count'] as int;
  }

  // Helper methods to get related entities
  Future<dynamic> getEventFloorById(String floorId) async {
    return await EventFloorRepository().getEventFloorById(floorId);
  }

  Future<dynamic> getEventSessionById(String sessionId) async {
    return await EventSessionRepository().getEventSessionById(sessionId);
  }

  Future<dynamic> getEventDayById(String dayId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'event_days',
      where: 'id = ?',
      whereArgs: [dayId],
    );
    if (maps.isEmpty) return null;
    // Return raw map since we don't have EventDay import here
    return maps.first;
  }

  // Recalculate auto-calculated session fees after time changes
  Future<void> recalcAutoFeesForSession(String eventSessionId) async {
    final sessionRepo = EventSessionRepository();
    final feeRepo = JudgeFeeRepository();

    final session = await sessionRepo.getEventSessionById(eventSessionId);
    if (session == null) return;

    final sessionHours = session.durationInHours;
    final assignments = await getAssignmentsBySessionId(eventSessionId);

    for (final assignment in assignments) {
      final fees = await feeRepo.getFeesByAssignmentId(assignment.id);

      JudgeFee? autoSessionFee;
      for (final fee in fees) {
        if (fee.isAutoCalculated && fee.feeType == FeeType.sessionRate) {
          autoSessionFee = fee;
          break;
        }
      }

      final amount = assignment.hourlyRate * sessionHours;

      if (autoSessionFee != null) {
        final updated = autoSessionFee.copyWith(
          amount: amount,
          hours: sessionHours,
        );
        await feeRepo.updateFee(updated);
      } else {
        await feeRepo.createFee(
          judgeAssignmentId: assignment.id,
          feeType: FeeType.sessionRate,
          description: 'Session fee for ${session.name}',
          amount: amount,
          hours: sessionHours,
          isAutoCalculated: true,
          isTaxable: true,
        );
      }
    }
  }

  // Clone an assignment to a new floor
  Future<JudgeAssignment> cloneAssignment({
    required String assignmentId,
    required String newEventFloorId,
  }) async {
    final db = await _dbService.database;
    
    // Get the original assignment
    final originalAssignment = await getAssignmentById(assignmentId);
    if (originalAssignment == null) {
      throw Exception('Assignment not found');
    }

    final now = DateTime.now();
    
    // Create the new assignment with the same judge info
    final newAssignment = JudgeAssignment(
      id: _uuid.v4(),
      eventFloorId: newEventFloorId,
      judgeId: originalAssignment.judgeId,
      judgeFirstName: originalAssignment.judgeFirstName,
      judgeLastName: originalAssignment.judgeLastName,
      judgeAssociation: originalAssignment.judgeAssociation,
      judgeLevel: originalAssignment.judgeLevel,
      judgeContactInfo: originalAssignment.judgeContactInfo,
      role: originalAssignment.role,
      hourlyRate: originalAssignment.hourlyRate,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('judge_assignments', newAssignment.toMap());

    // Auto-create session fee for the new assignment
    try {
      final floorRepo = EventFloorRepository();
      final sessionRepo = EventSessionRepository();
      final feeRepo = JudgeFeeRepository();

      final floor = await floorRepo.getEventFloorById(newEventFloorId);
      if (floor != null) {
        final session = await sessionRepo.getEventSessionById(floor.eventSessionId);
        if (session != null) {
          final sessionHours = session.durationInHours;
          final amount = newAssignment.hourlyRate * sessionHours;

          await feeRepo.createFee(
            judgeAssignmentId: newAssignment.id,
            feeType: FeeType.sessionRate,
            description: 'Session fee for ${session.name}',
            amount: amount,
            hours: sessionHours,
            isAutoCalculated: true,
            isTaxable: true,
          );
        }
      }
    } catch (e) {
      print('Warning: Failed to auto-create session fee: $e');
      // Don't fail the assignment if fee creation fails
    }

    return newAssignment;
  }
}
