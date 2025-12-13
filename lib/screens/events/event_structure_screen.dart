import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/event_day.dart';
import '../../models/event_session.dart';
import '../../models/event_floor.dart';
import '../../models/judge_assignment.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../providers/judge_assignment_provider.dart';
import '../../repositories/event_day_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/judge_assignment_repository.dart';

class EventStructureScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventStructureScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventStructureScreen> createState() => _EventStructureScreenState();
}

class _EventStructureScreenState extends ConsumerState<EventStructureScreen> {
  int _refreshKey = 0;

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Structure'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found'));
          }
          return _buildEventStructure(context, ref, event);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading event: $error'),
        ),
      ),
    );
  }

  Widget _buildEventStructure(BuildContext context, WidgetRef ref, Event event) {
    return FutureBuilder<List<EventDay>>(
      key: ValueKey('event_structure_$_refreshKey'),
      future: EventDayRepository().getEventDaysByEventId(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final days = snapshot.data ?? [];

        if (days.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No days configured'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDayDialog(context, ref, event, 0),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Day'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              flex: 2,
              child: _buildDaysListView(context, ref, event, days),
            ),
            const Divider(height: 1, thickness: 2),
            Expanded(
              flex: 3,
              child: _buildJudgeScheduleView(context, ref, event, days),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDaysListView(BuildContext context, WidgetRef ref, Event event, List<EventDay> days) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Event Days',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Day'),
              onPressed: () => _showAddDayDialog(context, ref, event, days.length),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...days.map((day) => _buildDayCard(context, ref, day, event)),
      ],
    );
  }

  Widget _buildJudgeScheduleView(BuildContext context, WidgetRef ref, Event event, List<EventDay> days) {
    return FutureBuilder<List<EventFloor>>(
      key: ValueKey('judge_schedule_$_refreshKey'),
      future: _getAllFloorsForEvent(widget.eventId),
      builder: (context, floorsSnapshot) {
        if (floorsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFloors = floorsSnapshot.data ?? [];
        
        if (allFloors.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No floors configured yet.\nAdd sessions and floors to see the judge schedule.'),
            ),
          );
        }

        // Group floors by pod (floor name)
        final floorsByPod = <String, List<EventFloor>>{};
        for (final floor in allFloors) {
          floorsByPod.putIfAbsent(floor.name, () => []).add(floor);
        }

        return DefaultTabController(
          length: floorsByPod.length,
          child: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                child: TabBar(
                  isScrollable: true,
                  tabs: floorsByPod.keys.map((podName) => Tab(text: podName)).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: floorsByPod.entries.map((entry) {
                    return _buildPodScheduleTable(context, ref, entry.key, entry.value, days);
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodScheduleTable(BuildContext context, WidgetRef ref, String podName, List<EventFloor> floors, List<EventDay> days) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('pod_schedule_${podName}_$_refreshKey'),
      future: _buildScheduleData(ref, floors, days),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final scheduleData = snapshot.data ?? [];
        
        if (scheduleData.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No sessions scheduled for $podName'),
            ),
          );
        }

        // Get the color from the first floor in this pod
        final podColor = floors.isNotEmpty ? _getFloorColor(floors.first.color) : Colors.grey;
        
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildScheduleTable(context, scheduleData, days, podColor),
          ),
        );
      },
    );
  }

  Widget _buildScheduleTable(BuildContext context, List<Map<String, dynamic>> scheduleData, List<EventDay> days, Color podColor) {
    final dayAbbrevFormat = DateFormat('E');  // Mon, Tue, Wed, etc.
    final shortDateFormat = DateFormat('M/d/yy');
    final timeFormat = DateFormat('h:mm a');
    
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 2),
      defaultColumnWidth: const FlexColumnWidth(),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      children: [
        // Build table rows grouped by day
        for (final entry in scheduleData) ...[
          // Day header row
          TableRow(
            decoration: BoxDecoration(
              color: podColor.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(color: podColor, width: 3),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Day ${entry['dayNumber']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  dayAbbrevFormat.format(entry['date']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  shortDateFormat.format(entry['date']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(),
              const SizedBox(),
            ],
          ),
          // Session header and data rows
          for (final session in entry['sessions']) ...[
            // Session header with time
            TableRow(
              decoration: BoxDecoration(color: podColor.withOpacity(0.15)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Text(
                    session['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Text(
                    timeFormat.format(session['startTime']),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                const SizedBox(),
                const SizedBox(),
                const SizedBox(),
              ],
            ),
            // Apparatus headers
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Vault', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Bars', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Beam', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Floor', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Floating', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ],
            ),
            // Judge rows
            for (int i = 0; i < session['maxJudges']; i++)
              TableRow(
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : Colors.grey.shade50,
                ),
                children: [
                  for (final apparatus in ['Vault', 'Bars', 'Beam', 'Floor', 'Other'])
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildJudgeCell(
                        (session['judges'][apparatus] as List<Map<String, String>>).length > i
                            ? (session['judges'][apparatus] as List<Map<String, String>>)[i]
                            : null
                      ),
                    ),
                ],
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildJudgeCell(Map<String, String>? judgeInfo) {
    if (judgeInfo == null || judgeInfo['name'] == null || judgeInfo['name']!.isEmpty) {
      return const SizedBox(height: 30);
    }
    
    return InkWell(
      onTap: () {
        final floorId = judgeInfo['floorId'];
        final dayId = judgeInfo['dayId'];
        final sessionId = judgeInfo['sessionId'];
        if (floorId != null && dayId != null && sessionId != null) {
          context.push(
            '/events/${widget.eventId}/days/$dayId/sessions/$sessionId/floors/$floorId'
          ).then((_) {
            // Invalidate assignment providers to force fresh data
            ref.invalidate(assignmentsByFloorProvider(floorId));
            ref.invalidate(assignmentsBySessionProvider(sessionId));
            ref.invalidate(assignmentsByEventProvider(widget.eventId));
            _refresh();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          judgeInfo['name']!,
          style: const TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Color _getFloorColor(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'pink':
        return Colors.pink;
      case 'lavender':
        return const Color(0xFFE6E6FA);
      case 'white':
        return Colors.grey.shade100;
      case 'beige':
        return const Color(0xFFF5F5DC);
      case 'black':
        return Colors.grey.shade800;
      case 'red':
        return Colors.red;
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'gold':
        return const Color(0xFFFFD700);
      default:
        return Colors.grey;
    }
  }

  Future<List<EventFloor>> _getAllFloorsForEvent(String eventId) async {
    final days = await EventDayRepository().getEventDaysByEventId(eventId);
    final allFloors = <EventFloor>[];
    
    for (final day in days) {
      final sessions = await EventSessionRepository().getEventSessionsByDayId(day.id);
      for (final session in sessions) {
        final floors = await EventFloorRepository().getEventFloorsBySessionId(session.id);
        allFloors.addAll(floors);
      }
    }
    
    return allFloors;
  }

  Future<List<Map<String, dynamic>>> _buildScheduleData(WidgetRef ref, List<EventFloor> floors, List<EventDay> days) async {
    final scheduleByDay = <String, Map<String, dynamic>>{};
    
    for (final floor in floors) {
      final session = await EventSessionRepository().getEventSessionById(floor.eventSessionId);
      if (session == null) continue;
      
      final day = days.firstWhere((d) => d.id == session.eventDayId, orElse: () => days.first);
      final dayKey = day.date.toIso8601String().substring(0, 10);
      
      scheduleByDay.putIfAbsent(dayKey, () => {
        'date': day.date,
        'dayNumber': day.dayNumber ?? 0,
        'sessions': <String, Map<String, dynamic>>{},
      });
      
      final sessionsMap = scheduleByDay[dayKey]!['sessions'] as Map<String, Map<String, dynamic>>;
      sessionsMap.putIfAbsent(session.id, () => {
        'name': session.name ?? 'Session ${session.sessionNumber}',
        'startTime': DateTime(2000, 1, 1, session.startTime.hour, session.startTime.minute),
        'dayId': day.id,
        'sessionId': session.id,
        'judges': <String, List<Map<String, String>>>{
          'Vault': <Map<String, String>>[],
          'Bars': <Map<String, String>>[],
          'Beam': <Map<String, String>>[],
          'Floor': <Map<String, String>>[],
          'Other': <Map<String, String>>[],
        },
        'maxJudges': 0,
      });
      
      // Get judge assignments for this floor
      final assignments = await JudgeAssignmentRepository().getAssignmentsByFloorId(floor.id);
      
      // Group assignments by apparatus
      for (final assignment in assignments) {
        final apparatus = assignment.apparatus ?? 'Other';
        if (['Vault', 'Bars', 'Beam', 'Floor', 'Other'].contains(apparatus)) {
          final judgesList = sessionsMap[session.id]!['judges'][apparatus] as List<Map<String, String>>;
          judgesList.add({
            'name': assignment.judgeFullName,
            'floorId': floor.id,
            'dayId': day.id,
            'sessionId': session.id,
          });
        }
      }
      
      // Update max judges count
      int maxCount = 0;
      for (final judgesList in (sessionsMap[session.id]!['judges'] as Map<String, List<Map<String, String>>>).values) {
        if (judgesList.length > maxCount) {
          maxCount = judgesList.length;
        }
      }
      sessionsMap[session.id]!['maxJudges'] = maxCount;
    }
    
    // Convert to sorted list
    final result = <Map<String, dynamic>>[];
    for (final dayData in scheduleByDay.values) {
      final sessionsMap = dayData['sessions'] as Map<String, Map<String, dynamic>>;
      final sessionsList = sessionsMap.values.toList();
      sessionsList.sort((a, b) => (a['startTime'] as DateTime).compareTo(b['startTime'] as DateTime));
      
      result.add({
        'date': dayData['date'],
        'dayNumber': dayData['dayNumber'],
        'sessions': sessionsList,
      });
    }
    
    result.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    return result;
  }

  Widget _buildDayCard(BuildContext context, WidgetRef ref, EventDay day, Event event) {
    final dateFormat = DateFormat('EEEE, MMM d');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/events/${widget.eventId}/days/${day.id}').then((_) => _refresh()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day ${day.dayNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          dateFormat.format(day.date),
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
                      final totalAsync = ref.watch(totalFeesForDayProvider(day.id));
                      return totalAsync.when(
                        data: (total) => Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'total fees',
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
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'clone',
                        child: Row(
                          children: [
                            Icon(Icons.content_copy, size: 18),
                            SizedBox(width: 8),
                            Text('Clone Day'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Day', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'clone') {
                        _showCloneDayDialog(context, ref, day);
                      } else if (value == 'delete') {
                        _confirmDeleteDay(context, ref, day, event);
                      }
                    },
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDayDialog(BuildContext context, WidgetRef ref, Event event, int currentDayCount) {
    context.push('/events/${widget.eventId}/add-day').then((_) => _refresh());
  }

  Future<void> _showCloneDayDialog(BuildContext context, WidgetRef ref, EventDay day) async {
    DateTime selectedDate = day.date.add(const Duration(days: 1));
    bool includeJudges = true;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Clone Day'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a copy of Day ${day.dayNumber} with all its sessions and floors.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('New Date'),
                    subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
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
                  onPressed: () => Navigator.pop(context, {
                    'date': selectedDate,
                    'includeJudges': includeJudges,
                  }),
                  child: const Text('Clone Day'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && context.mounted) {
      try {
        final newDay = await EventDayRepository().cloneEventDay(
          eventDayId: day.id,
          newDate: result['date'] as DateTime,
          includeJudgeAssignments: result['includeJudges'] as bool,
        );

        ref.invalidate(eventProvider(widget.eventId));
        ref.invalidate(totalFeesForDayProvider(day.id));
        ref.invalidate(totalFeesForDayProvider(newDay.id));
        _refresh();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Day cloned successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cloning day: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteDay(BuildContext context, WidgetRef ref, EventDay day, Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Day'),
        content: const Text('Are you sure you want to delete this day? This will also delete all sessions and floors.'),
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
        await EventDayRepository().deleteEventDay(day.id);
        ref.invalidate(eventProvider(widget.eventId));
        _refresh();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Day deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting day: $e')),
          );
        }
      }
    }
  }
}
