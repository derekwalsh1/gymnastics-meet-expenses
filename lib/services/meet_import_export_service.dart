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

class MeetImportExportService {
  final EventRepository _eventRepository = EventRepository();
  final EventSessionRepository _sessionRepository = EventSessionRepository();
  final EventFloorRepository _floorRepository = EventFloorRepository();
  final EventDayRepository _dayRepository = EventDayRepository();
  final JudgeRepository _judgeRepository = JudgeRepository();
  final JudgeAssignmentRepository _assignmentRepository = JudgeAssignmentRepository();
  final JudgeFeeRepository _feeRepository = JudgeFeeRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();
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
        'assignments': assignments.map((a) => a.toJson()).toList(),
        'fees': fees.map((f) => f.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

      // Save to file
      final exportJson = JsonEncoder.withIndent('  ').convert(exportData);
      final fileName = 'meet_export_${event.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = await _getSaveFilePath(fileName);

      final file = File(filePath);
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
        final newMeetId = _uuid.v4();
        idMap[oldMeetId] = newMeetId;

        // Create new event
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

        // 2. Import days
        if (jsonData['days'] is List) {
          for (final dayData in jsonData['days'] as List) {
            try {
              final dayMap = dayData as Map<String, dynamic>;
              final oldDayId = dayMap['id'];
              final newDayId = _uuid.v4();
              idMap[oldDayId] = newDayId;

              await _dayRepository.createEventDay(
                eventId: newMeetId,
                dayNumber: dayMap['dayNumber'] ?? 1,
                date: DateTime.parse(dayMap['date'] ?? DateTime.now().toIso8601String()),
                notes: dayMap['notes'],
              );
              daysCreated++;
            } catch (e) {
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
              final newSessionId = _uuid.v4();
              idMap[oldSessionId] = newSessionId;

              final oldDayId = sessionMap['eventDayId'];
              final newDayId = idMap[oldDayId] ?? oldDayId;

              await _sessionRepository.createEventSession(
                eventDayId: newDayId,
                sessionNumber: sessionMap['sessionNumber'] ?? 1,
                name: sessionMap['name'] ?? 'Session',
                startTime: _parseTimeOfDay(sessionMap['startTime'] ?? '09:00'),
                endTime: _parseTimeOfDay(sessionMap['endTime'] ?? '17:00'),
                notes: sessionMap['notes'],
              );
              sessionsCreated++;
            } catch (e) {
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
              final newFloorId = _uuid.v4();
              idMap[oldFloorId] = newFloorId;
              final oldSessionId = floorMap['eventSessionId'];
              final newSessionId = idMap[oldSessionId] ?? oldSessionId;

              await _floorRepository.createEventFloor(
                eventSessionId: newSessionId,
                floorNumber: floorMap['floorNumber'] ?? 1,
                name: floorMap['name'] ?? 'Floor',
                notes: floorMap['notes'],
              );
              floorsCreated++;
            } catch (e) {
              errors.add('Failed to import floor: ${e.toString()}');
            }
          }
        }

        // 5. Import judges
        if (jsonData['judges'] is List) {
          for (final judgeData in jsonData['judges'] as List) {
            try {
              final judgeMap = judgeData as Map<String, dynamic>;
              final oldJudgeId = judgeMap['id'];
              final newJudgeId = _uuid.v4();
              idMap[oldJudgeId] = newJudgeId;

              final judge = Judge(
                id: newJudgeId,
                firstName: judgeMap['firstName'] ?? 'Unknown',
                lastName: judgeMap['lastName'] ?? 'Judge',
                contactInfo: judgeMap['contactInfo'],
                notes: judgeMap['notes'],
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                isArchived: judgeMap['isArchived'] ?? false,
              );

              await _judgeRepository.createJudge(judge);
              judgesCreated++;
            } catch (e) {
              errors.add('Failed to import judge: ${e.toString()}');
            }
          }
        }

        // 6. Import expenses (simpler than assignments)
        if (jsonData['expenses'] is List) {
          for (final expenseData in jsonData['expenses'] as List) {
            try {
              final expenseMap = expenseData as Map<String, dynamic>;
              final oldJudgeId = expenseMap['judgeId'];
              final newJudgeId = oldJudgeId != null ? idMap[oldJudgeId] : null;

              await _expenseRepository.createExpense(
                eventId: newMeetId,
                judgeId: newJudgeId,
                category: ExpenseCategory.other,
                amount: (expenseMap['amount'] as num?)?.toDouble() ?? 0.0,
                date: DateTime.parse(expenseMap['date'] ?? DateTime.now().toIso8601String()),
                description: expenseMap['description'] ?? '',
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
