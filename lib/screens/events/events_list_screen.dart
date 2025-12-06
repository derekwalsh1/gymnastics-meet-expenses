import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';

class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(filteredEventsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context, ref),
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No events yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create your first event',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _EventCard(event: event);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading events: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/events/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Events'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'By Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...[
                ListTile(
                  dense: true,
                  title: const Text('All Statuses'),
                  onTap: () {
                    ref.read(eventStatusFilterProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                ),
                ...EventStatus.values.map((status) {
                  return ListTile(
                    dense: true,
                    title: Text(status.name.toUpperCase()),
                    onTap: () {
                      ref.read(eventStatusFilterProvider.notifier).state = status;
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
              const Divider(),
              const Text(
                'By Association',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...[
                ListTile(
                  dense: true,
                  title: const Text('All Associations'),
                  onTap: () {
                    ref.read(eventAssociationFilterProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                ),
                ...['NAWGJ', 'NGA', 'USAG', 'AAU'].map((association) {
                  return ListTile(
                    dense: true,
                    title: Text(association),
                    onTap: () {
                      ref.read(eventAssociationFilterProvider.notifier).state = association;
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final startDate = dateFormat.format(event.startDate);
    final endDate = dateFormat.format(event.endDate);
    final dateRange = startDate == endDate ? startDate : '$startDate - $endDate';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/events/${event.id}'),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(event.status),
          child: Icon(
            _getStatusIcon(event.status),
            color: Colors.white,
          ),
        ),
        title: Text(
          event.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(dateRange),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${event.location.venueName}, ${event.location.city}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (event.associationId != null)
              _AssociationBadge(association: event.associationId!),
            const SizedBox(height: 4),
            _StatusBadge(status: event.status),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Colors.blue;
      case EventStatus.ongoing:
        return Colors.green;
      case EventStatus.completed:
        return Colors.orange;
      case EventStatus.archived:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Icons.schedule;
      case EventStatus.ongoing:
        return Icons.play_circle;
      case EventStatus.completed:
        return Icons.check_circle;
      case EventStatus.archived:
        return Icons.archive;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final EventStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: _getColor(),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case EventStatus.upcoming:
        return Colors.blue;
      case EventStatus.ongoing:
        return Colors.green;
      case EventStatus.completed:
        return Colors.orange;
      case EventStatus.archived:
        return Colors.grey;
    }
  }
}

class _AssociationBadge extends StatelessWidget {
  final String association;

  const _AssociationBadge({required this.association});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getAssociationColor(association).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAssociationColor(association).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        association,
        style: TextStyle(
          color: _getAssociationColor(association),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getAssociationColor(String association) {
    switch (association.toUpperCase()) {
      case 'NAWGJ':
        return Colors.purple;
      case 'NGA':
        return Colors.indigo;
      case 'USAG':
        return Colors.blue;
      case 'AAU':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }
}
