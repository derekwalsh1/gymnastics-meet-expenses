import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/judge_level.dart';
import '../repositories/judge_level_repository.dart';

// Repository provider
final judgeLevelRepositoryProvider = Provider<JudgeLevelRepository>((ref) {
  return JudgeLevelRepository();
});

// Judge levels list provider
final judgeLevelsProvider = FutureProvider<List<JudgeLevel>>((ref) async {
  final repository = ref.watch(judgeLevelRepositoryProvider);
  return repository.getAllJudgeLevels();
});

// Associations provider
final judgeAssociationsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(judgeLevelRepositoryProvider);
  return repository.getAssociations();
});

// Levels by association provider
final levelsByAssociationProvider = FutureProvider.family<List<JudgeLevel>, String>(
  (ref, association) async {
    final repository = ref.watch(judgeLevelRepositoryProvider);
    return repository.getLevelsByAssociation(association);
  },
);

// Judge level notifier for CRUD operations
class JudgeLevelNotifier extends StateNotifier<AsyncValue<List<JudgeLevel>>> {
  final JudgeLevelRepository _repository;

  JudgeLevelNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadJudgeLevels();
  }

  Future<void> loadJudgeLevels() async {
    state = const AsyncValue.loading();
    try {
      final levels = await _repository.getAllJudgeLevels();
      state = AsyncValue.data(levels);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addJudgeLevel({
    required String association,
    required String level,
    required double defaultHourlyRate,
    required int sortOrder,
  }) async {
    try {
      final now = DateTime.now();
      final judgeLevel = JudgeLevel(
        id: const Uuid().v4(),
        association: association,
        level: level,
        defaultHourlyRate: defaultHourlyRate,
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.createJudgeLevel(judgeLevel);
      await loadJudgeLevels();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateJudgeLevel(JudgeLevel level) async {
    try {
      final updatedLevel = level.copyWith(updatedAt: DateTime.now());
      await _repository.updateJudgeLevel(updatedLevel);
      await loadJudgeLevels();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<bool> deleteJudgeLevel(String id) async {
    try {
      // Check if level is in use
      final isInUse = await _repository.isLevelInUse(id);
      if (isInUse) {
        return false; // Cannot delete, in use
      }
      
      await _repository.deleteJudgeLevel(id);
      await loadJudgeLevels();
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<JudgeLevel?> getJudgeLevel(String id) async {
    try {
      return await _repository.getJudgeLevelById(id);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> archiveJudgeLevel(String id) async {
    try {
      await _repository.archiveJudgeLevel(id);
      await loadJudgeLevels();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// Judge level notifier provider
final judgeLevelNotifierProvider =
    StateNotifierProvider<JudgeLevelNotifier, AsyncValue<List<JudgeLevel>>>((ref) {
  final repository = ref.watch(judgeLevelRepositoryProvider);
  return JudgeLevelNotifier(repository);
});
