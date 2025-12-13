import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/event_floor.dart';
import '../../models/event_session.dart';
import '../../models/judge_assignment.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_assignment_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/judge_assignment_repository.dart';
import '../../widgets/apparatus_icon.dart';

class FloorDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String dayId;
  final String sessionId;
  final String floorId;

  const FloorDetailScreen({
    super.key,
    required this.eventId,
    required this.dayId,
    required this.sessionId,
    required this.floorId,
  });

  @override
  ConsumerState<FloorDetailScreen> createState() => _FloorDetailScreenState();
}

class _FloorDetailScreenState extends ConsumerState<FloorDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Floor / Pod Details')),
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

        final timeFmt = DateFormat('h:mm a');
        final start = DateTime(2000, 1, 1, session.startTime.hour, session.startTime.minute);
        final end = DateTime(2000, 1, 1, session.endTime.hour, session.endTime.minute);

        return SingleChildScrollView(
          child: Column(
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
                    Text('${session.name} • ${timeFmt.format(start)} - ${timeFmt.format(end)}'),
                    const SizedBox(height: 4),
                    Text('Floor ${floor.floorNumber}: ${floor.name}'),
                    const SizedBox(height: 8),
                    Consumer(builder: (context, ref, _) {
                      final totalAsync = ref.watch(totalFeesForFloorProvider(floor.id));
                      return totalAsync.when(
                        data: (t) => Text('Total Fees: \$${t.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        loading: () => const CircularProgressIndicator(strokeWidth: 2),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Judges by Apparatus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final cols = width >= 1200
                          ? 4
                          : width >= 900
                            ? 3
                            : 2;
                        return GridView.count(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildApparatusButton('Vault', context, session, floor),
                            _buildApparatusButton('Bars', context, session, floor),
                            _buildApparatusButton('Beam', context, session, floor),
                            _buildApparatusButton('Floor', context, session, floor),
                            _buildApparatusButton('Other', context, session, floor),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assigned Judges', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final assignmentsAsync = ref.watch(assignmentsByFloorProvider(floor.id));
                        return assignmentsAsync.when(
                          data: (assignments) {
                            if (assignments.isEmpty) {
                              return const Text('No judges assigned', style: TextStyle(fontSize: 12, color: Colors.grey));
                            }

                            final byApparatus = <String, List<JudgeAssignment>>{};
                            for (final a in assignments) {
                              final key = a.apparatus ?? 'Other';
                              byApparatus.putIfAbsent(key, () => []).add(a);
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: byApparatus.entries.map((e) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ApparatusIcon(
                                          apparatus: e.key,
                                          size: 18,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...e.value.map((a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(a.judgeFullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                                Text('${a.judgeAssociation} - ${a.judgeLevel}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (choice) {
                                              if (choice == 'edit') {
                                                context.push('/assignments/${a.id}/edit?floorId=${floor.id}&sessionId=${session.id}');
                                              } else if (choice == 'delete') {
                                                _confirmDeleteAssignment(a, session, floor);
                                              }
                                            },
                                            itemBuilder: (BuildContext context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 18),
                                                    SizedBox(width: 8),
                                                    Text('Edit Fees/Expenses'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete, size: 18, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Remove Judge', style: TextStyle(color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              }).toList(),
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('Error: $e'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApparatusButton(String apparatus, BuildContext context, EventSession session, EventFloor floor) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.push(
          '/events/${widget.eventId}/days/${widget.dayId}/sessions/${widget.sessionId}/floors/${floor.id}/assign-apparatus?apparatus=${Uri.encodeComponent(apparatus)}',
        ),
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconSize = (constraints.biggest.shortestSide * 0.45).clamp(28.0, 48.0);
            return Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ApparatusIcon(
                    apparatus: apparatus,
                    size: iconSize,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    apparatus,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAssignment(JudgeAssignment a, EventSession session, EventFloor floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Judge'),
        content: Text('Remove ${a.judgeFullName} from this floor?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await JudgeAssignmentRepository().deleteAssignment(a.id);
        if (mounted) {
          ref.invalidate(assignmentsByFloorProvider(floor.id));
          ref.invalidate(totalFeesForFloorProvider(floor.id));
          ref.invalidate(totalFeesForSessionProvider(session.id));
          ref.invalidate(totalFeesForDayProvider(session.eventDayId));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judge removed')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
