import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_session.dart';
import '../../models/event_floor.dart';
import '../../models/judge_assignment.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../providers/judge_assignment_provider.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/judge_assignment_repository.dart';

class EventSessionDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String dayId;
  final String sessionId;

  const EventSessionDetailScreen({
    super.key,
    required this.eventId,
    required this.dayId,
    required this.sessionId,
  });

  @override
  ConsumerState<EventSessionDetailScreen> createState() => _EventSessionDetailScreenState();
}

class _EventSessionDetailScreenState extends ConsumerState<EventSessionDetailScreen> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventSession?>(
      key: ValueKey(_refreshKey),
      future: EventSessionRepository().getEventSessionById(widget.sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Session Not Found')),
            body: const Center(child: Text('Session not found')),
          );
        }

        return _buildSessionDetail(context, session);
      },
    );
  }

  Widget _buildSessionDetail(BuildContext context, EventSession session) {
    final timeFormat = DateFormat('h:mm a');
    final startTime = DateTime(2000, 1, 1, session.startTime.hour, session.startTime.minute);
    final endTime = DateTime(2000, 1, 1, session.endTime.hour, session.endTime.minute);

    return Scaffold(
      appBar: AppBar(
        title: Text('Session ${session.sessionNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.access_time),
            tooltip: 'Edit time',
            onPressed: () => _editSessionTimes(context, session),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clone',
                child: Row(
                  children: [
                    Icon(Icons.content_copy),
                    SizedBox(width: 8),
                    Text('Clone Session'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Session', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'clone') {
                _cloneSession(context, session);
              } else if (value == 'delete') {
                _confirmDeleteSession(context, session);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Session Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final totalAsync = ref.watch(totalFeesForSessionProvider(session.id));
                    return totalAsync.when(
                      data: (total) => Text(
                        'Total Fees: \$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (e, stack) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
            ),
          ),
          // Floors List
          Expanded(
            child: FutureBuilder<List<EventFloor>>(
              key: ValueKey('floors_$_refreshKey'),
              future: EventFloorRepository().getEventFloorsBySessionId(widget.sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final floors = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Floors',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Floor'),
                          onPressed: () => _showAddFloorDialog(context, session, floors.length),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (floors.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Text('No floors configured'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddFloorDialog(context, session, 0),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Floor'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...floors.map((floor) => _buildFloorCard(context, session, floor)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard(BuildContext context, EventSession session, EventFloor floor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Floor ${floor.floorNumber}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        floor.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final totalAsync = ref.watch(totalFeesForFloorProvider(floor.id));
                    return totalAsync.when(
                      data: (total) => Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'fees',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (e, stack) => const SizedBox.shrink(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clone',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy, size: 18),
                          SizedBox(width: 8),
                          Text('Clone Floor'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Floor', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'clone') {
                      _cloneFloor(context, session, floor);
                    } else if (value == 'delete') {
                      _confirmDeleteFloor(context, session, floor);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Judge Assignments
            Consumer(
              builder: (context, ref, child) {
                final assignmentsAsync = ref.watch(assignmentsByFloorProvider(floor.id));
                return assignmentsAsync.when(
                  data: (assignments) {
                    if (assignments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              const Text(
                                'No judges assigned',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showAssignJudgeDialog(context, session, floor),
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Assign Judge', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Assigned Judges (${assignments.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _showAssignJudgeDialog(context, session, floor),
                              icon: const Icon(Icons.person_add, size: 14),
                              label: const Text('Add', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...assignments.map((assignment) => _buildJudgeCard(context, assignment, session, floor)),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $error'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJudgeCard(
    BuildContext context,
    JudgeAssignment assignment,
    EventSession session,
    EventFloor floor,
  ) {
    final totalFeesAsync = ref.watch(totalFeesByAssignmentProvider(assignment.id));
    final feesAsync = ref.watch(feesByAssignmentProvider(assignment.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            assignment.judgeFirstName[0] + assignment.judgeLastName[0],
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(assignment.judgeFullName),
            ),
            const SizedBox(width: 8),
            totalFeesAsync.when(
              data: (total) => Text(
                '\$${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              loading: () => const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${assignment.judgeAssociation} - ${assignment.judgeLevel}${assignment.role != null ? ' (${assignment.role})' : ''}',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => context.push('/assignments/${assignment.id}/edit?floorId=${floor.id}&sessionId=${session.id}'),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/assignments/${assignment.id}/fees?judgeName=${Uri.encodeComponent(assignment.judgeFullName)}'),
                  icon: const Icon(Icons.attach_money, size: 14),
                  label: const Text('Fees', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, size: 18),
          onPressed: () => _confirmDeleteAssignment(context, session, floor, assignment),
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showAddFloorDialog(BuildContext context, EventSession session, int floorCount) {
    context.push('/events/${widget.eventId}/sessions/${session.id}/add-floor');
  }

  void _showAssignJudgeDialog(BuildContext context, EventSession session, EventFloor floor) {
    context.push('/events/${widget.eventId}/floors/${floor.id}/assign-judge?sessionId=${session.id}');
  }

  Future<void> _confirmDeleteSession(BuildContext context, EventSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure you want to delete this session? This will also delete all floors.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await EventSessionRepository().deleteEventSession(session.id);
        ref.invalidate(eventProvider(widget.eventId));
        ref.invalidate(totalFeesForDayProvider(session.eventDayId));

        if (context.mounted) {
          context.pop(); // Go back to day detail screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting session: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteFloor(BuildContext context, EventSession session, EventFloor floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Floor'),
        content: const Text('Are you sure you want to delete this floor? This will also unassign all judges.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await EventFloorRepository().deleteEventFloor(floor.id);
        ref.invalidate(eventProvider(widget.eventId));
        ref.invalidate(totalFeesForSessionProvider(session.id));
        ref.invalidate(totalFeesForDayProvider(session.eventDayId));

        if (mounted) {
          setState(() {
            _refreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Floor deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting floor: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteAssignment(
    BuildContext context,
    EventSession session,
    EventFloor floor,
    JudgeAssignment assignment,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Judge'),
        content: Text('Remove ${assignment.judgeFullName} from this floor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await JudgeAssignmentRepository().deleteAssignment(assignment.id);

        // Invalidate providers to refresh the UI
        ref.invalidate(assignmentsByFloorProvider(floor.id));
        ref.invalidate(availableJudgesForSessionProvider(session.id));

        // Invalidate fee totals
        ref.invalidate(totalFeesForFloorProvider(floor.id));
        ref.invalidate(totalFeesForSessionProvider(session.id));
        ref.invalidate(totalFeesForDayProvider(session.eventDayId));
        ref.invalidate(eventProvider(widget.eventId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Judge removed successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing judge: $e')),
          );
        }
      }
    }
  }

  Future<void> _cloneSession(BuildContext context, EventSession session) async {
    bool includeJudges = true;

    final result = await showDialog<bool?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Clone Session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will create a copy of Session ${session.sessionNumber} with all its floors.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Include judge assignments'),
                    value: includeJudges,
                    onChanged: (value) {
                      setState(() {
                        includeJudges = value ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, includeJudges),
                  child: const Text('Clone Session'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      try {
        await EventSessionRepository().cloneEventSession(
          eventSessionId: session.id,
          includeJudgeAssignments: result,
        );
        
        ref.invalidate(eventProvider(widget.eventId));
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session cloned successfully')),
          );
          context.pop(); // Return to day screen
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cloning session: $e')),
          );
        }
      }
    }
  }

  Future<void> _cloneFloor(BuildContext context, EventSession session, EventFloor floor) async {
    bool includeJudges = true;

    final result = await showDialog<bool?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Clone Floor'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will create a copy of Floor ${floor.floorNumber} (${floor.name}).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Include judge assignment'),
                    value: includeJudges,
                    onChanged: (value) {
                      setState(() {
                        includeJudges = value ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, includeJudges),
                  child: const Text('Clone Floor'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      try {
        await EventFloorRepository().cloneEventFloor(
          eventFloorId: floor.id,
          includeJudgeAssignments: result,
        );
        
        ref.invalidate(eventProvider(widget.eventId));
        ref.invalidate(totalFeesForSessionProvider(session.id));
        
        if (mounted) {
          setState(() {
            _refreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Floor cloned successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cloning floor: $e')),
          );
        }
      }
    }
  }

  Future<void> _editSessionTimes(BuildContext context, EventSession session) async {
    TimeOfDay newStart = session.startTime;
    TimeOfDay newEnd = session.endTime;
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickStart() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: newStart,
              );
              if (picked != null) {
                setState(() {
                  newStart = picked;
                });
              }
            }

            Future<void> pickEnd() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: newEnd,
              );
              if (picked != null) {
                setState(() {
                  newEnd = picked;
                });
              }
            }

            String format(TimeOfDay t) => t.format(context);

            return AlertDialog(
              title: const Text('Edit Session Time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: const Text('Start time'),
                    subtitle: Text(format(newStart)),
                    onTap: pickStart,
                  ),
                  ListTile(
                    leading: const Icon(Icons.stop),
                    title: const Text('End time'),
                    subtitle: Text(format(newEnd)),
                    onTap: pickEnd,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final startMinutes = newStart.hour * 60 + newStart.minute;
                    final endMinutes = newEnd.hour * 60 + newEnd.minute;
                    if (endMinutes <= startMinutes) {
                      setState(() {
                        error = 'End time must be after start time.';
                      });
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        final updated = session.copyWith(
          startTime: newStart,
          endTime: newEnd,
          updatedAt: DateTime.now(),
        );

        await EventSessionRepository().updateEventSession(updated);
        await JudgeAssignmentRepository().recalcAutoFeesForSession(session.id);

        // Invalidate fee totals for floors and assignments in this session
        final floorRepo = EventFloorRepository();
        final assignmentRepo = JudgeAssignmentRepository();
        final floors = await floorRepo.getEventFloorsBySessionId(session.id);
        for (final floor in floors) {
          ref.invalidate(totalFeesForFloorProvider(floor.id));
          final assignments = await assignmentRepo.getAssignmentsByFloorId(floor.id);
          for (final assignment in assignments) {
            ref.invalidate(totalFeesByAssignmentProvider(assignment.id));
          }
        }

        ref.invalidate(eventProvider(widget.eventId));
        ref.invalidate(totalFeesForSessionProvider(session.id));
        ref.invalidate(totalFeesForDayProvider(session.eventDayId));

        if (mounted) {
          setState(() {
            _refreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session time updated')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating session: $e')),
          );
        }
      }
    }
  }
}
