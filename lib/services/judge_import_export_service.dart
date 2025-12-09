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
    
    // Save to file - use appropriate location for platform
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'judges_$timestamp.json';
    
    late File file;
    
    if (Platform.isAndroid) {
      // On Android: try to save to Download folder for user accessibility
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        try {
          final basePath = externalDir.path.split('/Android/')[0];
          file = File('$basePath/Download/$fileName');
          await file.parent.create(recursive: true);
        } catch (e) {
          // Fallback if path extraction fails
          final docDir = await getApplicationDocumentsDirectory();
          file = File('${docDir.path}/$fileName');
        }
      } else {
        // Fallback if getExternalStorageDirectory fails
        final docDir = await getApplicationDocumentsDirectory();
        file = File('${docDir.path}/$fileName');
      }
    } else {
      // iOS or other platforms: Use app documents directory
      final docDir = await getApplicationDocumentsDirectory();
      file = File('${docDir.path}/$fileName');
    }
    
    await file.writeAsString(jsonString);
    return file;
  }

  /// Import judges from a JSON file
  /// Returns a summary of the import operation
  /// Can be cancelled using cancelImport()
  Future<ImportResult> importJudges(File jsonFile) async {
    _currentImportOperation = CancelableOperation<ImportResult>.fromFuture(
      _detectAndImport(jsonFile),
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
        createdJudgeNames: const [],
        updatedJudgeNames: const [],
      );
    }
  }

  Future<ImportResult> _detectAndImport(File jsonFile) async {
    try {
      final jsonString = await jsonFile.readAsString();
      final dynamic jsonData = jsonDecode(jsonString);

      if (jsonData is List) {
        // Legacy v2 judge list export (array of objects with name + level int)
        return _doImportLegacyJudges(jsonData);
      }

      if (jsonData is Map<String, dynamic>) {
        // Current v3 format
        return _doImportJudges(jsonData);
      }

      return ImportResult(
        success: false,
        message: 'Unrecognized file structure for judges import',
        judgesCreated: 0,
        judgesUpdated: 0,
        levelsAssigned: 0,
        errors: ['Top-level JSON must be an object or array'],
        createdJudgeNames: const [],
        updatedJudgeNames: const [],
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Failed to parse JSON file: ${e.toString()}',
        judgesCreated: 0,
        judgesUpdated: 0,
        levelsAssigned: 0,
        errors: [e.toString()],
        createdJudgeNames: const [],
        updatedJudgeNames: const [],
      );
    }
  }

  Future<ImportResult> _doImportJudges(Map<String, dynamic> jsonData) async {
    try {
      
      // Validate structure
      if (!jsonData.containsKey('judges')) {
        return ImportResult(
          success: false,
          message: 'Invalid file format: missing "judges" field',
          judgesCreated: 0,
          judgesUpdated: 0,
          levelsAssigned: 0,
          errors: [],
          createdJudgeNames: const [],
          updatedJudgeNames: const [],
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
          createdJudgeNames: const [],
          updatedJudgeNames: const [],
        );
      }

      int judgesCreated = 0;
      int judgesUpdated = 0;
      int levelsAssigned = 0;
      final List<String> createdNames = [];
      final List<String> updatedNames = [];
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
            updatedNames.add('${judge.fullName}'.trim());
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
            createdNames.add('${judge.fullName}'.trim());
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
        createdJudgeNames: createdNames,
        updatedJudgeNames: updatedNames,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Failed to parse JSON file: ${e.toString()}',
        judgesCreated: 0,
        judgesUpdated: 0,
        levelsAssigned: 0,
        errors: [e.toString()],
        createdJudgeNames: const [],
        updatedJudgeNames: const [],
      );
    }
  }

  Future<ImportResult> _doImportLegacyJudges(List<dynamic> judgesList) async {
    if (judgesList.isEmpty) {
      return ImportResult(
        success: false,
        message: 'File contains no judges',
        judgesCreated: 0,
        judgesUpdated: 0,
        levelsAssigned: 0,
        errors: [],
        createdJudgeNames: const [],
        updatedJudgeNames: const [],
      );
    }

    int judgesCreated = 0;
    int judgesUpdated = 0;
    int levelsAssigned = 0;
    final List<String> createdNames = [];
    final List<String> updatedNames = [];
    final List<String> errors = [];

    // Map legacy enum index to association/level/rate/sort order
    const Map<int, _LegacyLevelMapping> legacyLevelMap = {
      0: _LegacyLevelMapping('NAWGJ', '4-5', 19.0, 2),
      1: _LegacyLevelMapping('NAWGJ', '6-8', 21.0, 1),
      2: _LegacyLevelMapping('NAWGJ', '4-8', 23.0, 2),
      3: _LegacyLevelMapping('NAWGJ', 'Nine', 27.0, 3),
      4: _LegacyLevelMapping('NAWGJ', 'Ten', 31.0, 4),
      5: _LegacyLevelMapping('NAWGJ', 'National', 34.0, 6),
      6: _LegacyLevelMapping('NAWGJ', 'Brevet', 37.0, 5),
      7: _LegacyLevelMapping('NGA', 'Local', 23.0, 7),
      8: _LegacyLevelMapping('NGA', 'State', 27.0, 8),
      9: _LegacyLevelMapping('NGA', 'Regional', 31.0, 9),
      10: _LegacyLevelMapping('NGA', 'National', 34.0, 10),
      11: _LegacyLevelMapping('NGA', 'Elite', 37.0, 11),
    };

    // Cache existing levels once
    final existingLevels = await _judgeLevelRepository.getAllJudgeLevels(includeArchived: true);
    final Map<String, JudgeLevel> levelByKey = {
      for (final level in existingLevels)
        '${level.association.toLowerCase()}|${level.level.toLowerCase()}': level,
    };

    // Aggregate legacy entries by judge name so multiple levels merge
    final Map<String, _LegacyJudge> legacyJudges = {};

    for (int i = 0; i < judgesList.length; i++) {
      try {
        final entry = judgesList[i] as Map<String, dynamic>;
        final name = (entry['name'] ?? '').toString().trim();
        final levelIndex = entry['level'];

        if (name.isEmpty || levelIndex == null) {
          errors.add('Judge ${i + 1}: Missing name or level');
          continue;
        }

        final mapping = legacyLevelMap[levelIndex];
        if (mapping == null) {
          errors.add('Judge ${i + 1}: Unknown level index "$levelIndex"');
          continue;
        }

        final key = name.toLowerCase();
        legacyJudges.putIfAbsent(key, () => _LegacyJudge(originalName: name));
        legacyJudges[key]!.levelMappings.add(mapping);
      } catch (e) {
        errors.add('Judge ${i + 1}: ${e.toString()}');
      }
    }

    // Fetch all existing judges once to speed matching
    final allJudges = await _judgeRepository.getAllJudges(includeArchived: true);

    // Ensure required levels exist (create if missing)
    Future<JudgeLevel> ensureLevel(_LegacyLevelMapping mapping) async {
      final mapKey = '${mapping.association.toLowerCase()}|${mapping.level.toLowerCase()}';
      final cached = levelByKey[mapKey];
      if (cached != null) return cached;

      final now = DateTime.now();
      final newLevel = JudgeLevel(
        id: '${mapping.association}-${mapping.level}'.replaceAll(' ', '-'),
        association: mapping.association,
        level: mapping.level,
        defaultHourlyRate: mapping.rate,
        sortOrder: mapping.sortOrder,
        createdAt: now,
        updatedAt: now,
        isArchived: false,
      );

      await _judgeLevelRepository.createJudgeLevel(newLevel);
      levelByKey[mapKey] = newLevel;
      return newLevel;
    }

    for (final legacy in legacyJudges.values) {
      final nameParts = legacy.originalName.split(' ');
      String firstName;
      String lastName;
      if (nameParts.length >= 2) {
        firstName = nameParts.first.trim();
        lastName = nameParts.sublist(1).join(' ').trim();
      } else {
        firstName = legacy.originalName;
        lastName = '';
      }

      // Find existing judge by name match
      final exactMatch = allJudges.where((j) =>
        j.firstName.toLowerCase() == firstName.toLowerCase() &&
        j.lastName.toLowerCase() == lastName.toLowerCase()
      ).firstOrNull;

      Judge judge;
      if (exactMatch != null) {
        final updatedJudge = exactMatch.copyWith(
          updatedAt: DateTime.now(),
        );
        await _judgeRepository.updateJudge(updatedJudge);
        judge = updatedJudge;
        judgesUpdated++;
        updatedNames.add('${judge.fullName}'.trim());
      } else {
        final now = DateTime.now();
        judge = Judge(
          id: _uuid.v4(),
          firstName: firstName,
          lastName: lastName,
          notes: null,
          contactInfo: null,
          createdAt: now,
          updatedAt: now,
          isArchived: false,
        );
        await _judgeRepository.createJudge(judge);
        judgesCreated++;
        createdNames.add('${judge.fullName}'.trim());
      }

      // Assign certifications for each mapped level
      for (final mapping in legacy.levelMappings) {
        final level = await ensureLevel(mapping);
        final alreadyCertified = await _certificationRepository.hasCertification(
          judge.id,
          level.id,
        );

        if (!alreadyCertified) {
          final now = DateTime.now();
          final certification = JudgeCertification(
            id: _uuid.v4(),
            judgeId: judge.id,
            judgeLevelId: level.id,
            certificationDate: now,
            expirationDate: null,
            createdAt: now,
            updatedAt: now,
          );
          await _certificationRepository.createCertification(certification);
          levelsAssigned++;
        }
      }
    }

    final bool success = judgesCreated > 0 || judgesUpdated > 0;
    final message = success
        ? 'Legacy import: $judgesCreated created, $judgesUpdated updated, $levelsAssigned levels assigned'
        : 'Import failed: No judges were created or updated';

    return ImportResult(
      success: success,
      message: message,
      judgesCreated: judgesCreated,
      judgesUpdated: judgesUpdated,
      levelsAssigned: levelsAssigned,
      errors: errors,
      createdJudgeNames: createdNames,
      updatedJudgeNames: updatedNames,
    );
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int judgesCreated;
  final int judgesUpdated;
  final int levelsAssigned;
  final List<String> errors;
  final List<String> createdJudgeNames;
  final List<String> updatedJudgeNames;

  ImportResult({
    required this.success,
    required this.message,
    required this.judgesCreated,
    required this.judgesUpdated,
    required this.levelsAssigned,
    required this.errors,
    required this.createdJudgeNames,
    required this.updatedJudgeNames,
  });

  bool get hasErrors => errors.isNotEmpty;
}

class _LegacyLevelMapping {
  final String association;
  final String level;
  final double rate;
  final int sortOrder;

  const _LegacyLevelMapping(this.association, this.level, this.rate, this.sortOrder);
}

class _LegacyJudge {
  final String originalName;
  final List<_LegacyLevelMapping> levelMappings = [];

  _LegacyJudge({required this.originalName});
}
