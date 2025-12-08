import 'dart:io';
import 'dart:convert';
import 'package:async/async.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/judge.dart';
import '../models/judge_level.dart';
import '../models/judge_certification.dart';
import '../repositories/judge_repository.dart';
import '../repositories/judge_level_repository.dart';
import '../repositories/judge_certification_repository.dart';

class JudgeImportExportService {
  final JudgeRepository _judgeRepository = JudgeRepository();
  final JudgeLevelRepository _judgeLevelRepository = JudgeLevelRepository();
  final JudgeCertificationRepository _certificationRepository = JudgeCertificationRepository();
  final _uuid = const Uuid();
  CancelableOperation<ImportResult>? _currentImportOperation;

  /// Cancel the currently running import operation
  void cancelImport() {
    _currentImportOperation?.cancel();
    _currentImportOperation = null;
  }

  /// Export all judges to a JSON file
  /// Returns the File object of the created JSON
  Future<File> exportJudges({bool includeArchived = false}) async {
    final judgesWithLevels = await _judgeRepository.getJudgesWithLevels(includeArchived: includeArchived);
    
    // Build export structure
    final judgesList = judgesWithLevels.map((judgeWithLevels) {
      final judge = judgeWithLevels.judge;
      return {
        'id': judge.id,
        'firstName': judge.firstName,
        'lastName': judge.lastName,
        'contactInfo': judge.contactInfo,
        'notes': judge.notes,
        'isArchived': judge.isArchived,
        'certifications': judgeWithLevels.levels.map((level) => {
          'association': level.association,
          'level': level.level,
        }).toList(),
      };
    }).toList();

    final exportData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'judges': judgesList,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'judges_$timestamp.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString);
    
    return file;
  }

  /// Import judges from a JSON file
  /// Returns a summary of the import operation
  /// Can be cancelled using cancelImport()
  Future<ImportResult> importJudges(File jsonFile) async {
    _currentImportOperation = CancelableOperation<ImportResult>.fromFuture(
      _doImportJudges(jsonFile),
    );
    
    try {
      final result = await _currentImportOperation!.value;
      _currentImportOperation = null;
      return result;
    } catch (e) {
      _currentImportOperation = null;
      // When cancelled, the operation throws an error
      return ImportResult(
        success: false,
        message: 'Import cancelled by user',
        judgesCreated: 0,
        judgesUpdated: 0,
        levelsAssigned: 0,
        errors: [],
      );
    }
  }

  Future<ImportResult> _doImportJudges(File jsonFile) async {
    try {
      final jsonString = await jsonFile.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      // Validate structure
      if (!jsonData.containsKey('judges')) {
        return ImportResult(
          success: false,
          message: 'Invalid file format: missing "judges" field',
          judgesCreated: 0,
          judgesUpdated: 0,
          levelsAssigned: 0,
          errors: [],
        );
      }

      final List<dynamic> judgesList = jsonData['judges'];
      if (judgesList.isEmpty) {
        return ImportResult(
          success: false,
          message: 'File contains no judges',
          judgesCreated: 0,
          judgesUpdated: 0,
          levelsAssigned: 0,
          errors: [],
        );
      }

      int judgesCreated = 0;
      int judgesUpdated = 0;
      int levelsAssigned = 0;
      final List<String> errors = [];
      
      // Process each judge
      for (int i = 0; i < judgesList.length; i++) {
        try {
          final judgeData = judgesList[i] as Map<String, dynamic>;
          
          final firstName = (judgeData['firstName'] ?? '').toString().trim();
          final lastName = (judgeData['lastName'] ?? '').toString().trim();
          
          if (firstName.isEmpty || lastName.isEmpty) {
            errors.add('Judge ${i + 1}: First name and last name are required');
            continue;
          }

          final contactInfo = judgeData['contactInfo']?.toString().trim();
          final notes = judgeData['notes']?.toString().trim();
          final isArchived = judgeData['isArchived'] == true;
          final certifications = judgeData['certifications'] as List<dynamic>? ?? [];
          
          // Check if judge already exists in database
          final allJudges = await _judgeRepository.getAllJudges(includeArchived: true);
          final exactMatch = allJudges.where((j) => 
            j.firstName.toLowerCase() == firstName.toLowerCase() && 
            j.lastName.toLowerCase() == lastName.toLowerCase()
          ).firstOrNull;
          
          Judge judge;
          if (exactMatch != null) {
            // Update existing judge - merge data intelligently
            final updatedJudge = exactMatch.copyWith(
              contactInfo: exactMatch.contactInfo != null && exactMatch.contactInfo!.isNotEmpty
                  ? exactMatch.contactInfo
                  : contactInfo,
              notes: exactMatch.notes != null && exactMatch.notes!.isNotEmpty
                  ? exactMatch.notes
                  : notes,
              isArchived: exactMatch.isArchived || isArchived,
              updatedAt: DateTime.now(),
            );
            await _judgeRepository.updateJudge(updatedJudge);
            judge = updatedJudge;
            judgesUpdated++;
          } else {
            // Create new judge with new ID
            final now = DateTime.now();
            judge = Judge(
              id: _uuid.v4(),
              firstName: firstName,
              lastName: lastName,
              contactInfo: contactInfo,
              notes: notes,
              createdAt: now,
              updatedAt: now,
              isArchived: isArchived,
            );
            await _judgeRepository.createJudge(judge);
            judgesCreated++;
          }
          
          // Assign certifications
          for (final cert in certifications) {
            try {
              final association = (cert['association'] ?? '').toString().trim();
              final level = (cert['level'] ?? '').toString().trim();
              
              if (association.isEmpty || level.isEmpty) continue;
              
              // Find matching judge level
              final allLevels = await _judgeLevelRepository.getAllJudgeLevels(includeArchived: true);
              final matchingLevel = allLevels.where((jl) =>
                jl.association.toLowerCase() == association.toLowerCase() &&
                jl.level.toLowerCase() == level.toLowerCase()
              ).firstOrNull;
              
              if (matchingLevel != null) {
                // Check if this certification already exists
                final alreadyCertified = await _certificationRepository.hasCertification(
                  judge.id,
                  matchingLevel.id,
                );
                
                if (!alreadyCertified) {
                  final now = DateTime.now();
                  final certification = JudgeCertification(
                    id: _uuid.v4(),
                    judgeId: judge.id,
                    judgeLevelId: matchingLevel.id,
                    certificationDate: now,
                    expirationDate: null,
                    createdAt: now,
                    updatedAt: now,
                  );
                  await _certificationRepository.createCertification(certification);
                  levelsAssigned++;
                }
              } else {
                errors.add('Judge ${i + 1}: Level "$association $level" not found (create it first)');
              }
            } catch (e) {
              errors.add('Judge ${i + 1}, certification: ${e.toString()}');
            }
          }
          
        } catch (e) {
          errors.add('Judge ${i + 1}: ${e.toString()}');
        }
      }

      final bool success = judgesCreated > 0 || judgesUpdated > 0;
      final message = success
          ? 'Import completed: $judgesCreated created, $judgesUpdated updated, $levelsAssigned levels assigned'
          : 'Import failed: No judges were created or updated';

      return ImportResult(
        success: success,
        message: message,
        judgesCreated: judgesCreated,
        judgesUpdated: judgesUpdated,
        levelsAssigned: levelsAssigned,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Failed to parse JSON file: ${e.toString()}',
        judgesCreated: 0,
        judgesUpdated: 0,
        levelsAssigned: 0,
        errors: [e.toString()],
      );
    }
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int judgesCreated;
  final int judgesUpdated;
  final int levelsAssigned;
  final List<String> errors;

  ImportResult({
    required this.success,
    required this.message,
    required this.judgesCreated,
    required this.judgesUpdated,
    required this.levelsAssigned,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}
