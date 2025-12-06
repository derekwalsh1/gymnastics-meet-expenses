import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/judge.dart';
import '../models/judge_with_level.dart';
import '../repositories/judge_repository.dart';

// Repository provider
final judgeRepositoryProvider = Provider<JudgeRepository>((ref) {
  return JudgeRepository();
});

// Judges with level details provider (v3: returns JudgeWithLevels)
final judgesWithLevelsProvider = FutureProvider<List<JudgeWithLevels>>((ref) async {
  final repository = ref.watch(judgeRepositoryProvider);
  return repository.getJudgesWithLevels();
});

// Filtered judges with levels provider (v3: returns JudgeWithLevels with filters)
final filteredJudgesWithLevelsProvider = FutureProvider<List<JudgeWithLevels>>((ref) async {
  final repository = ref.watch(judgeRepositoryProvider);
  final searchQuery = ref.watch(judgeSearchQueryProvider);
  final associationFilter = ref.watch(judgeAssociationFilterProvider);
  final levelFilter = ref.watch(judgeLevelFilterProvider);

  final allJudges = await repository.getJudgesWithLevels();

  // Apply filters in order: association, level, then search
  var filtered = allJudges;

  // Filter by association
  if (associationFilter != null) {
    filtered = filtered.where((j) => j.hasCertificationIn(associationFilter)).toList();
  }

  // Filter by specific level
  if (levelFilter != null) {
    filtered = filtered.where((j) => j.levels.any((l) => l.id == levelFilter)).toList();
  }

  // Apply search query
  if (searchQuery.isNotEmpty) {
    final query = searchQuery.toLowerCase();
    filtered = filtered.where((j) {
      return j.judge.firstName.toLowerCase().contains(query) ||
             j.judge.lastName.toLowerCase().contains(query) ||
             j.associations.any((assoc) => assoc.toLowerCase().contains(query)) ||
             j.levels.any((level) => level.level.toLowerCase().contains(query));
    }).toList();
  }

  return filtered;
});

// Judges list provider
final judgesProvider = FutureProvider<List<Judge>>((ref) async {
  final repository = ref.watch(judgeRepositoryProvider);
  return repository.getAllJudges();
});

// Search query provider
final judgeSearchQueryProvider = StateProvider<String>((ref) => '');

// Association filter provider
final judgeAssociationFilterProvider = StateProvider<String?>((ref) => null);

// Level filter provider
final judgeLevelFilterProvider = StateProvider<String?>((ref) => null);

// Filtered judges provider
final filteredJudgesProvider = FutureProvider<List<Judge>>((ref) async {
  final repository = ref.watch(judgeRepositoryProvider);
  final searchQuery = ref.watch(judgeSearchQueryProvider);
  final associationFilter = ref.watch(judgeAssociationFilterProvider);
  final levelFilter = ref.watch(judgeLevelFilterProvider);

  // If there's a search query, use search
  if (searchQuery.isNotEmpty) {
    return repository.searchJudges(searchQuery);
  }

  // Apply filters
  if (associationFilter != null) {
    return repository.getJudgesByAssociation(associationFilter);
  }

  if (levelFilter != null) {
    return repository.getJudgesByLevel(levelFilter);
  }

  // Default: return all judges
  return repository.getAllJudges();
});

// Associations provider
final associationsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(judgeRepositoryProvider);
  return repository.getAssociations();
});

// Levels provider
final levelsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(judgeRepositoryProvider);
  return repository.getLevels();
});

// Judge notifier for CRUD operations
class JudgeNotifier extends StateNotifier<AsyncValue<List<Judge>>> {
  final JudgeRepository _repository;

  JudgeNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadJudges();
  }

  Future<void> loadJudges() async {
    state = const AsyncValue.loading();
    try {
      final judges = await _repository.getAllJudges();
      state = AsyncValue.data(judges);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addJudge({
    required String firstName,
    required String lastName,
    String? notes,
    String? contactInfo,
  }) async {
    try {
      final now = DateTime.now();
      final judge = Judge(
        id: const Uuid().v4(),
        firstName: firstName,
        lastName: lastName,
        notes: notes,
        contactInfo: contactInfo,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.createJudge(judge);
      await loadJudges();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateJudge(Judge judge) async {
    try {
      final updatedJudge = judge.copyWith(updatedAt: DateTime.now());
      await _repository.updateJudge(updatedJudge);
      await loadJudges();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteJudge(String id) async {
    try {
      await _repository.deleteJudge(id);
      await loadJudges();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> archiveJudge(String id) async {
    try {
      await _repository.archiveJudge(id);
      await loadJudges();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// Judge notifier provider
final judgeNotifierProvider =
    StateNotifierProvider<JudgeNotifier, AsyncValue<List<Judge>>>((ref) {
  final repository = ref.watch(judgeRepositoryProvider);
  return JudgeNotifier(repository);
});
