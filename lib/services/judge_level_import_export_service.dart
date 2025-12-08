import 'dart:io';
import 'dart:convert';
import 'package:async/async.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/judge_level.dart';
import '../repositories/judge_level_repository.dart';

class JudgeLevelImportExportService {
  final JudgeLevelRepository _judgeLevelRepository = JudgeLevelRepository();
  final _uuid = const Uuid();
  CancelableOperation<JudgeLevelImportResult>? _currentImportOperation;

  /// Cancel the currently running import operation
  void cancelImport() {
    _currentImportOperation?.cancel();
    _currentImportOperation = null;
  }

  /// Export all judge levels to a JSON file
  /// Returns the File object of the created JSON
  Future<File> exportJudgeLevels({bool includeArchived = false}) async {
    final levels = await _judgeLevelRepository.getAllJudgeLevels(includeArchived: includeArchived);
    
    // Create JSON structure
    final exportData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'judgeLevels': levels.map((level) => level.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    
    // Save to file - use appropriate location for platform
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'judge_levels_$timestamp.json';
    
    // On Android: try to save to Download folder for user accessibility
    // On iOS: use app documents directory (iOS doesn't have public Downloads)
    final externalDir = await getExternalStorageDirectory();
    late File file;
    
    if (externalDir != null) {
      // Android: Save to /storage/emulated/0/Download/
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
      // iOS or other platforms: Use app documents directory
      final docDir = await getApplicationDocumentsDirectory();
      file = File('${docDir.path}/$fileName');
    }
    
    await file.writeAsString(jsonString);
    return file;
  }

  /// Import judge levels from a JSON file
  /// Returns a summary of the import operation
  /// Can be cancelled using cancelImport()
  Future<JudgeLevelImportResult> importJudgeLevels(File jsonFile) async {
    _currentImportOperation = CancelableOperation<JudgeLevelImportResult>.fromFuture(
      _doImportJudgeLevels(jsonFile),
    );
    
    try {
      final result = await _currentImportOperation!.value;
      _currentImportOperation = null;
      return result;
    } catch (e) {
      _currentImportOperation = null;
      // When cancelled, the operation throws an error
      return JudgeLevelImportResult(
        success: false,
        message: 'Import cancelled by user',
        levelsCreated: 0,
        levelsUpdated: 0,
        errors: [],
      );
    }
  }

  Future<JudgeLevelImportResult> _doImportJudgeLevels(File jsonFile) async {
    try {
      final jsonString = await jsonFile.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      // Validate structure
      if (!jsonData.containsKey('judgeLevels')) {
        return JudgeLevelImportResult(
          success: false,
          message: 'Invalid file format: missing "judgeLevels" field',
          levelsCreated: 0,
          levelsUpdated: 0,
          errors: [],
        );
      }

      final List<dynamic> levelsList = jsonData['judgeLevels'];
      if (levelsList.isEmpty) {
        return JudgeLevelImportResult(
          success: false,
          message: 'File contains no judge levels',
          levelsCreated: 0,
          levelsUpdated: 0,
          errors: [],
        );
      }

      int levelsCreated = 0;
      int levelsUpdated = 0;
      final List<String> errors = [];
      
      // Get all existing levels once
      final existingLevels = await _judgeLevelRepository.getAllJudgeLevels(includeArchived: true);
      
      // Process each level
      for (int i = 0; i < levelsList.length; i++) {
        try {
          final levelData = levelsList[i] as Map<String, dynamic>;
          
          // Parse from JSON
          final association = (levelData['association'] ?? '').toString().trim();
          final level = (levelData['level'] ?? '').toString().trim();
          
          if (association.isEmpty || level.isEmpty) {
            errors.add('Level ${i + 1}: Association and level are required');
            continue;
          }

          final hourlyRate = (levelData['defaultHourlyRate'] ?? 0.0).toDouble();
          final sortOrder = (levelData['sortOrder'] ?? 0).toInt();
          final isArchived = levelData['isArchived'] == true;
          
          // Check if this judge level already exists
          final exactMatch = existingLevels.where((jl) =>
            jl.association.toLowerCase() == association.toLowerCase() &&
            jl.level.toLowerCase() == level.toLowerCase()
          ).firstOrNull;
          
          if (exactMatch != null) {
            // Update existing level
            final updatedLevel = exactMatch.copyWith(
              defaultHourlyRate: hourlyRate,
              sortOrder: sortOrder,
              isArchived: isArchived,
              updatedAt: DateTime.now(),
            );
            await _judgeLevelRepository.updateJudgeLevel(updatedLevel);
            levelsUpdated++;
          } else {
            // Create new level with new ID
            final now = DateTime.now();
            final newLevel = JudgeLevel(
              id: _uuid.v4(),
              association: association,
              level: level,
              defaultHourlyRate: hourlyRate,
              sortOrder: sortOrder,
              createdAt: now,
              updatedAt: now,
              isArchived: isArchived,
            );
            await _judgeLevelRepository.createJudgeLevel(newLevel);
            levelsCreated++;
            
            // Add to existing levels list for subsequent checks in this import
            existingLevels.add(newLevel);
          }
          
        } catch (e) {
          errors.add('Level ${i + 1}: ${e.toString()}');
        }
      }

      final bool success = levelsCreated > 0 || levelsUpdated > 0;
      final message = success
          ? 'Import completed: $levelsCreated created, $levelsUpdated updated'
          : 'Import failed: No judge levels were created or updated';

      return JudgeLevelImportResult(
        success: success,
        message: message,
        levelsCreated: levelsCreated,
        levelsUpdated: levelsUpdated,
        errors: errors,
      );
    } catch (e) {
      return JudgeLevelImportResult(
        success: false,
        message: 'Failed to parse JSON file: ${e.toString()}',
        levelsCreated: 0,
        levelsUpdated: 0,
        errors: [e.toString()],
      );
    }
  }
}

class JudgeLevelImportResult {
  final bool success;
  final String message;
  final int levelsCreated;
  final int levelsUpdated;
  final List<String> errors;

  JudgeLevelImportResult({
    required this.success,
    required this.message,
    required this.levelsCreated,
    required this.levelsUpdated,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}
