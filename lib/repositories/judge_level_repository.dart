import 'package:sqflite/sqflite.dart';
import '../models/judge_level.dart';
import '../services/database_service.dart';

class JudgeLevelRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  // Create a new judge level
  Future<JudgeLevel> createJudgeLevel(JudgeLevel level) async {
    final db = await _dbService.database;
    await db.insert('judge_levels', level.toMap());
    return level;
  }

  // Read all judge levels (excluding archived by default)
  Future<List<JudgeLevel>> getAllJudgeLevels({bool includeArchived = false}) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps;
    
    if (includeArchived) {
      maps = await db.query('judge_levels', orderBy: 'sortOrder ASC');
    } else {
      maps = await db.query(
        'judge_levels',
        where: 'isArchived = ?',
        whereArgs: [0],
        orderBy: 'sortOrder ASC',
      );
    }

    return maps.map((map) => JudgeLevel.fromMap(map)).toList();
  }

  // Read a single judge level by ID
  Future<JudgeLevel?> getJudgeLevelById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_levels',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return JudgeLevel.fromMap(maps.first);
  }

  // Get levels by association
  Future<List<JudgeLevel>> getLevelsByAssociation(String association) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_levels',
      where: 'association = ? AND isArchived = ?',
      whereArgs: [association, 0],
      orderBy: 'sortOrder ASC',
    );

    return maps.map((map) => JudgeLevel.fromMap(map)).toList();
  }

  // Get distinct associations
  Future<List<String>> getAssociations() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT association FROM judge_levels WHERE isArchived = 0 ORDER BY association ASC'
    );
    return result.map((row) => row['association'] as String).toList();
  }

  // Update a judge level
  Future<int> updateJudgeLevel(JudgeLevel level) async {
    final db = await _dbService.database;
    return await db.update(
      'judge_levels',
      level.toMap(),
      where: 'id = ?',
      whereArgs: [level.id],
    );
  }

  // Delete a judge level (hard delete)
  Future<int> deleteJudgeLevel(String id) async {
    final db = await _dbService.database;
    return await db.delete(
      'judge_levels',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Archive a judge level (soft delete)
  Future<int> archiveJudgeLevel(String id) async {
    final db = await _dbService.database;
    return await db.update(
      'judge_levels',
      {'isArchived': 1, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Check if a level is in use by any judges
  Future<bool> isLevelInUse(String id) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM judges WHERE judgeLevelId = ? AND isArchived = 0',
      [id]
    );
    return Sqflite.firstIntValue(result)! > 0;
  }
}
