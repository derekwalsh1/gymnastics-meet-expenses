import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/judge_level_provider.dart';

class AssociationsScreen extends ConsumerWidget {
  const AssociationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final judgeLevelsAsync = ref.watch(judgeLevelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Judge Associations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Import/Export Judge Levels',
            onPressed: () {
              context.push('/judge-levels/import-export');
            },
          ),
        ],
      ),
      body: judgeLevelsAsync.when(
        data: (levels) {
          // Group levels by association and count them
          final associationMap = <String, int>{};
          for (final level in levels) {
            associationMap[level.association] = (associationMap[level.association] ?? 0) + 1;
          }

          final associations = associationMap.keys.toList()..sort();

          if (associations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_work, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No associations found'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAssociationDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Association'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: associations.length,
            itemBuilder: (context, index) {
              final association = associations[index];
              final levelCount = associationMap[association] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(association[0]),
                  ),
                  title: Text(
                    association,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text('$levelCount level${levelCount != 1 ? 's' : ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/judge-levels/$association');
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading associations: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAssociationDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddAssociationDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Association'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Association Name',
            hintText: 'e.g., USAG, AAU',
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim().toUpperCase();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                context.push('/judge-levels/$name');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
