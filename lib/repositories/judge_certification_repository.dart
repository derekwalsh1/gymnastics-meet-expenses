import 'package:sqflite/sqflite.dart';
import '../models/judge_certification.dart';
import '../services/database_service.dart';

class JudgeCertificationRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  // Create a new certification
  Future<JudgeCertification> createCertification(JudgeCertification certification) async {
    final db = await _dbService.database;
    await db.insert('judge_certifications', certification.toMap());
    return certification;
  }

  // Get all certifications for a specific judge
  Future<List<JudgeCertification>> getCertificationsForJudge(String judgeId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_certifications',
      where: 'judgeId = ?',
      whereArgs: [judgeId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => JudgeCertification.fromMap(map)).toList();
  }

  // Get all judges with a specific level
  Future<List<String>> getJudgeIdsWithLevel(String judgeLevelId) async {
    final db = await _dbService.database;
    final result = await db.query(
      'judge_certifications',
      columns: ['judgeId'],
      where: 'judgeLevelId = ?',
      whereArgs: [judgeLevelId],
    );
    return result.map((row) => row['judgeId'] as String).toList();
  }

  // Get a specific certification
  Future<JudgeCertification?> getCertification(String judgeId, String judgeLevelId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'judge_certifications',
      where: 'judgeId = ? AND judgeLevelId = ?',
      whereArgs: [judgeId, judgeLevelId],
    );
    
    if (maps.isEmpty) return null;
    return JudgeCertification.fromMap(maps.first);
  }

  // Update a certification
  Future<int> updateCertification(JudgeCertification certification) async {
    final db = await _dbService.database;
    return await db.update(
      'judge_certifications',
      certification.toMap(),
      where: 'id = ?',
      whereArgs: [certification.id],
    );
  }

  // Delete a certification (remove judge from level)
  Future<int> deleteCertification(String judgeId, String judgeLevelId) async {
    final db = await _dbService.database;
    return await db.delete(
      'judge_certifications',
      where: 'judgeId = ? AND judgeLevelId = ?',
      whereArgs: [judgeId, judgeLevelId],
    );
  }

  // Delete all certifications for a judge
  Future<int> deleteCertificationsForJudge(String judgeId) async {
    final db = await _dbService.database;
    return await db.delete(
      'judge_certifications',
      where: 'judgeId = ?',
      whereArgs: [judgeId],
    );
  }

  // Check if a judge has a specific certification
  Future<bool> hasCertification(String judgeId, String judgeLevelId) async {
    final db = await _dbService.database;
    final result = await db.query(
      'judge_certifications',
      where: 'judgeId = ? AND judgeLevelId = ?',
      whereArgs: [judgeId, judgeLevelId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Get count of certifications for a judge
  Future<int> getCertificationCount(String judgeId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM judge_certifications WHERE judgeId = ?',
      [judgeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Check if judge already has certification in an association
  Future<bool> hasAssociationCertification(String judgeId, String association) async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM judge_certifications jc
      INNER JOIN judge_levels jl ON jc.judgeLevelId = jl.id
      WHERE jc.judgeId = ? AND jl.association = ?
    ''', [judgeId, association]);
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }
}
