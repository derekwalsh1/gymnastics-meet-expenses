import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/judge_level.dart';
import '../repositories/judge_level_repository.dart';

class JudgeLevelImportExportService {
  final JudgeLevelRepository _judgeLevelRepository = JudgeLevelRepository();
  final _uuid = const Uuid();

  /// Export all judge levels to a CSV file
  /// Returns the File object of the created CSV
  Future<File> exportJudgeLevelsToCsv({bool includeArchived = false}) async {
    final levels = await _judgeLevelRepository.getAllJudgeLevels(includeArchived: includeArchived);
    
    // Create CSV content
    final List<List<String>> csvData = [
      // Header row
      [
        'Association',
        'Level',
        'Default Hourly Rate',
        'Sort Order',
        'Archived',
      ],
      // Data rows
      ...levels.map((level) => [
        level.association,
        level.level,
        level.defaultHourlyRate.toString(),
        level.sortOrder.toString(),
        level.isArchived ? 'true' : 'false',
      ]),
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'judge_levels_export_$timestamp.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);
    
    return file;
  }

  /// Import judge levels from a CSV file
  /// Returns a summary of the import operation
  Future<JudgeLevelImportResult> importJudgeLevelsFromCsv(File csvFile) async {
    final csvString = await csvFile.readAsString();
    final csvData = const CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvString);
    
    if (csvData.isEmpty) {
      return JudgeLevelImportResult(
        success: false,
        message: 'CSV file is empty',
        levelsCreated: 0,
        levelsUpdated: 0,
        errors: [],
      );
    }

    // Validate header
    final header = csvData[0].map((e) => e.toString().toLowerCase()).toList();
    final expectedHeaders = [
      'association',
      'level',
      'default hourly rate',
      'sort order',
      'archived',
    ];
    
    if (!_validateHeaders(header, expectedHeaders)) {
      return JudgeLevelImportResult(
        success: false,
        message: 'Invalid CSV format. Expected headers: ${expectedHeaders.join(", ")}\nFound: ${header.join(", ")}',
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
    
    // Process each row (skip header)
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      
      try {
        if (row.length < 5) {
          errors.add('Row ${i + 1}: Insufficient columns');
          continue;
        }
        
        final association = row[0].toString().trim();
        final level = row[1].toString().trim();
        final hourlyRateStr = row[2].toString().trim();
        final sortOrderStr = row[3].toString().trim();
        final isArchivedStr = row[4].toString().trim().toLowerCase();
        
        if (association.isEmpty || level.isEmpty) {
          errors.add('Row ${i + 1}: Association and level are required');
          continue;
        }

        // Parse numeric values
        final double hourlyRate;
        try {
          hourlyRate = double.parse(hourlyRateStr);
        } catch (e) {
          errors.add('Row ${i + 1}: Invalid hourly rate "$hourlyRateStr"');
          continue;
        }

        final int sortOrder;
        try {
          sortOrder = int.parse(sortOrderStr);
        } catch (e) {
          errors.add('Row ${i + 1}: Invalid sort order "$sortOrderStr"');
          continue;
        }

        final isArchived = isArchivedStr == 'true' || isArchivedStr == '1' || isArchivedStr == 'yes';
        
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
          // Create new level
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
        errors.add('Row ${i + 1}: ${e.toString()}');
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
  }

  bool _validateHeaders(List<String> actual, List<String> expected) {
    if (actual.length < expected.length) return false;
    
    for (int i = 0; i < expected.length; i++) {
      // Normalize both headers by removing spaces and converting to lowercase
      final normalizedActual = actual[i].replaceAll(' ', '').toLowerCase();
      final normalizedExpected = expected[i].replaceAll(' ', '').toLowerCase();
      
      if (normalizedActual != normalizedExpected) {
        return false;
      }
    }
    return true;
  }

  /// Create a sample/template CSV file for importing judge levels
  Future<File> createSampleCsv() async {
    final List<List<String>> csvData = [
      // Header row
      [
        'Association',
        'Level',
        'Default Hourly Rate',
        'Sort Order',
        'Archived',
      ],
      // Sample data rows - based on common gymnastics judging levels
      [
        'USAG',
        'National',
        '75.00',
        '10',
        'false',
      ],
      [
        'USAG',
        'Regional',
        '60.00',
        '20',
        'false',
      ],
      [
        'USAG',
        'State',
        '45.00',
        '30',
        'false',
      ],
      [
        'AAU',
        'Level 5',
        '70.00',
        '10',
        'false',
      ],
      [
        'AAU',
        'Level 4',
        '60.00',
        '20',
        'false',
      ],
      [
        'AAU',
        'Level 3',
        '50.00',
        '30',
        'false',
      ],
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'judge_levels_import_template.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);
    
    return file;
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
