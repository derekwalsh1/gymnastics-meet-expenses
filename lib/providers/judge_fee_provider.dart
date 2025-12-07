import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/judge_fee.dart';
import '../repositories/judge_fee_repository.dart';

// Repository provider
final judgeFeeRepositoryProvider = Provider<JudgeFeeRepository>((ref) {
  return JudgeFeeRepository();
});

// Fees for a specific assignment
final feesByAssignmentProvider = FutureProvider.family<List<JudgeFee>, String>((ref, assignmentId) async {
  final repository = ref.watch(judgeFeeRepositoryProvider);
  return repository.getFeesByAssignmentId(assignmentId);
});

// Total fees for an assignment
final totalFeesByAssignmentProvider = FutureProvider.family<double, String>((ref, assignmentId) async {
  final repository = ref.watch(judgeFeeRepositoryProvider);
  return repository.getTotalFeesForAssignment(assignmentId);
});

// Total taxable fees for an assignment
final totalTaxableFeesByAssignmentProvider = FutureProvider.family<double, String>((ref, assignmentId) async {
  final repository = ref.watch(judgeFeeRepositoryProvider);
  return repository.getTotalTaxableFeesForAssignment(assignmentId);
});

// Fees for a judge in a specific event
final feesForJudgeInEventProvider = FutureProvider.family<List<JudgeFee>, ({String judgeId, String eventId})>((ref, params) async {
  final repository = ref.watch(judgeFeeRepositoryProvider);
  return repository.getFeesForJudgeInEvent(judgeId: params.judgeId, eventId: params.eventId);
});

// Total fees for a floor
final totalFeesForFloorProvider = FutureProvider.family<double, String>((ref, floorId) async {
  final repository = ref.watch(judgeFeeRepositoryProvider);
  return repository.getTotalFeesForFloor(floorId);
});

// Total fees for a session
final totalFeesForSessionProvider = FutureProvider.family<double, String>((ref, sessionId) async {
  final repository = ref.watch(judgeFeeRepositoryProvider);
  return repository.getTotalFeesForSession(sessionId);
});

// Total fees for a day
final totalFeesForDayProvider = FutureProvider.family<double, String>((ref, dayId) async {
  final repository = ref.watch(judgeFeeRepositoryProvider);
  return repository.getTotalFeesForDay(dayId);
});
