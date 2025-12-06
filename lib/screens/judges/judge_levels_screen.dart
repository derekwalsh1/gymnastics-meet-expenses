import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/judge_level.dart';
import '../../providers/judge_level_provider.dart';

class JudgeLevelsScreen extends ConsumerWidget {
  final String association;
  
  const JudgeLevelsScreen({
    super.key,
    required this.association,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final judgeLevelsAsync = ref.watch(judgeLevelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$association Levels'),
      ),
      body: judgeLevelsAsync.when(
        data: (allLevels) {
          final levels = allLevels
              .where((l) => l.association == association)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          if (levels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No levels found for $association'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push('/judge-levels/$association/add');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Level'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: levels.length,
            itemBuilder: (context, index) {
              return _JudgeLevelCard(level: levels[index], association: association);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading judge levels: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/judge-levels/$association/add');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _JudgeLevelCard extends ConsumerWidget {
  final JudgeLevel level;
  final String association;

  const _JudgeLevelCard({
    required this.level,
    required this.association,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          level.level,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '\$${level.defaultHourlyRate.toStringAsFixed(2)}/hr',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push('/judge-levels/$association/edit/${level.id}');
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Judge Level'),
        content: Text(
          'Are you sure you want to delete ${level.displayName}?\n\n'
          'This will affect any judges currently using this level.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(judgeLevelNotifierProvider.notifier).deleteJudgeLevel(level.id);
                ref.invalidate(judgeLevelsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${level.displayName} deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting level: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
