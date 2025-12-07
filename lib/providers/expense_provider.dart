import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';

// Repository provider
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

// Expenses for a specific event
final expensesByEventProvider = FutureProvider.family<List<Expense>, String>((ref, eventId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesByEventId(eventId);
});

// Expenses for a specific judge
final expensesByJudgeProvider = FutureProvider.family<List<Expense>, String>((ref, judgeId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesByJudgeId(judgeId);
});

// Expenses for a specific assignment
final expensesByAssignmentProvider = FutureProvider.family<List<Expense>, String>((ref, assignmentId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesByAssignmentId(assignmentId);
});

// Expenses for a judge in an event
final expensesByJudgeAndEventProvider = FutureProvider.family<List<Expense>, ({String judgeId, String eventId})>((ref, params) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpensesByJudgeAndEvent(
    judgeId: params.judgeId,
    eventId: params.eventId,
  );
});

// Total expenses for an event
final totalExpensesByEventProvider = FutureProvider.family<double, String>((ref, eventId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getTotalExpensesByEvent(eventId);
});

// Total expenses for a judge
final totalExpensesByJudgeProvider = FutureProvider.family<double, String>((ref, judgeId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getTotalExpensesByJudge(judgeId);
});

// Total expenses for an assignment
final totalExpensesByAssignmentProvider = FutureProvider.family<double, String>((ref, assignmentId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getTotalExpensesByAssignment(assignmentId);
});

// Total expenses for a judge in an event
final totalExpensesByJudgeAndEventProvider = FutureProvider.family<double, ({String judgeId, String eventId})>((ref, params) async {
  final repository = ref.watch(expenseRepositoryProvider);
  final expenses = await repository.getExpensesByJudgeAndEvent(
    judgeId: params.judgeId,
    eventId: params.eventId,
  );
  return expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
});

// Expense breakdown by category for an event
final expenseBreakdownByEventProvider = FutureProvider.family<Map<ExpenseCategory, double>, String>((ref, eventId) async {
  final repository = ref.watch(expenseRepositoryProvider);
  return repository.getExpenseBreakdownByEvent(eventId);
});
