import 'package:uuid/uuid.dart';
import '../models/event_report.dart';
import '../models/event.dart';
import '../models/judge_assignment.dart';
import '../models/judge_fee.dart';
import '../models/expense.dart';
import '../models/event_day.dart';
import '../models/event_session.dart';
import '../models/event_floor.dart';
import 'event_repository.dart';
import 'judge_assignment_repository.dart';
import 'judge_fee_repository.dart';
import 'expense_repository.dart';
import 'event_day_repository.dart';
import 'event_session_repository.dart';
import 'event_floor_repository.dart';

class ReportRepository {
  final EventRepository _eventRepo = EventRepository();
  final JudgeAssignmentRepository _assignmentRepo = JudgeAssignmentRepository();
  final JudgeFeeRepository _feeRepo = JudgeFeeRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final EventDayRepository _dayRepo = EventDayRepository();
  final EventSessionRepository _sessionRepo = EventSessionRepository();
  final EventFloorRepository _floorRepo = EventFloorRepository();
  final _uuid = const Uuid();

  /// Generate a comprehensive financial report for an event
  Future<EventReport> generateEventReport(String eventId) async {
    final event = await _eventRepo.getEventById(eventId);
    if (event == null) {
      throw Exception('Event not found');
    }

    // Get all assignments for this event
    final assignments = await _assignmentRepo.getAssignmentsByEventId(eventId);
    
    // Build judge breakdowns
    final judgeBreakdowns = <String, JudgeFinancialSummary>{};
    
    for (final assignment in assignments) {
      if (!judgeBreakdowns.containsKey(assignment.judgeId)) {
        // Get all fees for this judge in this event
        final allAssignmentsForJudge = assignments.where(
          (a) => a.judgeId == assignment.judgeId
        ).toList();
        
        double totalFees = 0.0;
        final feesBySession = <String, double>{};
        
        for (final judgeAssignment in allAssignmentsForJudge) {
          final fees = await _feeRepo.getFeesByAssignmentId(judgeAssignment.id);
          final assignmentTotal = fees.fold<double>(0.0, (sum, fee) => sum + fee.amount);
          totalFees += assignmentTotal;
          feesBySession[judgeAssignment.id] = assignmentTotal;
        }
        
        // Get all expenses for this judge in this event
        final expenses = await _expenseRepo.getExpensesByJudgeAndEvent(
          judgeId: assignment.judgeId,
          eventId: eventId,
        );
        
        final totalExpenses = expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);
        
        final expensesByCategory = <String, double>{};
        for (final expense in expenses) {
          final categoryName = expense.category.name;
          expensesByCategory[categoryName] = 
            (expensesByCategory[categoryName] ?? 0.0) + expense.amount;
        }
        
        judgeBreakdowns[assignment.judgeId] = JudgeFinancialSummary(
          judgeId: assignment.judgeId,
          judgeName: assignment.judgeFullName,
          totalFees: totalFees,
          totalExpenses: totalExpenses,
          netTotal: totalFees - totalExpenses,
          feesBySession: feesBySession,
          expensesByCategory: expensesByCategory,
        );
      }
    }
    
    // Calculate overall totals
    final totalFees = judgeBreakdowns.values.fold<double>(
      0.0, (sum, summary) => sum + summary.totalFees
    );
    final totalExpenses = judgeBreakdowns.values.fold<double>(
      0.0, (sum, summary) => sum + summary.totalExpenses
    );
    
    // Get expense breakdown by category for the whole event
    final expensesByCategory = <String, double>{};
    final allExpenses = await _expenseRepo.getExpensesByEventId(eventId);
    for (final expense in allExpenses) {
      final categoryName = expense.category.name;
      expensesByCategory[categoryName] = 
        (expensesByCategory[categoryName] ?? 0.0) + expense.amount;
    }

    return EventReport(
      id: _uuid.v4(),
      reportType: ReportType.event,
      eventId: eventId,
      eventName: event.name,
      startDate: event.startDate,
      endDate: event.endDate,
      generatedAt: DateTime.now(),
      judgeBreakdowns: judgeBreakdowns,
      expensesByCategory: expensesByCategory,
      totalFees: totalFees,
      totalExpenses: totalExpenses,
      netTotal: totalFees - totalExpenses,
    );
  }

  /// Generate a report for a specific judge across a date range
  Future<EventReport> generateJudgeReport({
    required String judgeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Get all assignments for this judge in the date range
    final allAssignments = await _assignmentRepo.getAssignmentsByJudgeId(judgeId);
    
    // Filter assignments by date range (need to check event dates)
    final relevantAssignments = <JudgeAssignment>[];
    final relevantEvents = <Event>[];
    
    for (final assignment in allAssignments) {
      // Get event to check dates - navigate through hierarchy
      final floor = await _floorRepo.getEventFloorById(assignment.eventFloorId);
      if (floor != null) {
        final session = await _sessionRepo.getEventSessionById(floor.eventSessionId);
        if (session != null) {
          final day = await _dayRepo.getEventDayById(session.eventDayId);
          if (day != null) {
            final event = await _eventRepo.getEventById(day.eventId);
            if (event != null && 
                event.startDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
                event.endDate.isBefore(endDate.add(const Duration(days: 1)))) {
              relevantAssignments.add(assignment);
              if (!relevantEvents.any((e) => e.id == event.id)) {
                relevantEvents.add(event);
              }
            }
          }
        }
      }
    }

    // Calculate totals
    double totalFees = 0.0;
    double totalExpenses = 0.0;
    final feesBySession = <String, double>{};
    final expensesByCategory = <String, double>{};
    
    for (final assignment in relevantAssignments) {
      final fees = await _feeRepo.getFeesByAssignmentId(assignment.id);
      final assignmentTotal = fees.fold<double>(0.0, (sum, fee) => sum + fee.amount);
      totalFees += assignmentTotal;
      feesBySession[assignment.id] = assignmentTotal;
    }
    
    // Get expenses for this judge in the date range
    final expenses = await _expenseRepo.getExpensesByDateRange(
      startDate: startDate,
      endDate: endDate,
      judgeId: judgeId,
    );
    
    totalExpenses = expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);
    
    for (final expense in expenses) {
      final categoryName = expense.category.name;
      expensesByCategory[categoryName] = 
        (expensesByCategory[categoryName] ?? 0.0) + expense.amount;
    }
    
    // Get judge name from first assignment
    final judgeName = relevantAssignments.isNotEmpty 
      ? relevantAssignments.first.judgeFullName
      : 'Unknown Judge';
    
    final judgeBreakdowns = <String, JudgeFinancialSummary>{
      judgeId: JudgeFinancialSummary(
        judgeId: judgeId,
        judgeName: judgeName,
        totalFees: totalFees,
        totalExpenses: totalExpenses,
        netTotal: totalFees - totalExpenses,
        feesBySession: feesBySession,
        expensesByCategory: expensesByCategory,
      ),
    };

    return EventReport(
      id: _uuid.v4(),
      reportType: ReportType.judge,
      judgeId: judgeId,
      judgeName: judgeName,
      startDate: startDate,
      endDate: endDate,
      generatedAt: DateTime.now(),
      judgeBreakdowns: judgeBreakdowns,
      expensesByCategory: expensesByCategory,
      totalFees: totalFees,
      totalExpenses: totalExpenses,
      netTotal: totalFees - totalExpenses,
    );
  }

  /// Get a quick financial summary for an event
  Future<FinancialSummary> getEventFinancialSummary(String eventId) async {
    final event = await _eventRepo.getEventById(eventId);
    if (event == null) {
      throw Exception('Event not found');
    }

    final assignments = await _assignmentRepo.getAssignmentsByEventId(eventId);
    final uniqueJudges = assignments.map((a) => a.judgeId).toSet();
    
    // Calculate total fees
    double totalFees = 0.0;
    for (final assignment in assignments) {
      final fees = await _feeRepo.getFeesByAssignmentId(assignment.id);
      totalFees += fees.fold<double>(0.0, (sum, fee) => sum + fee.amount);
    }
    
    // Calculate total expenses
    final expenses = await _expenseRepo.getExpensesByEventId(eventId);
    final totalExpenses = expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);
    
    // Expense breakdown
    final expenseBreakdown = <String, double>{};
    for (final expense in expenses) {
      final categoryName = expense.category.name;
      expenseBreakdown[categoryName] = 
        (expenseBreakdown[categoryName] ?? 0.0) + expense.amount;
    }

    return FinancialSummary(
      eventId: eventId,
      eventName: event.name,
      startDate: event.startDate,
      endDate: event.endDate,
      totalFees: totalFees,
      totalExpenses: totalExpenses,
      netProfit: totalFees - totalExpenses,
      numberOfJudges: uniqueJudges.length,
      expenseBreakdown: expenseBreakdown,
    );
  }

  /// Get earnings breakdown for a specific judge at a specific event
  Future<JudgeFinancialSummary> getJudgeEarningsBreakdown({
    required String judgeId,
    required String eventId,
  }) async {
    final assignments = await _assignmentRepo.getAssignmentsByEventId(eventId);
    final judgeAssignments = assignments.where((a) => a.judgeId == judgeId).toList();
    
    if (judgeAssignments.isEmpty) {
      throw Exception('Judge not assigned to this event');
    }
    
    double totalFees = 0.0;
    final feesBySession = <String, double>{};
    
    for (final assignment in judgeAssignments) {
      final fees = await _feeRepo.getFeesByAssignmentId(assignment.id);
      final assignmentTotal = fees.fold<double>(0.0, (sum, fee) => sum + fee.amount);
      totalFees += assignmentTotal;
      feesBySession[assignment.id] = assignmentTotal;
    }
    
    // Get expenses
    final expenses = await _expenseRepo.getExpensesByJudgeAndEvent(
      judgeId: judgeId,
      eventId: eventId,
    );
    
    final totalExpenses = expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);
    
    final expensesByCategory = <String, double>{};
    for (final expense in expenses) {
      final categoryName = expense.category.name;
      expensesByCategory[categoryName] = 
        (expensesByCategory[categoryName] ?? 0.0) + expense.amount;
    }
    
    return JudgeFinancialSummary(
      judgeId: judgeId,
      judgeName: judgeAssignments.first.judgeFullName,
      totalFees: totalFees,
      totalExpenses: totalExpenses,
      netTotal: totalFees - totalExpenses,
      feesBySession: feesBySession,
      expensesByCategory: expensesByCategory,
    );
  }
}
