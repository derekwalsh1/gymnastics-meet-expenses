import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/judge_assignment.dart';
import '../repositories/judge_assignment_repository.dart';

// Repository provider
final judgeAssignmentRepositoryProvider = Provider((ref) => JudgeAssignmentRepository());

// Assignments by floor
final assignmentsByFloorProvider = FutureProvider.family<List<JudgeAssignment>, String>((ref, floorId) async {
  final repository = ref.watch(judgeAssignmentRepositoryProvider);
  return await repository.getAssignmentsByFloorId(floorId);
});

// Assignments by session
final assignmentsBySessionProvider = FutureProvider.family<List<JudgeAssignment>, String>((ref, sessionId) async {
  final repository = ref.watch(judgeAssignmentRepositoryProvider);
  return await repository.getAssignmentsBySessionId(sessionId);
});

// Assignments by event
final assignmentsByEventProvider = FutureProvider.family<List<JudgeAssignment>, String>((ref, eventId) async {
  final repository = ref.watch(judgeAssignmentRepositoryProvider);
  return await repository.getAssignmentsByEventId(eventId);
});

// Assignments by judge
final assignmentsByJudgeProvider = FutureProvider.family<List<JudgeAssignment>, String>((ref, judgeId) async {
  final repository = ref.watch(judgeAssignmentRepositoryProvider);
  return await repository.getAssignmentsByJudgeId(judgeId);
});

// Available judges for session (not assigned to any floor at that time)
final availableJudgesForSessionProvider = FutureProvider.family<List<String>, String>((ref, sessionId) async {
  final repository = ref.watch(judgeAssignmentRepositoryProvider);
  return await repository.getAvailableJudgeIds(sessionId);
});

// Check conflict for judge assignment
final judgeConflictCheckProvider = FutureProvider.family<bool, ConflictCheckParams>((ref, params) async {
  final repository = ref.watch(judgeAssignmentRepositoryProvider);
  return await repository.hasConflict(
    judgeId: params.judgeId,
    eventSessionId: params.sessionId,
    excludeAssignmentId: params.excludeAssignmentId,
  );
});

class ConflictCheckParams {
  final String judgeId;
  final String sessionId;
  final String? excludeAssignmentId;

  ConflictCheckParams({
    required this.judgeId,
    required this.sessionId,
    this.excludeAssignmentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictCheckParams &&
          runtimeType == other.runtimeType &&
          judgeId == other.judgeId &&
          sessionId == other.sessionId &&
          excludeAssignmentId == other.excludeAssignmentId;

  @override
  int get hashCode => judgeId.hashCode ^ sessionId.hashCode ^ (excludeAssignmentId?.hashCode ?? 0);
}
