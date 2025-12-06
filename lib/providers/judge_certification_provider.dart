import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/judge_certification.dart';
import '../repositories/judge_certification_repository.dart';

// Repository provider
final judgeCertificationRepositoryProvider = Provider<JudgeCertificationRepository>((ref) {
  return JudgeCertificationRepository();
});

// Certifications for a specific judge provider
final judgeCertificationsProvider = FutureProvider.family<List<JudgeCertification>, String>(
  (ref, judgeId) async {
    final repository = ref.watch(judgeCertificationRepositoryProvider);
    return repository.getCertificationsForJudge(judgeId);
  },
);

// Certification notifier for CRUD operations
class JudgeCertificationNotifier extends StateNotifier<AsyncValue<List<JudgeCertification>>> {
  final JudgeCertificationRepository _repository;
  final String? _judgeId;

  JudgeCertificationNotifier(this._repository, this._judgeId) : super(const AsyncValue.loading()) {
    if (_judgeId != null) {
      loadCertifications(_judgeId!);
    }
  }

  Future<void> loadCertifications(String judgeId) async {
    state = const AsyncValue.loading();
    try {
      final certifications = await _repository.getCertificationsForJudge(judgeId);
      state = AsyncValue.data(certifications);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addCertification({
    required String judgeId,
    required String judgeLevelId,
    DateTime? certificationDate,
    DateTime? expirationDate,
  }) async {
    try {
      final now = DateTime.now();
      final certification = JudgeCertification(
        id: const Uuid().v4(),
        judgeId: judgeId,
        judgeLevelId: judgeLevelId,
        certificationDate: certificationDate,
        expirationDate: expirationDate,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.createCertification(certification);
      await loadCertifications(judgeId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> removeCertification({
    required String judgeId,
    required String judgeLevelId,
  }) async {
    try {
      await _repository.deleteCertification(judgeId, judgeLevelId);
      await loadCertifications(judgeId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateCertification(JudgeCertification certification) async {
    try {
      final updated = certification.copyWith(updatedAt: DateTime.now());
      await _repository.updateCertification(updated);
      await loadCertifications(certification.judgeId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// Certification notifier provider
final judgeCertificationNotifierProvider = StateNotifierProvider.family<
    JudgeCertificationNotifier,
    AsyncValue<List<JudgeCertification>>,
    String?>((ref, judgeId) {
  final repository = ref.watch(judgeCertificationRepositoryProvider);
  return JudgeCertificationNotifier(repository, judgeId);
});
