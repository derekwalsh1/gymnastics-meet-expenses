import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/judge_provider.dart';
import '../../providers/judge_level_provider.dart';
import '../../models/judge.dart';
import '../../models/judge_level.dart';
import '../../models/judge_with_level.dart';
import 'add_edit_judge_screen.dart';

class JudgesListScreen extends ConsumerStatefulWidget {
  const JudgesListScreen({super.key});

  @override
  ConsumerState<JudgesListScreen> createState() => _JudgesListScreenState();
}

class _JudgesListScreenState extends ConsumerState<JudgesListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final judgesAsync = ref.watch(filteredJudgesWithLevelsProvider);
    final searchQuery = ref.watch(judgeSearchQueryProvider);
    final associationFilter = ref.watch(judgeAssociationFilterProvider);
    final levelFilter = ref.watch(judgeLevelFilterProvider);
    final hasActiveFilter = associationFilter != null || levelFilter != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Judges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Manage Judge Levels',
            onPressed: () {
              context.push('/associations');
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterDialog(context),
              ),
              if (hasActiveFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import/Export Judges',
            onPressed: () {
              context.push('/judges/import-export');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search judges...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(judgeSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                ref.read(judgeSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          // Judges list
          Expanded(
            child: judgesAsync.when(
              data: (judges) {
                if (judges.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No judges found'
                              : 'No judges yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Try a different search'
                              : 'Tap + to add your first judge',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: judges.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final judgeWithLevel = judges[index];
                    return _JudgeCard(
                      judgeWithLevel: judgeWithLevel,
                      onTap: () => _navigateToEditJudge(context, judgeWithLevel.judge),
                      onDelete: () => _confirmDeleteJudge(context, judgeWithLevel.judge),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading judges: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(filteredJudgesWithLevelsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddJudge(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddJudge(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEditJudgeScreen(),
      ),
    );
  }

  void _navigateToEditJudge(BuildContext context, Judge judge) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditJudgeScreen(judge: judge),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final judgeLevelsAsync = ref.read(judgeLevelsProvider);
    
    judgeLevelsAsync.whenData((allLevels) {
      // Get unique associations
      final associations = allLevels.map((l) => l.association).toSet().toList()..sort();
      
      // Group levels by association
      final levelsByAssoc = <String, List<JudgeLevel>>{};
      for (final level in allLevels) {
        levelsByAssoc.putIfAbsent(level.association, () => []).add(level);
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Filter Judges'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('All Judges'),
                  onTap: () {
                    ref.read(judgeAssociationFilterProvider.notifier).state = null;
                    ref.read(judgeLevelFilterProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'By Association',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...associations.map((assoc) => ListTile(
                  leading: _AssociationBadge(association: assoc),
                  title: Text(assoc),
                  onTap: () {
                    ref.read(judgeAssociationFilterProvider.notifier).state = assoc;
                    ref.read(judgeLevelFilterProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                )),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'By Specific Level',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...levelsByAssoc.entries.expand((entry) => [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...entry.value.map((level) => ListTile(
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    title: Text(level.level),
                    subtitle: Text('\$${level.defaultHourlyRate.toStringAsFixed(2)}/hr'),
                    onTap: () {
                      ref.read(judgeAssociationFilterProvider.notifier).state = null;
                      ref.read(judgeLevelFilterProvider.notifier).state = level.id;
                      Navigator.pop(context);
                    },
                  )),
                ]),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _confirmDeleteJudge(BuildContext context, Judge judge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Judge'),
        content: Text(
          'Are you sure you want to delete ${judge.fullName}? This action cannot be undone.',
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
                await ref.read(judgeNotifierProvider.notifier).deleteJudge(judge.id);
                // Refresh the judges list
                ref.invalidate(judgesWithLevelsProvider);
                ref.invalidate(filteredJudgesWithLevelsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('${judge.fullName} deleted'),
                        duration: const Duration(milliseconds: 500),
                      ),
                    );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting judge: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _JudgeCard extends StatelessWidget {
  final JudgeWithLevels judgeWithLevel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _JudgeCard({
    required this.judgeWithLevel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final judge = judgeWithLevel.judge;
    final hasCerts = judgeWithLevel.levels.isNotEmpty;
    final associations = judgeWithLevel.associations;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            judge.firstName[0] + judge.lastName[0],
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          judge.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (associations.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: associations.map((assoc) => _AssociationBadge(association: assoc)).toList(),
              ),
            ],
            if (hasCerts) ...[
              const SizedBox(height: 4),
              Text(
                judgeWithLevel.certificationsDisplay,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${judgeWithLevel.levels.length} certification${judgeWithLevel.levels.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ] else
              const Text(
                'No certifications',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        isThreeLine: hasCerts,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _AssociationBadge extends StatelessWidget {
  final String association;

  const _AssociationBadge({required this.association});

  Color _getColorForAssociation(String assoc) {
    // Assign colors based on association
    switch (assoc.toUpperCase()) {
      case 'NAWGJ':
        return Colors.green;
      case 'NGA':
        return Colors.blue;
      case 'AAU':
        return Colors.orange;
      case 'USAG':
        return Colors.purple;
      default:
        // Generate a consistent color based on hash
        final hash = assoc.hashCode;
        final colors = [
          Colors.teal,
          Colors.indigo,
          Colors.pink,
          Colors.amber,
          Colors.cyan,
          Colors.deepOrange,
        ];
        return colors[hash.abs() % colors.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForAssociation(association);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        association,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
