import 'package:uuid/uuid.dart';
import '../models/judge_fee.dart';
import '../services/database_service.dart';

class JudgeFeeRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  final _uuid = const Uuid();

  // Create
  Future<JudgeFee> createFee({
    required String judgeAssignmentId,
    required FeeType feeType,
    required String description,
    required double amount,
    double? hours,
    bool isAutoCalculated = false,
    bool isTaxable = true,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    final fee = JudgeFee(
      id: _uuid.v4(),
      judgeAssignmentId: judgeAssignmentId,
      feeType: feeType,
      description: description,
      amount: amount,
      hours: hours,
      isAutoCalculated: isAutoCalculated,
      isTaxable: isTaxable,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('judge_fees', fee.toMap());
    return fee;
  }

  // Read
  Future<JudgeFee?> getFeeById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_fees',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return JudgeFee.fromMap(maps.first);
  }

  Future<List<JudgeFee>> getFeesByAssignmentId(String assignmentId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_fees',
      where: 'judgeAssignmentId = ?',
      whereArgs: [assignmentId],
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => JudgeFee.fromMap(map)).toList();
  }

  Future<List<JudgeFee>> getFeesForJudgeInEvent({
    required String judgeId,
    required String eventId,
  }) async {
    final db = await _dbService.database;
    
    // Join with judge_assignments to filter by judge and event
    final maps = await db.rawQuery('''
      SELECT jf.*
      FROM judge_fees jf
      INNER JOIN judge_assignments ja ON jf.judgeAssignmentId = ja.id
      INNER JOIN event_floors ef ON ja.eventFloorId = ef.id
      INNER JOIN event_sessions es ON ef.eventSessionId = es.id
      INNER JOIN event_days ed ON es.eventDayId = ed.id
      WHERE ja.judgeId = ? AND ed.eventId = ?
      ORDER BY jf.createdAt ASC
    ''', [judgeId, eventId]);

    return maps.map((map) => JudgeFee.fromMap(map)).toList();
  }

  // Update
  Future<void> updateFee(JudgeFee fee) async {
    final db = await _dbService.database;
    final updatedFee = fee.copyWith(updatedAt: DateTime.now());

    await db.update(
      'judge_fees',
      updatedFee.toMap(),
      where: 'id = ?',
      whereArgs: [fee.id],
    );
  }

  // Delete
  Future<void> deleteFee(String id) async {
    final db = await _dbService.database;
    await db.delete(
      'judge_fees',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFeesForAssignment(String assignmentId) async {
    final db = await _dbService.database;
    await db.delete(
      'judge_fees',
      where: 'judgeAssignmentId = ?',
      whereArgs: [assignmentId],
    );
  }

  // Calculations
  Future<double> getTotalFeesForAssignment(String assignmentId) async {
    final fees = await getFeesByAssignmentId(assignmentId);
    return fees.fold<double>(0.0, (sum, fee) => sum + fee.amount);
  }

  Future<double> getTotalTaxableFeesForAssignment(String assignmentId) async {
    final fees = await getFeesByAssignmentId(assignmentId);
    return fees.where((f) => f.isTaxable).fold<double>(0.0, (sum, fee) => sum + fee.amount);
  }

  Future<double> getTotalFeesForJudgeInEvent({
    required String judgeId,
    required String eventId,
  }) async {
    final fees = await getFeesForJudgeInEvent(judgeId: judgeId, eventId: eventId);
    return fees.fold<double>(0.0, (sum, fee) => sum + fee.amount);
  }
}
