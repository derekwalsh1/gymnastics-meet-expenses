import 'dart:io';
import 'package:csv/csv.dart';
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

  /// Export all judges to a CSV file
  /// Returns the File object of the created CSV
  Future<File> exportJudgesToCsv({bool includeArchived = false}) async {
    final judgesWithLevels = await _judgeRepository.getJudgesWithLevels(includeArchived: includeArchived);
    
    // Build CSV rows
    final csvRows = <Map<String, String>>[];
    
    for (final judgeWithLevels in judgesWithLevels) {
      final judge = judgeWithLevels.judge;
      
      if (judgeWithLevels.levels.isEmpty) {
        // Judge with no certifications
        csvRows.add({
          'firstName': judge.firstName,
          'lastName': judge.lastName,
          'contactInfo': judge.contactInfo ?? '',
          'notes': judge.notes ?? '',
          'association': '',
          'level': '',
          'isArchived': judge.isArchived ? 'true' : 'false',
        });
      } else {
        // Add a row for each certification
        for (final level in judgeWithLevels.levels) {
          csvRows.add({
            'firstName': judge.firstName,
            'lastName': judge.lastName,
            'contactInfo': judge.contactInfo ?? '',
            'notes': judge.notes ?? '',
            'association': level.association,
            'level': level.level,
            'isArchived': judge.isArchived ? 'true' : 'false',
          });
        }
      }
    }

    // Create CSV content
    final List<List<String>> csvData = [
      // Header row
      [
        'First Name',
        'Last Name',
        'Contact Info',
        'Notes',
        'Association',
        'Level',
        'Archived',
      ],
      // Data rows
      ...csvRows.map((data) => [
        data['firstName']!,
        data['lastName']!,
        data['contactInfo']!,
        data['notes']!,
        data['association']!,
        data['level']!,
        data['isArchived']!,
      ]),
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'judges_export_$timestamp.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);
    
    return file;
  }

  /// Import judges from a CSV file
  /// Returns a summary of the import operation
  Future<ImportResult> importJudgesFromCsv(File csvFile) async {
    final csvString = await csvFile.readAsString();
    final csvData = const CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvString);
    
    if (csvData.isEmpty) {
      return ImportResult(
        success: false,
        message: 'CSV file is empty',
        judgesCreated: 0,
        judgesUpdated: 0,
        levelsAssigned: 0,
        errors: [],
      );
    }

    // Validate header
    final header = csvData[0].map((e) => e.toString().toLowerCase()).toList();
    final expectedHeaders = [
      'first name',
      'last name',
      'contact info',
      'notes',
      'association',
      'level',
      'archived',
    ];
    
    if (!_validateHeaders(header, expectedHeaders)) {
      return ImportResult(
        success: false,
        message: 'Invalid CSV format. Expected headers: ${expectedHeaders.join(", ")}\nFound: ${header.join(", ")}',
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
    
    // Process each row (skip header)
    final Map<String, Judge> processedJudges = {};
    
    for (int i = 1; i < csvData.length; i++) {
      final row = csvData[i];
      
      try {
        if (row.length < 7) {
          errors.add('Row ${i + 1}: Insufficient columns');
          continue;
        }
        
        final firstName = row[0].toString().trim();
        final lastName = row[1].toString().trim();
        final contactInfo = row[2].toString().trim();
        final notes = row[3].toString().trim();
        final association = row[4].toString().trim();
        final level = row[5].toString().trim();
        final isArchivedStr = row[6].toString().trim().toLowerCase();
        
        if (firstName.isEmpty || lastName.isEmpty) {
          errors.add('Row ${i + 1}: First name and last name are required');
          continue;
        }

        final isArchived = isArchivedStr == 'true' || isArchivedStr == '1' || isArchivedStr == 'yes';
        
        // Create unique key for this judge
        final judgeKey = '${firstName}_${lastName}'.toLowerCase();
        
        Judge judge;
        bool isNewJudge = false;
        bool judgeWasUpdated = false;
        
        if (!processedJudges.containsKey(judgeKey)) {
          // Check if judge already exists in database
          final allJudges = await _judgeRepository.getAllJudges(includeArchived: true);
          final exactMatch = allJudges.where((j) => 
            j.firstName.toLowerCase() == firstName.toLowerCase() && 
            j.lastName.toLowerCase() == lastName.toLowerCase()
          ).firstOrNull;
          
          if (exactMatch != null) {
            // Merge with existing judge - keep existing data unless empty
            // This prevents accidental overwrites when importing
            final updatedJudge = exactMatch.copyWith(
              // Only update contact info if existing is empty and import has value
              contactInfo: exactMatch.contactInfo != null && exactMatch.contactInfo!.isNotEmpty
                  ? exactMatch.contactInfo
                  : (contactInfo.isEmpty ? null : contactInfo),
              // Only update notes if existing is empty and import has value  
              notes: exactMatch.notes != null && exactMatch.notes!.isNotEmpty
                  ? exactMatch.notes
                  : (notes.isEmpty ? null : notes),
              // Only archive if import says archived (don't un-archive)
              isArchived: exactMatch.isArchived || isArchived,
              updatedAt: DateTime.now(),
            );
            await _judgeRepository.updateJudge(updatedJudge);
            judge = updatedJudge;
            judgeWasUpdated = true;
            judgesUpdated++;
          } else {
            // Create new judge
            final now = DateTime.now();
            judge = Judge(
              id: _uuid.v4(),
              firstName: firstName,
              lastName: lastName,
              contactInfo: contactInfo.isEmpty ? null : contactInfo,
              notes: notes.isEmpty ? null : notes,
              createdAt: now,
              updatedAt: now,
              isArchived: isArchived,
            );
            await _judgeRepository.createJudge(judge);
            judgesCreated++;
            isNewJudge = true;
          }
          
          processedJudges[judgeKey] = judge;
        } else {
          judge = processedJudges[judgeKey]!;
        }
        
        // Assign level if provided
        if (association.isNotEmpty && level.isNotEmpty) {
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
            // Always log when a level isn't found, so user knows to create it
            errors.add('Row ${i + 1}: Judge level "$association $level" not found in system (create it first)');
          }
        }
        
      } catch (e) {
        errors.add('Row ${i + 1}: ${e.toString()}');
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

  /// Create a sample/template CSV file for importing judges
  Future<File> createSampleCsv() async {
    final List<List<String>> csvData = [
      // Header row
      [
        'First Name',
        'Last Name',
        'Contact Info',
        'Notes',
        'Association',
        'Level',
        'Archived',
      ],
      // Sample data rows
      [
        'John',
        'Smith',
        'john.smith@email.com',
        'Available most weekends',
        'USAG',
        'National',
        'false',
      ],
      [
        'Jane',
        'Doe',
        '555-1234',
        '',
        'AAU',
        'Level 3',
        'false',
      ],
      [
        'Mike',
        'Johnson',
        '',
        'Prefers local meets',
        '',
        '',
        'false',
      ],
    ];

    final csvString = const ListToCsvConverter().convert(csvData);
    
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'judges_import_template.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvString);
    
    return file;
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
