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
import '../../repositories/event_day_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/judge_assignment_repository.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/events'),
        ),
        title: const Text('Event Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit event
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showEventMenu(context),
          ),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found'));
          }
          return _buildEventDetails(event);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading event: $error'),
        ),
      ),
    );
  }

  Widget _buildEventDetails(Event event) {
    return ListView(
      children: [
        _buildEventHeader(event),
        const Divider(height: 1),
        _buildEventInfo(event),
        const Divider(height: 1),
        _buildEventStructure(event),
      ],
    );
  }

  Widget _buildEventHeader(Event event) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final startDate = dateFormat.format(event.startDate);
    final endDate = dateFormat.format(event.endDate);
    final dateRange = startDate == endDate ? startDate : '$startDate - $endDate';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(dateRange),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${event.location.venueName}, ${event.location.city}, ${event.location.state}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventInfo(Event event) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (event.associationId != null)
            _buildInfoRow('Association', event.associationId!),
          _buildInfoRow('Status', event.status.name.toUpperCase()),
          if (event.description.isNotEmpty)
            _buildInfoRow('Description', event.description),
          _buildInfoRow('Address', event.location.address),
          _buildInfoRow('City', '${event.location.city}, ${event.location.state} ${event.location.zipCode}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildEventStructure(Event event) {
    return FutureBuilder<List<EventDay>>(
      future: EventDayRepository().getEventDaysByEventId(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final days = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Event Structure',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Day'),
                    onPressed: () {
                      // TODO: Add day functionality
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (days.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No days configured'),
                  ),
                )
              else
                ...days.map((day) => _buildDayCard(day)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayCard(EventDay day) {
    final dateFormat = DateFormat('EEEE, MMM d');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          'Day ${day.dayNumber}: ${dateFormat.format(day.date)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          FutureBuilder<List<EventSession>>(
            future: EventSessionRepository().getEventSessionsByDayId(day.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final sessions = snapshot.data ?? [];

              if (sessions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('No sessions configured'),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Session'),
                        onPressed: () {
                          // TODO: Add session functionality
                        },
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: sessions.map((session) => _buildSessionCard(session)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(EventSession session) {
    final timeFormat = DateFormat('h:mm a');
    final startTime = DateTime(2000, 1, 1, session.startTime.hour, session.startTime.minute);
    final endTime = DateTime(2000, 1, 1, session.endTime.hour, session.endTime.minute);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(session.name),
        subtitle: Text(
          '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)} (${session.durationInHours.toStringAsFixed(1)} hrs)',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          FutureBuilder<List<EventFloor>>(
            future: EventFloorRepository().getEventFloorsBySessionId(session.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final floors = snapshot.data ?? [];

              if (floors.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('No floors configured'),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Floor'),
                        onPressed: () {
                          // TODO: Add floor functionality
                        },
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: floors.map((floor) => _buildFloorCard(floor, session)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard(EventFloor floor, EventSession session) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              floor.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAssignJudgeDialog(floor, session),
            ),
          ),
          FutureBuilder<List<JudgeAssignment>>(
            future: JudgeAssignmentRepository().getAssignmentsByFloorId(floor.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final assignments = snapshot.data ?? [];

              if (assignments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No judges assigned',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: assignments.map((assignment) => 
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        assignment.judgeFirstName[0] + assignment.judgeLastName[0],
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text(assignment.judgeFullName),
                    subtitle: Text(
                      '${assignment.judgeAssociation} - ${assignment.judgeLevel}${assignment.role != null ? ' (${assignment.role})' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${assignment.hourlyRate.toStringAsFixed(2)}/hr',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _confirmDeleteAssignment(assignment),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAssignJudgeDialog(EventFloor floor, EventSession session) {
    context.push('/events/${widget.eventId}/floors/${floor.id}/assign-judge?sessionId=${session.id}');
  }

  Future<void> _confirmDeleteAssignment(JudgeAssignment assignment) async {
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

    if (confirm == true && mounted) {
      try {
        await JudgeAssignmentRepository().deleteAssignment(assignment.id);
        setState(() {}); // Refresh the view
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Judge removed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing judge: $e')),
          );
        }
      }
    }
  }

  void _showEventMenu(BuildContext context) {
    final eventAsync = ref.read(eventProvider(widget.eventId));
    final event = eventAsync.value;
    final isArchived = event?.status == EventStatus.archived;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isArchived)
            ListTile(
              leading: const Icon(Icons.unarchive),
              title: const Text('Unarchive Event'),
              onTap: () {
                Navigator.pop(context);
                _confirmUnarchiveEvent();
              },
            )
          else
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive Event'),
              onTap: () {
                Navigator.pop(context);
                _confirmArchiveEvent();
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Event', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteEvent();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchiveEvent() async {
    final eventAsync = ref.read(eventProvider(widget.eventId));
    final event = eventAsync.value;
    
    if (event == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Event'),
        content: Text('Archive "${event.name}"? You can unarchive it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repository = ref.read(eventRepositoryProvider);
        await repository.archiveEvent(widget.eventId);
        
        // Invalidate providers to refresh data
        ref.invalidate(filteredEventsProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(upcomingEventsProvider);
        
        if (mounted) {
          context.go('/events');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event archived successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error archiving event: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _confirmUnarchiveEvent() async {
    final eventAsync = ref.read(eventProvider(widget.eventId));
    final event = eventAsync.value;
    
    if (event == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unarchive Event'),
        content: Text('Unarchive "${event.name}"? It will be restored to the appropriate status.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repository = ref.read(eventRepositoryProvider);
        await repository.unarchiveEvent(widget.eventId);
        
        // Invalidate providers to refresh data
        ref.invalidate(filteredEventsProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(upcomingEventsProvider);
        ref.invalidate(eventProvider(widget.eventId));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event unarchived successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error unarchiving event: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteEvent() async {
    final eventAsync = ref.read(eventProvider(widget.eventId));
    final event = eventAsync.value;
    
    if (event == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permanently delete "${event.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'This will delete all associated data including:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('• Event days, sessions, and floors'),
            const Text('• Judge assignments'),
            const Text('• Fees and expenses'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
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

    if (confirm == true && mounted) {
      try {
        // Delete all related data
        final dayRepo = EventDayRepository();
        final sessionRepo = EventSessionRepository();
        final floorRepo = EventFloorRepository();
        final assignmentRepo = JudgeAssignmentRepository();
        
        // Get all days for this event
        final days = await dayRepo.getEventDaysByEventId(widget.eventId);
        
        // Delete all sessions, floors, and assignments
        for (final day in days) {
          final sessions = await sessionRepo.getEventSessionsByDayId(day.id);
          
          for (final session in sessions) {
            final floors = await floorRepo.getEventFloorsBySessionId(session.id);
            
            for (final floor in floors) {
              // Delete assignments for this floor
              final assignments = await assignmentRepo.getAssignmentsByFloorId(floor.id);
              for (final assignment in assignments) {
                await assignmentRepo.deleteAssignment(assignment.id);
              }
              
              // Delete floor
              await floorRepo.deleteEventFloor(floor.id);
            }
            
            // Delete session
            await sessionRepo.deleteEventSession(session.id);
          }
          
          // Delete day
          await dayRepo.deleteEventDay(day.id);
        }
        
        // Finally, delete the event itself
        final repository = ref.read(eventRepositoryProvider);
        await repository.deleteEvent(widget.eventId);
        
        // Invalidate providers to refresh data
        ref.invalidate(filteredEventsProvider);
        ref.invalidate(eventsProvider);
        ref.invalidate(upcomingEventsProvider);
        
        if (mounted) {
          context.go('/events');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting event: $e')),
          );
        }
      }
    }
  }
}
