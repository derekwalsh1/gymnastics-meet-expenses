import 'package:sqflite/sqflite.dart';
import '../models/judge.dart';
import '../models/judge_with_level.dart';
import '../models/judge_level.dart';
import '../services/database_service.dart';

class JudgeRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  // Create a new judge (no longer takes judgeLevelId)
  Future<Judge> createJudge(Judge judge) async {
    final db = await _dbService.database;
    await db.insert('judges', judge.toMap());
    return judge;
  }

  // Read all judges (excluding archived by default)
  Future<List<Judge>> getAllJudges({bool includeArchived = false}) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps;
    
    if (includeArchived) {
      maps = await db.query('judges', orderBy: 'lastName ASC, firstName ASC');
    } else {
      maps = await db.query(
        'judges',
        where: 'isArchived = ?',
        whereArgs: [0],
        orderBy: 'lastName ASC, firstName ASC',
      );
    }

    return maps.map((map) => Judge.fromMap(map)).toList();
  }

  // Read a single judge by ID
  Future<Judge?> getJudgeById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judges',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Judge.fromMap(maps.first);
  }

  // Update a judge
  Future<int> updateJudge(Judge judge) async {
    final db = await _dbService.database;
    return await db.update(
      'judges',
      judge.toMap(),
      where: 'id = ?',
      whereArgs: [judge.id],
    );
  }

  // Delete a judge (hard delete)
  Future<int> deleteJudge(String id) async {
    final db = await _dbService.database;
    return await db.delete(
      'judges',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Archive a judge (soft delete)
  Future<int> archiveJudge(String id) async {
    final db = await _dbService.database;
    return await db.update(
      'judges',
      {'isArchived': 1, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Unarchive a judge
  Future<int> unarchiveJudge(String id) async {
    final db = await _dbService.database;
    return await db.update(
      'judges',
      {'isArchived': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Search judges by name
  Future<List<Judge>> searchJudges(String query) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judges',
      where: 'isArchived = ? AND (firstName LIKE ? OR lastName LIKE ?)',
      whereArgs: [0, '%$query%', '%$query%'],
      orderBy: 'lastName ASC, firstName ASC',
    );

    return maps.map((map) => Judge.fromMap(map)).toList();
  }

  // Filter judges by association (updated for v3)
  Future<List<Judge>> getJudgesByAssociation(String association) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT j.* FROM judges j
      INNER JOIN judge_certifications jc ON j.id = jc.judgeId
      INNER JOIN judge_levels jl ON jc.judgeLevelId = jl.id
      WHERE j.isArchived = 0 AND jl.association = ?
      ORDER BY j.lastName ASC, j.firstName ASC
    ''', [association]);

    return maps.map((map) => Judge.fromMap(map)).toList();
  }

  // Filter judges by level (updated for v3)
  Future<List<Judge>> getJudgesByLevel(String levelId) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT j.* FROM judges j
      INNER JOIN judge_certifications jc ON j.id = jc.judgeId
      WHERE j.isArchived = 0 AND jc.judgeLevelId = ?
      ORDER BY j.lastName ASC, j.firstName ASC
    ''', [levelId]);

    return maps.map((map) => Judge.fromMap(map)).toList();
  }

  // Get distinct associations (from judge_levels)
  Future<List<String>> getAssociations() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT association FROM judge_levels WHERE isArchived = 0 ORDER BY association ASC'
    );
    return result.map((row) => row['association'] as String).toList();
  }

  // Get distinct levels
  Future<List<String>> getLevels() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT id, level FROM judge_levels WHERE isArchived = 0 ORDER BY sortOrder ASC'
    );
    return result.map((row) => row['id'] as String).toList();
  }

  // Get judge count
  Future<int> getJudgeCount({bool includeArchived = false}) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      includeArchived 
        ? 'SELECT COUNT(*) as count FROM judges'
        : 'SELECT COUNT(*) as count FROM judges WHERE isArchived = 0'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Get judges with their level details (v3: returns JudgeWithLevels with multiple certifications)
  Future<List<JudgeWithLevels>> getJudgesWithLevels({bool includeArchived = false}) async {
    final db = await _dbService.database;
    
    // Get all judges
    final judgeMaps = await db.query(
      'judges',
      where: includeArchived ? null : 'isArchived = ?',
      whereArgs: includeArchived ? null : [0],
      orderBy: 'lastName ASC, firstName ASC',
    );
    
    final List<JudgeWithLevels> result = [];
    
    for (final judgeMap in judgeMaps) {
      final judge = Judge.fromMap(judgeMap);
      
      // Get all certifications and levels for this judge
      final levelMaps = await db.rawQuery('''
        SELECT jl.*
        FROM judge_levels jl
        INNER JOIN judge_certifications jc ON jl.id = jc.judgeLevelId
        WHERE jc.judgeId = ?
        ORDER BY jl.association ASC, jl.sortOrder ASC
      ''', [judge.id]);
      
      final levels = levelMaps.map((map) => JudgeLevel.fromMap(map)).toList();
      
      result.add(JudgeWithLevels(judge: judge, levels: levels));
    }
    
    return result;
  }
}
