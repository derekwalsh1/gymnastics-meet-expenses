import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/event.dart';
import '../../models/event_floor.dart';
import '../../models/event_session.dart';
import '../../models/judge_with_level.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../providers/judge_assignment_provider.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/judge_assignment_repository.dart';
import '../judges/add_edit_judge_screen.dart';

class FloorApparatusAssignScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String dayId;
  final String sessionId;
  final String floorId;
  final String apparatus;

  const FloorApparatusAssignScreen({
    super.key,
    required this.eventId,
    required this.dayId,
    required this.sessionId,
    required this.floorId,
    required this.apparatus,
  });

  @override
  ConsumerState<FloorApparatusAssignScreen> createState() => _FloorApparatusAssignScreenState();
}

class _FloorApparatusAssignScreenState extends ConsumerState<FloorApparatusAssignScreen> {
  String _searchQuery = '';
  final Set<String> _selectedJudgeIds = {};
  bool _assigning = false;

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    return Scaffold(
      appBar: AppBar(title: Text('Assign to ${widget.apparatus}')),
      body: eventAsync.when(
        data: (event) {
          if (event == null) return const Center(child: Text('Event not found'));
          return _buildContent(event);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(Event event) {
    return FutureBuilder(
      future: Future.wait([
        EventFloorRepository().getEventFloorById(widget.floorId),
        EventSessionRepository().getEventSessionById(widget.sessionId),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data == null || snap.data!.isEmpty) {
          return const Center(child: Text('Floor or session not found'));
        }

        final floor = snap.data![0] as EventFloor?;
        final session = snap.data![1] as EventSession?;
        if (floor == null || session == null) {
          return const Center(child: Text('Floor or session not found'));
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name),
                  const SizedBox(height: 4),
                  Text('Floor ${floor.floorNumber}: ${floor.name}'),
                  const SizedBox(height: 4),
                  Text(widget.apparatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search judges...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Add new judge',
                    child: IconButton(
                      onPressed: () => _openAddJudgeScreen(event),
                      icon: const Icon(Icons.person_add),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildJudgeList(event, session, floor)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedJudgeIds.isEmpty || _assigning ? null : () => _assignSelected(session, floor, event),
                  icon: const Icon(Icons.person_add),
                  label: Text('Assign ${_selectedJudgeIds.length} Judge${_selectedJudgeIds.length != 1 ? 's' : ''}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAddJudgeScreen(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddEditJudgeScreen(),
      ),
    ).then((_) {
      // Refresh judges list after returning from judge creation
      ref.refresh(judgesWithLevelsProvider);
    });
  }

  Widget _buildJudgeList(Event event, EventSession session, EventFloor floor) {
    final judgesAsync = ref.watch(judgesWithLevelsProvider);
    return judgesAsync.when(
      data: (allJudges) {
        return FutureBuilder<Set<String>>(
          future: _getAssignedJudgeIds(session),
          builder: (context, assignedSnap) {
            if (assignedSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final assignedIds = assignedSnap.data ?? {};
            List<JudgeWithLevels> filtered = allJudges.where((j) {
              if (_searchQuery.isNotEmpty && !j.judge.fullName.toLowerCase().contains(_searchQuery)) return false;
              if (assignedIds.contains(j.judge.id)) return false;
              // Filter to judges with certifications matching event association
              if (!j.associations.contains(event.associationId)) return false;
              return true;
            }).toList();

            if (filtered.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No judges available for assignment'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final j = filtered[i];
                final selected = _selectedJudgeIds.contains(j.judge.id);
                return ListTile(
                  title: Text(j.judge.fullName),
                  subtitle: Text('${j.levels.isNotEmpty ? j.levels.first.level : 'No level'}'),
                  trailing: Checkbox(
                    value: selected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedJudgeIds.add(j.judge.id);
                        } else {
                          _selectedJudgeIds.remove(j.judge.id);
                        }
                      });
                    },
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<Set<String>> _getAssignedJudgeIds(EventSession session) async {
    final floorRepo = EventFloorRepository();
    final assignmentRepo = JudgeAssignmentRepository();
    final floors = await floorRepo.getEventFloorsBySessionId(session.id);
    final assignedIds = <String>{};
    for (final f in floors) {
      final assignments = await assignmentRepo.getAssignmentsByFloorId(f.id);
      for (final a in assignments) {
        assignedIds.add(a.judgeId);
      }
    }
    return assignedIds;
  }

  Future<void> _assignSelected(EventSession session, EventFloor floor, Event event) async {
    if (_selectedJudgeIds.isEmpty) return;
    setState(() => _assigning = true);
    try {
      final judges = await ref.read(judgesWithLevelsProvider.future);
      for (final id in _selectedJudgeIds) {
        final selected = judges.firstWhere((j) => j.judge.id == id);
        await JudgeAssignmentRepository().createAssignment(
          eventFloorId: floor.id,
          judge: selected,
          association: event.associationId ?? '',
          role: null,
          apparatus: widget.apparatus,
        );
      }

      ref.invalidate(assignmentsByFloorProvider(floor.id));
      ref.invalidate(totalFeesForFloorProvider(floor.id));
      ref.invalidate(totalFeesForSessionProvider(session.id));
      ref.invalidate(totalFeesForDayProvider(session.eventDayId));

      setState(() {
        _selectedJudgeIds.clear();
        _assigning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Judges assigned'),
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _assigning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
