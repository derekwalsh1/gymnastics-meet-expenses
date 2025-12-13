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
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit Session'),
                  ],
                ),
              ),
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
              if (value == 'edit') {
                _showEditSessionDialog(context, session);
              } else if (value == 'clone') {
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
                if (session.name != null && session.name!.trim().isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.name!,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Edit Session',
                        onPressed: () => _showEditSessionDialog(context, session),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
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

  Widget _buildFloorColorIcon(EventFloor floor) {
    Color getFloorColor(String colorName) {
      switch (colorName) {
        case 'red':
          return Colors.red;
        case 'blue':
          return Colors.blue;
        case 'green':
          return Colors.green;
        case 'white':
          return Colors.white;
        case 'black':
          return Colors.black;
        case 'pink':
          return Colors.pink;
        case 'yellow':
          return Colors.yellow;
        case 'orange':
          return Colors.orange;
        case 'lavender':
          return const Color(0xFFE6E6FA);
        case 'beige':
          return const Color(0xFFF5F5DC);
        case 'silver':
          return const Color(0xFFC0C0C0);
        case 'bronze':
          return const Color(0xFFCD7F32);
        case 'gold':
          return const Color(0xFFFFD700);
        default:
          return Colors.blue;
      }
    }

    final color = getFloorColor(floor.displayColor);
    
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildFloorCard(BuildContext context, EventSession session, EventFloor floor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/events/${widget.eventId}/days/${widget.dayId}/sessions/${widget.sessionId}/floors/${floor.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildFloorColorIcon(floor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Floor ${floor.floorNumber}${(floor.name.trim().isNotEmpty) ? ' (${floor.name})' : ''}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          tooltip: 'Edit Floor',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => _showEditFloorDialog(context, session, floor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer(
                    builder: (context, ref, child) {
                      final totalAsync = ref.watch(totalFeesForFloorProvider(floor.id));
                      return totalAsync.when(
                        data: (total) => Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                            ),
                            Text('fees', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                        loading: () => const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (e, stack) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Floor')]),
                      ),
                      PopupMenuItem(
                        value: 'clone',
                        child: Row(children: [Icon(Icons.content_copy, size: 18), SizedBox(width: 8), Text('Clone Floor')]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete Floor', style: TextStyle(color: Colors.red))]),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditFloorDialog(context, session, floor);
                      } else if (value == 'clone') {
                        _cloneFloor(context, session, floor);
                      } else if (value == 'delete') {
                        _confirmDeleteFloor(context, session, floor);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Floor card ends here; assignments are intentionally hidden in this view.
            ],
          ),
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
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_apparatusIcon(assignment.apparatus), color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                assignment.judgeFirstName[0] + assignment.judgeLastName[0],
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
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
              '${assignment.judgeAssociation} - ${assignment.judgeLevel}${assignment.role != null ? ' (${assignment.role})' : ''}${assignment.apparatus != null ? ' • ${assignment.apparatus}' : ''}',
              style: const TextStyle(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
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

  IconData _apparatusIcon(String? apparatus) {
    switch (apparatus) {
      case 'Vault':
        return Icons.sports_gymnastics;
      case 'Bars':
        return Icons.hardware;
      case 'Beam':
        return Icons.stacked_line_chart;
      case 'Floor':
        return Icons.view_comfy;
      default:
        return Icons.category;
    }
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

  Future<void> _showEditSessionDialog(BuildContext context, EventSession session) async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) {
        return _EditSessionDialog(initialName: session.name, initialNotes: session.notes ?? '');
      },
    );

    if (result != null && context.mounted) {
      try {
        final updated = session.copyWith(
          name: result['name']!,
          notes: result['notes']!.isEmpty ? null : result['notes'],
          updatedAt: DateTime.now(),
        );
        
        await EventSessionRepository().updateEventSession(updated);
        ref.invalidate(eventProvider(widget.eventId));
        
        if (mounted) {
          setState(() {
            _refreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session updated')),
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

  Future<void> _showEditFloorDialog(BuildContext context, EventSession session, EventFloor floor) async {
    final result = await showDialog<Map<String, String?>?>(
      context: context,
      builder: (context) {
        return _EditFloorDialog(initialName: floor.name, initialNotes: floor.notes ?? '', initialColor: floor.color);
      },
    );

    if (result != null && context.mounted) {
      try {
        final updated = floor.copyWith(
          name: result['name']!,
          notes: result['notes']!.isEmpty ? null : result['notes'],
          color: result['color'],
          updatedAt: DateTime.now(),
        );
        
        await EventFloorRepository().updateEventFloor(updated);
        ref.invalidate(eventProvider(widget.eventId));
        
        if (mounted) {
          setState(() {
            _refreshKey++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Floor updated')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating floor: $e')),
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

class _EditSessionDialog extends StatefulWidget {
  final String initialName;
  final String initialNotes;

  const _EditSessionDialog({required this.initialName, required this.initialNotes});

  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<_EditSessionDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Session Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session name is required')),
              );
              return;
            }
            Navigator.pop(context, {
              'name': _nameController.text,
              'notes': _notesController.text,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditFloorDialog extends StatefulWidget {
  final String initialName;
  final String initialNotes;
  final String? initialColor;

  const _EditFloorDialog({required this.initialName, required this.initialNotes, this.initialColor});

  @override
  State<_EditFloorDialog> createState() => _EditFloorDialogState();
}

class _EditFloorDialogState extends State<_EditFloorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late String? _selectedColor;

  final List<Map<String, dynamic>> _floorColors = [
    {'name': 'Red', 'value': 'red', 'color': Colors.red},
    {'name': 'Blue', 'value': 'blue', 'color': Colors.blue},
    {'name': 'Green', 'value': 'green', 'color': Colors.green},
    {'name': 'White', 'value': 'white', 'color': Colors.white},
    {'name': 'Black', 'value': 'black', 'color': Colors.black},
    {'name': 'Pink', 'value': 'pink', 'color': Colors.pink},
    {'name': 'Yellow', 'value': 'yellow', 'color': Colors.yellow},
    {'name': 'Orange', 'value': 'orange', 'color': Colors.orange},
    {'name': 'Lavender', 'value': 'lavender', 'color': const Color(0xFFE6E6FA)},
    {'name': 'Beige', 'value': 'beige', 'color': const Color(0xFFF5F5DC)},
    {'name': 'Silver', 'value': 'silver', 'color': const Color(0xFFC0C0C0)},
    {'name': 'Bronze', 'value': 'bronze', 'color': const Color(0xFFCD7F32)},
    {'name': 'Gold', 'value': 'gold', 'color': const Color(0xFFFFD700)},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _notesController = TextEditingController(text: widget.initialNotes);
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Floor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Floor Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Floor Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _floorColors.map((colorData) {
              final isSelected = _selectedColor == colorData['value'];
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorData['value']),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colorData['color'],
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade400,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: colorData['value'] == 'white' || colorData['value'] == 'yellow' || colorData['value'] == 'beige' ? Colors.black : Colors.white,
                          size: 24,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Floor name is required')),
              );
              return;
            }
            Navigator.pop(context, {
              'name': _nameController.text,
              'notes': _notesController.text,
              'color': _selectedColor,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
