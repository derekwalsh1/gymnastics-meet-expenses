import 'dart:io';
import 'dart:convert';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../models/event_session.dart';
import '../models/event_floor.dart';
import '../models/event_day.dart';
import '../models/judge.dart';
import '../models/judge_assignment.dart';
import '../models/judge_fee.dart';
import '../models/expense.dart';
import '../models/meet_import_export_result.dart';
import '../repositories/event_repository.dart';
import '../repositories/event_session_repository.dart';
import '../repositories/event_floor_repository.dart';
import '../repositories/event_day_repository.dart';
import '../repositories/judge_repository.dart';
import '../repositories/judge_assignment_repository.dart';
import '../repositories/judge_fee_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/judge_certification_repository.dart';
import '../models/judge_certification.dart';
import '../services/database_service.dart';

class MeetImportExportService {
  final DatabaseService _dbService = DatabaseService.instance;
  final EventRepository _eventRepository = EventRepository();
  final EventSessionRepository _sessionRepository = EventSessionRepository();
  final EventFloorRepository _floorRepository = EventFloorRepository();
  final EventDayRepository _dayRepository = EventDayRepository();
  final JudgeRepository _judgeRepository = JudgeRepository();
  final JudgeAssignmentRepository _assignmentRepository = JudgeAssignmentRepository();
  final JudgeFeeRepository _feeRepository = JudgeFeeRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
  final JudgeCertificationRepository _certificationRepository = JudgeCertificationRepository();
  final _uuid = const Uuid();

  CancelableOperation<MeetImportResult>? _currentImportOperation;

  /// Cancel the currently running import operation
  void cancelImport() {
    _currentImportOperation?.cancel();
    _currentImportOperation = null;
  }

  /// Export a complete meet with all related data
  Future<MeetExportResult> exportMeet(String eventId) async {
    try {
      // Fetch all meet data
      final event = await _eventRepository.getEventById(eventId);
      if (event == null) {
        return MeetExportResult(
          success: false,
          message: 'Meet not found',
          meetName: 'Unknown',
        );
      }

      final sessions = await _sessionRepository.getEventSessionsByEventId(eventId);
      final days = await _dayRepository.getEventDaysByEventId(eventId);
      final floors = <EventFloor>[];
      final judges = <Judge>[];
      final certifications = <JudgeCertification>[];
      final assignments = <JudgeAssignment>[];
      final fees = <JudgeFee>[];
      final expenses = await _expenseRepository.getExpensesByEventId(eventId);

      // Get all floors for all sessions
      for (final session in sessions) {
        final sessionFloors = await _floorRepository.getEventFloorsBySessionId(session.id);
        floors.addAll(sessionFloors);
      }

      // Get all judge assignments and their judges
      for (final session in sessions) {
        final sessionAssignments = await _assignmentRepository.getAssignmentsBySessionId(session.id);
        assignments.addAll(sessionAssignments);

        for (final assignment in sessionAssignments) {
          final judge = await _judgeRepository.getJudgeById(assignment.judgeId);
          if (judge != null && !judges.any((j) => j.id == judge.id)) {
            judges.add(judge);
            
            // Get certifications for this judge
            final judgeCerts = await _certificationRepository.getCertificationsForJudge(judge.id);
            certifications.addAll(judgeCerts);
          }

          // Get fees for this assignment
          final assignmentFees = await _feeRepository.getFeesByAssignmentId(assignment.id);
          fees.addAll(assignmentFees);
        }
      }

      // Build export structure
      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toUtc().toIso8601String(),
        'exportedBy': 'Gymnastics Meet Expenses v1.0.0+7',
        'meet': event.toJson(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'days': days.map((d) => d.toJson()).toList(),
        'floors': floors.map((f) => f.toJson()).toList(),
        'judges': judges.map((j) => j.toJson()).toList(),
        'certifications': certifications.map((c) => c.toJson()).toList(),
        'assignments': assignments.map((a) => a.toJson()).toList(),
        'fees': fees.map((f) => f.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

      // Save to file
      final exportJson = JsonEncoder.withIndent('  ').convert(exportData);
      // Sanitize filename - remove special characters that aren't valid in filenames
      final sanitizedName = event.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = 'meet_export_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = await _getSaveFilePath(fileName);

      final file = File(filePath);
      // Ensure parent directory exists
      await file.parent.create(recursive: true);
      await file.writeAsString(exportJson);

      return MeetExportResult(
        success: true,
        message: 'Meet exported successfully',
        filePath: filePath,
        meetId: event.id,
        meetName: event.name,
      );
    } catch (e) {
      return MeetExportResult(
        success: false,
        message: 'Export failed: ${e.toString()}',
        meetName: 'Unknown',
      );
    }
  }

  /// Import a meet from JSON file
  Future<MeetImportResult> importMeet(File jsonFile) async {
    try {
      final fileContents = await jsonFile.readAsString();
      final jsonData = jsonDecode(fileContents) as Map<String, dynamic>;

      int sessionsCreated = 0;
      int floorsCreated = 0;
      int daysCreated = 0;
      int judgesCreated = 0;
      int assignmentsCreated = 0;
      int feesCreated = 0;
      int expensesCreated = 0;

      final errors = <String>[];
      final warnings = <String>[];
      final idMap = <String, String>{};

      try {
        // 1. Import meet (event)
        final meetData = jsonData['meet'] as Map<String, dynamic>;
        final oldMeetId = meetData['id'] as String;

        // Create new event (it will generate its own UUID)
        final event = await _eventRepository.createEvent(
          name: meetData['name'] ?? 'Imported Meet',
          startDate: DateTime.parse(meetData['startDate'] ?? DateTime.now().toIso8601String()),
          endDate: DateTime.parse(meetData['endDate'] ?? DateTime.now().toIso8601String()),
          location: EventLocation.fromJson(meetData['location'] ?? {}),
          description: meetData['description'] ?? '',
          totalBudget: (meetData['totalBudget'] as num?)?.toDouble(),
          associationId: meetData['associationId'],
          status: EventStatus.values.firstWhere(
            (status) => status.name == (meetData['status'] ?? 'upcoming'),
            orElse: () => EventStatus.upcoming,
          ),
        );

        // Map old meet ID to the actual created event ID
        final newMeetId = event.id;
        idMap[oldMeetId] = newMeetId;
        

        // 2. Import days
        if (jsonData['days'] is List) {
          for (final dayData in jsonData['days'] as List) {
            try {
              final dayMap = dayData as Map<String, dynamic>;
              final oldDayId = dayMap['id'];

              final createdDay = await _dayRepository.createEventDay(
                eventId: newMeetId,
                dayNumber: dayMap['dayNumber'] ?? 1,
                date: DateTime.parse(dayMap['date'] ?? DateTime.now().toIso8601String()),
                notes: dayMap['notes'],
              );
              
              idMap[oldDayId] = createdDay.id;
              daysCreated++;
            } catch (e, stack) {
              errors.add('Failed to import day: ${e.toString()}');
            }
          }
        }

        // 3. Import sessions
        if (jsonData['sessions'] is List) {
          for (final sessionData in jsonData['sessions'] as List) {
            try {
              final sessionMap = sessionData as Map<String, dynamic>;
              final oldSessionId = sessionMap['id'];
              final oldDayId = sessionMap['eventDayId'];
              final newDayId = idMap[oldDayId] ?? oldDayId;

              final createdSession = await _sessionRepository.createEventSession(
                eventDayId: newDayId,
                sessionNumber: sessionMap['sessionNumber'] ?? 1,
                name: sessionMap['name'] ?? 'Session',
                startTime: _parseTimeOfDay(sessionMap['startTime'] ?? '09:00'),
                endTime: _parseTimeOfDay(sessionMap['endTime'] ?? '17:00'),
                notes: sessionMap['notes'],
              );
              
              idMap[oldSessionId] = createdSession.id;
              sessionsCreated++;
            } catch (e, stack) {
              errors.add('Failed to import session: ${e.toString()}');
            }
          }
        }

        // 4. Import floors
        if (jsonData['floors'] is List) {
          for (final floorData in jsonData['floors'] as List) {
            try {
              final floorMap = floorData as Map<String, dynamic>;
              final oldFloorId = floorMap['id'];
              final oldSessionId = floorMap['eventSessionId'];
              final newSessionId = idMap[oldSessionId] ?? oldSessionId;

              final createdFloor = await _floorRepository.createEventFloor(
                eventSessionId: newSessionId,
                floorNumber: floorMap['floorNumber'] ?? 1,
                name: floorMap['name'] ?? 'Floor',
                notes: floorMap['notes'],
                color: floorMap['color'],
              );
              
              idMap[oldFloorId] = createdFloor.id;
              floorsCreated++;
            } catch (e, stack) {
              errors.add('Failed to import floor: ${e.toString()}');
            }
          }
        }

        // 5. Import judges (check for duplicates by name)
        if (jsonData['judges'] is List) {
          for (final judgeData in jsonData['judges'] as List) {
            try {
              final judgeMap = judgeData as Map<String, dynamic>;
              final oldJudgeId = judgeMap['id'];
              final firstName = judgeMap['firstName'] ?? 'Unknown';
              final lastName = judgeMap['lastName'] ?? 'Judge';

              // Check if judge already exists by name
              final existingJudges = await _judgeRepository.getAllJudges(includeArchived: true);
              final existingJudge = existingJudges.where((j) => 
                j.firstName.toLowerCase() == firstName.toLowerCase() && 
                j.lastName.toLowerCase() == lastName.toLowerCase()
              ).firstOrNull;

              if (existingJudge != null) {
                // Use existing judge
                idMap[oldJudgeId] = existingJudge.id;
                warnings.add('Judge "$firstName $lastName" already exists, using existing record');
              } else {
                // Create new judge
                final newJudgeId = _uuid.v4();
                idMap[oldJudgeId] = newJudgeId;

                final judge = Judge(
                  id: newJudgeId,
                  firstName: firstName,
                  lastName: lastName,
                  contactInfo: judgeMap['contactInfo'],
                  notes: judgeMap['notes'],
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  isArchived: judgeMap['isArchived'] ?? false,
                );

                await _judgeRepository.createJudge(judge);
                judgesCreated++;
              }
            } catch (e) {
              errors.add('Failed to import judge: ${e.toString()}');
            }
          }
        }

        // 5b. Import judge certifications
        if (jsonData['certifications'] is List) {
          for (final certData in jsonData['certifications'] as List) {
            try {
              final certMap = certData as Map<String, dynamic>;
              final oldJudgeId = certMap['judgeId'];
              final newJudgeId = idMap[oldJudgeId];
              
              if (newJudgeId == null) {
                warnings.add('Skipping certification for unknown judge');
                continue;
              }

              // Check if this judge already has this level
              final judgeLevelId = certMap['judgeLevelId'];
              final existingCert = await _certificationRepository.getCertification(newJudgeId, judgeLevelId);
              
              if (existingCert == null) {
                final certification = JudgeCertification(
                  id: _uuid.v4(),
                  judgeId: newJudgeId,
                  judgeLevelId: judgeLevelId,
                  certificationDate: certMap['certificationDate'] != null 
                    ? DateTime.parse(certMap['certificationDate'])
                    : null,
                  expirationDate: certMap['expirationDate'] != null
                    ? DateTime.parse(certMap['expirationDate'])
                    : null,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await _certificationRepository.createCertification(certification);
              }
            } catch (e) {
              warnings.add('Failed to import certification: ${e.toString()}');
            }
          }
        }

        // 6. Import judge assignments
        if (jsonData['assignments'] is List) {
          for (final assignmentData in jsonData['assignments'] as List) {
            try {
              final assignmentMap = assignmentData as Map<String, dynamic>;
              final oldAssignmentId = assignmentMap['id'];
              final oldJudgeId = assignmentMap['judgeId'];
              final oldFloorId = assignmentMap['eventFloorId'];
              
              final newJudgeId = idMap[oldJudgeId];
              final newFloorId = idMap[oldFloorId];
              
              if (newJudgeId == null || newFloorId == null) {
                warnings.add('Skipping assignment due to missing judge or floor mapping');
                continue;
              }

              final newAssignmentId = _uuid.v4();
              final assignment = JudgeAssignment(
                id: newAssignmentId,
                judgeId: newJudgeId,
                eventFloorId: newFloorId,
                apparatus: assignmentMap['apparatus'],
                judgeFirstName: assignmentMap['judgeFirstName'] ?? '',
                judgeLastName: assignmentMap['judgeLastName'] ?? '',
                judgeAssociation: assignmentMap['judgeAssociation'] ?? '',
                judgeLevel: assignmentMap['judgeLevel'] ?? '',
                judgeContactInfo: assignmentMap['judgeContactInfo'],
                role: assignmentMap['role'],
                hourlyRate: (assignmentMap['hourlyRate'] as num?)?.toDouble() ?? 0.0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              // Insert directly to avoid triggering auto-fee creation
              final db = await _dbService.database;
              await db.insert('judge_assignments', assignment.toMap());
              idMap[oldAssignmentId] = newAssignmentId;
              assignmentsCreated++;
            } catch (e) {
              errors.add('Failed to import assignment: ${e.toString()}');
            }
          }
        }

        // 7. Import judge fees
        if (jsonData['fees'] is List) {
          for (final feeData in jsonData['fees'] as List) {
            try {
              final feeMap = feeData as Map<String, dynamic>;
              final oldAssignmentId = feeMap['judgeAssignmentId'];
              final newAssignmentId = idMap[oldAssignmentId];
              
              if (newAssignmentId == null) {
                warnings.add('Skipping fee due to missing assignment mapping');
                continue;
              }

              final fee = JudgeFee(
                id: _uuid.v4(),
                judgeAssignmentId: newAssignmentId,
                feeType: FeeType.values.firstWhere(
                  (type) => type.name == (feeMap['feeType'] ?? 'sessionRate'),
                  orElse: () => FeeType.sessionRate,
                ),
                amount: (feeMap['amount'] as num?)?.toDouble() ?? 0.0,
                hours: (feeMap['hours'] as num?)?.toDouble(),
                description: feeMap['description'] ?? '',
                isAutoCalculated: feeMap['isAutoCalculated'] ?? false,
                isTaxable: feeMap['isTaxable'] ?? true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              // Insert directly 
              final db = await _dbService.database;
              await db.insert('judge_fees', fee.toMap());
              feesCreated++;
            } catch (e) {
              errors.add('Failed to import fee: ${e.toString()}');
            }
          }
        }

        // 8. Import expenses
        if (jsonData['expenses'] is List) {
          for (final expenseData in jsonData['expenses'] as List) {
            try {
              final expenseMap = expenseData as Map<String, dynamic>;
              final oldJudgeId = expenseMap['judgeId'];
              final newJudgeId = oldJudgeId != null ? idMap[oldJudgeId] : null;

              // Parse category from JSON
              final categoryStr = expenseMap['category'] as String?;
              final category = categoryStr != null
                  ? ExpenseCategory.values.firstWhere(
                      (e) => e.name == categoryStr,
                      orElse: () => ExpenseCategory.other,
                    )
                  : ExpenseCategory.other;

              // Parse meal type if present
              final mealTypeStr = expenseMap['mealType'] as String?;
              final mealType = mealTypeStr != null
                  ? MealType.values.firstWhere(
                      (e) => e.name == mealTypeStr,
                      orElse: () => MealType.breakfast,
                    )
                  : null;

              await _expenseRepository.createExpense(
                eventId: newMeetId,
                judgeId: newJudgeId,
                category: category,
                amount: (expenseMap['amount'] as num?)?.toDouble() ?? 0.0,
                date: DateTime.parse(expenseMap['date'] ?? DateTime.now().toIso8601String()),
                description: expenseMap['description'] ?? '',
                distance: (expenseMap['distance'] as num?)?.toDouble(),
                mileageRate: (expenseMap['mileageRate'] as num?)?.toDouble(),
                mealType: mealType,
                perDiemRate: (expenseMap['perDiemRate'] as num?)?.toDouble(),
                transportationType: expenseMap['transportationType'] as String?,
                checkInDate: expenseMap['checkInDate'] != null
                    ? DateTime.parse(expenseMap['checkInDate'])
                    : null,
                checkOutDate: expenseMap['checkOutDate'] != null
                    ? DateTime.parse(expenseMap['checkOutDate'])
                    : null,
                numberOfNights: expenseMap['numberOfNights'] as int?,
                receiptPhotoPath: expenseMap['receiptPhotoPath'] as String?,
                isAutoCalculated: expenseMap['isAutoCalculated'] as bool? ?? false,
              );
              expensesCreated++;
            } catch (e) {
              errors.add('Failed to import expense: ${e.toString()}');
            }
          }
        }

        return MeetImportResult(
          success: true,
          message: 'Meet imported successfully',
          meetId: newMeetId,
          meetName: event.name,
          sessionsCreated: sessionsCreated,
          floorsCreated: floorsCreated,
          daysCreated: daysCreated,
          judgesCreated: judgesCreated,
          assignmentsCreated: assignmentsCreated,
          feesCreated: feesCreated,
          expensesCreated: expensesCreated,
          errors: errors,
          warnings: warnings,
        );
      } catch (e) {
        return MeetImportResult(
          success: false,
          message: 'Import failed: ${e.toString()}',
          errors: [e.toString()],
        );
      }
    } catch (e) {
      return MeetImportResult(
        success: false,
        message: 'Failed to read file: ${e.toString()}',
        errors: [e.toString()],
      );
    }
  }

  /// Helper method to parse TimeOfDay from string (HH:mm format)
  TimeOfDay _parseTimeOfDay(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return const TimeOfDay(hour: 9, minute: 0);
  }

  /// Get the platform-appropriate file save path
  Future<String> _getSaveFilePath(String fileName) async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return '${downloadDir.path}/$fileName';
      }
    }

    // iOS or fallback
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }
}
