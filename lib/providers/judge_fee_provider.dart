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
  return repository.getFeesForJudgeInEvent(params.judgeId, params.eventId);
});
