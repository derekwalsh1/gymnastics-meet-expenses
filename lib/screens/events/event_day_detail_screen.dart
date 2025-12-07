import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event_day.dart';
import '../../models/event_session.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../repositories/event_day_repository.dart';
import '../../repositories/event_session_repository.dart';

class EventDayDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String dayId;

  const EventDayDetailScreen({
    super.key,
    required this.eventId,
    required this.dayId,
  });

  @override
  ConsumerState<EventDayDetailScreen> createState() => _EventDayDetailScreenState();
}

class _EventDayDetailScreenState extends ConsumerState<EventDayDetailScreen> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventDay?>(
      key: ValueKey(_refreshKey),
      future: EventDayRepository().getEventDayById(widget.dayId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final day = snapshot.data;
        if (day == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Day Not Found')),
            body: const Center(child: Text('Event day not found')),
          );
        }

        return _buildDayDetail(context, day);
      },
    );
  }

  Widget _buildDayDetail(BuildContext context, EventDay day) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${day.dayNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDeleteDay(context, ref, day),
          ),
        ],
      ),
      body: Column(
        children: [
          // Day Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(day.date),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final totalAsync = ref.watch(totalFeesForDayProvider(day.id));
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
          // Sessions List
          Expanded(
            child: FutureBuilder<List<EventSession>>(
              key: ValueKey('sessions_$_refreshKey'),
              future: EventSessionRepository().getEventSessionsByDayId(widget.dayId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sessions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Session'),
                          onPressed: () => _showAddSessionDialog(context, day, sessions.length),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sessions.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Text('No sessions configured'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddSessionDialog(context, day, 0),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Session'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...sessions.map((session) => _buildSessionCard(context, session)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, EventSession session) {
    final timeFormat = DateFormat('h:mm a');
    final startTime = DateTime(2000, 1, 1, session.startTime.hour, session.startTime.minute);
    final endTime = DateTime(2000, 1, 1, session.endTime.hour, session.endTime.minute);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/events/${widget.eventId}/days/${widget.dayId}/sessions/${session.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session ${session.sessionNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}',
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
                  final totalAsync = ref.watch(totalFeesForSessionProvider(session.id));
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
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () => _confirmDeleteSession(context, ref, session),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSessionDialog(BuildContext context, EventDay day, int sessionCount) {
    context.push('/events/${widget.eventId}/days/${day.id}/add-session');
  }

  Future<void> _confirmDeleteDay(BuildContext context, WidgetRef ref, EventDay day) async {
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

        if (context.mounted) {
          context.pop(); // Go back to structure screen
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

  Future<void> _confirmDeleteSession(BuildContext context, WidgetRef ref, EventSession session) async {
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

        if (mounted) {
          setState(() {
            _refreshKey++;
          });
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
}
