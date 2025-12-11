import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/event_day.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../repositories/event_day_repository.dart';

class EventStructureScreen extends ConsumerWidget {
  final String eventId;

  const EventStructureScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Structure'),
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
      future: EventDayRepository().getEventDaysByEventId(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final days = snapshot.data ?? [];

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
            if (days.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
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
              )
            else
              ...days.map((day) => _buildDayCard(context, ref, day, event)),
          ],
        );
      },
    );
  }

  Widget _buildDayCard(BuildContext context, WidgetRef ref, EventDay day, Event event) {
    final dateFormat = DateFormat('EEEE, MMM d');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/events/$eventId/days/${day.id}'),
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
    context.push('/events/$eventId/add-day');
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

        ref.invalidate(eventProvider(eventId));
        ref.invalidate(totalFeesForDayProvider(day.id));
        ref.invalidate(totalFeesForDayProvider(newDay.id));

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
        ref.invalidate(eventProvider(eventId));

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
