import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../models/event_day.dart';
import '../../models/event_session.dart';
import '../../models/event_floor.dart';
import '../../models/judge_assignment.dart';
import '../../models/expense.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_assignment_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../providers/expense_provider.dart';
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
  final Set<String> _expandedDays = {};
  final Set<String> _expandedSessions = {};
  int _selectedTabIndex = 0;

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
            onPressed: () => context.push('/events/${widget.eventId}/edit'),
            tooltip: 'Edit Event',
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
    return Column(
      children: [
        _buildEventHeader(event),
        const Divider(height: 1),
        _buildEventInfo(event),
        const Divider(height: 1),
        _buildTabButtons(),
        const Divider(height: 1),
        Expanded(
          child: _selectedTabIndex == 0
              ? _buildEventStructure(event)
              : _buildExpensesSection(event),
        ),
      ],
    );
  }

  Widget _buildTabButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              icon: Icons.account_tree,
              label: 'Structure & Fees',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTabButton(
              index: 1,
              icon: Icons.receipt_long,
              label: 'Expenses',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).primaryColor : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : null,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : null,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildExpensesSection(Event event) {
    return FutureBuilder<List<JudgeAssignment>>(
      future: JudgeAssignmentRepository().getAssignmentsByEventId(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final assignments = snapshot.data ?? [];
        
        // Get unique judges
        final judgeMap = <String, JudgeAssignment>{};
        for (final assignment in assignments) {
          judgeMap[assignment.judgeId] = assignment;
        }
        final judges = judgeMap.values.toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Judge Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'View and manage expenses for each judge',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (judges.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No judges assigned to this event yet.\nAssign judges from the Structure & Fees tab.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ...judges.map((judge) => _buildJudgeExpenseCard(judge)),
          ],
        );
      },
    );
  }

  Widget _buildJudgeExpenseCard(JudgeAssignment judge) {
    final totalAsync = ref.watch(totalExpensesByJudgeAndEventProvider((
      judgeId: judge.judgeId,
      eventId: widget.eventId,
    )));
    final expensesAsync = ref.watch(expensesByJudgeAndEventProvider((
      judgeId: judge.judgeId,
      eventId: widget.eventId,
    )));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/expenses?eventId=${widget.eventId}&judgeId=${judge.judgeId}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      judge.judgeFirstName[0] + judge.judgeLastName[0],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judge.judgeFullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${judge.judgeAssociation} - ${judge.judgeLevel}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  totalAsync.when(
                    data: (total) => Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: total > 0 ? Colors.orange.shade700 : Colors.grey,
                          ),
                        ),
                        const Text(
                          'expenses',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const Icon(Icons.error_outline, color: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              expensesAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No expenses recorded',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${expenses.length} expense${expenses.length != 1 ? 's' : ''} • Tap to view details',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
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

        return ListView(
          padding: const EdgeInsets.all(16),
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
                    onPressed: () => _showAddDayDialog(event, days.length),
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
                ...days.map((day) => _buildDayCard(day, event)),
            ],
        );
      },
    );
  }

  Widget _buildDayCard(EventDay day, Event event) {
    final dateFormat = DateFormat('EEEE, MMM d');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        key: PageStorageKey<String>('day_${day.id}'),
        initiallyExpanded: _expandedDays.contains(day.id),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedDays.add(day.id);
            } else {
              _expandedDays.remove(day.id);
            }
          });
        },
        title: Row(
          children: [
            Text(
              'Day ${day.dayNumber}: ${dateFormat.format(day.date)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Consumer(
              builder: (context, ref, child) {
                final totalAsync = ref.watch(totalFeesForDayProvider(day.id));
                return totalAsync.when(
                  data: (total) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300, width: 1),
                    ),
                    child: Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, stack) => const SizedBox.shrink(),
                );
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _confirmDeleteDay(day, event),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
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
                        onPressed: () => _showAddSessionDialog(day, 1),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  ...sessions.map((session) => _buildSessionCard(session)),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Session', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showAddSessionDialog(day, sessions.length + 1),
                    ),
                  ),
                ],
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
        key: PageStorageKey<String>('session_${session.id}'),
        initiallyExpanded: _expandedSessions.contains(session.id),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedSessions.add(session.id);
            } else {
              _expandedSessions.remove(session.id);
            }
          });
        },
        title: Row(
          children: [
            Text(session.name),
            const SizedBox(width: 8),
            Consumer(
              builder: (context, ref, child) {
                final totalAsync = ref.watch(totalFeesForSessionProvider(session.id));
                return totalAsync.when(
                  data: (total) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300, width: 1),
                    ),
                    child: Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, stack) => const SizedBox.shrink(),
                );
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _confirmDeleteSession(session),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
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
                        onPressed: () => _showAddFloorDialog(session, 1),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  ...floors.map((floor) => _buildFloorCard(floor, session)),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Floor', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showAddFloorDialog(session, floors.length + 1),
                    ),
                  ),
                ],
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
            title: Row(
              children: [
                Text(
                  floor.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final totalAsync = ref.watch(totalFeesForFloorProvider(floor.id));
                    return totalAsync.when(
                      data: (total) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300, width: 1),
                        ),
                        child: Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (e, stack) => const SizedBox.shrink(),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () => _showAssignJudgeDialog(floor, session),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _confirmDeleteFloor(floor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              final assignmentsAsync = ref.watch(assignmentsByFloorProvider(floor.id));
              
              return assignmentsAsync.when(
                data: (assignments) {
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
                    children: assignments.map((assignment) {
                      return Consumer(
                        builder: (context, ref, child) {
                          final totalFeesAsync = ref.watch(totalFeesByAssignmentProvider(assignment.id));
                          final feesAsync = ref.watch(feesByAssignmentProvider(assignment.id));
                          
                          return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                              Text(assignment.judgeFullName),
                              const SizedBox(width: 8),
                              totalFeesAsync.when(
                                data: (total) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade300, width: 1),
                                  ),
                                  child: Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade900,
                                    ),
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
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${assignment.hourlyRate.toStringAsFixed(2)}/hr',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                              // Show role-based fees
                              feesAsync.when(
                                data: (fees) {
                                  final roleFees = fees.where((f) => !f.isAutoCalculated).toList();
                                  if (roleFees.isEmpty) return const SizedBox.shrink();
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: roleFees.map((fee) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: Text(
                                          '${fee.description}: \$${fee.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )).toList(),
                                    ),
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => context.push('/assignments/${assignment.id}/edit?floorId=${floor.id}&sessionId=${session.id}'),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      minimumSize: const Size(0, 28),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () => context.push('/assignments/${assignment.id}/fees?judgeName=${Uri.encodeComponent(assignment.judgeFullName)}'),
                                    icon: const Icon(Icons.attach_money, size: 16),
                                    label: const Text('Fees', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      minimumSize: const Size(0, 28),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _confirmDeleteAssignment(assignment, floor, session),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                }).toList(),
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
    );
  }

  void _showAssignJudgeDialog(EventFloor floor, EventSession session) {
    context.push('/events/${widget.eventId}/floors/${floor.id}/assign-judge?sessionId=${session.id}');
  }

  Future<void> _confirmDeleteAssignment(
    JudgeAssignment assignment,
    EventFloor floor,
    EventSession session,
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

    if (confirm == true && mounted) {
      try {
        await JudgeAssignmentRepository().deleteAssignment(assignment.id);
        
        // Invalidate providers to refresh the UI
        ref.invalidate(assignmentsByFloorProvider(floor.id));
        ref.invalidate(availableJudgesForSessionProvider(session.id));
        
        // Invalidate fee totals
        ref.invalidate(totalFeesForFloorProvider(floor.id));
        ref.invalidate(totalFeesForSessionProvider(session.id));
        ref.invalidate(totalFeesForDayProvider(session.eventDayId));
        
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

  Future<void> _showAddDayDialog(Event event, int currentDayCount) async {
    DateTime selectedDate = event.startDate.add(Duration(days: currentDayCount));
    final dateController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          dateController.text = DateFormat('MMM d, yyyy').format(selectedDate);
          
          return AlertDialog(
            title: Text('Add Day ${currentDayCount + 1}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: event.startDate,
                        lastDate: event.endDate,
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Competition Day, Practice Day',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Day'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      try {
        // Create the day
        final newDay = await EventDayRepository().createEventDay(
          eventId: event.id,
          dayNumber: currentDayCount + 1,
          date: selectedDate,
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        // Create a default session for the day
        final sessionRepo = EventSessionRepository();
        final newSession = await sessionRepo.createEventSession(
          eventDayId: newDay.id,
          sessionNumber: 1,
          name: 'Session 1',
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
          notes: null,
        );

        // Create a default floor for the session
        await EventFloorRepository().createEventFloor(
          eventSessionId: newSession.id,
          floorNumber: 1,
          name: 'Floor 1',
          notes: null,
        );

        if (mounted) {
          setState(() {}); // Refresh the day list
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Day ${currentDayCount + 1} added with default session and floor')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding day: $e')),
          );
        }
      }
    }

    dateController.dispose();
    notesController.dispose();
  }

  Future<void> _showAddSessionDialog(EventDay day, int sessionNumber) async {
    final nameController = TextEditingController(text: 'Session $sessionNumber');
    final notesController = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Session to Day ${day.dayNumber}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Session Name',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Morning Session, Competition',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Time'),
                    subtitle: Text(startTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (picked != null) {
                        setState(() {
                          startTime = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Time'),
                    subtitle: Text(endTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (picked != null) {
                        setState(() {
                          endTime = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Session'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      try {
        // Create the session
        final sessionRepo = EventSessionRepository();
        final newSession = await sessionRepo.createEventSession(
          eventDayId: day.id,
          sessionNumber: sessionNumber,
          name: nameController.text.trim(),
          startTime: startTime,
          endTime: endTime,
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        // Create a default floor for the session
        await EventFloorRepository().createEventFloor(
          eventSessionId: newSession.id,
          floorNumber: 1,
          name: 'Floor 1',
          notes: null,
        );

        if (mounted) {
          setState(() {}); // Refresh the session list
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${nameController.text} added with Floor 1')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding session: $e')),
          );
        }
      }
    }

    nameController.dispose();
    notesController.dispose();
  }

  Future<void> _showAddFloorDialog(EventSession session, int floorNumber) async {
    final nameController = TextEditingController(text: 'Floor $floorNumber');
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Floor to ${session.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Floor Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Floor 1, Vault Area',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Equipment setup notes',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add Floor'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await EventFloorRepository().createEventFloor(
          eventSessionId: session.id,
          floorNumber: floorNumber,
          name: nameController.text.trim(),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        if (mounted) {
          setState(() {}); // Refresh the floor list
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${nameController.text} added to ${session.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding floor: $e')),
          );
        }
      }
    }

    nameController.dispose();
    notesController.dispose();
  }

  Future<void> _confirmDeleteDay(EventDay day, Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Day'),
        content: Text(
          'Delete Day ${day.dayNumber}?\n\nThis will also delete all sessions, floors, and judge assignments for this day.',
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
        final dayRepo = EventDayRepository();
        final eventRepo = ref.read(eventRepositoryProvider);
        
        // Get all event days to handle renumbering
        final allDays = await dayRepo.getEventDaysByEventId(day.eventId);
        final deletedDayNumber = day.dayNumber;
        
        // Delete the day
        await dayRepo.deleteEventDay(day.id);
        
        // Renumber and update dates for all subsequent days
        for (final otherDay in allDays) {
          if (otherDay.dayNumber > deletedDayNumber) {
            final newDayNumber = otherDay.dayNumber - 1;
            final newDate = event.startDate.add(Duration(days: newDayNumber - 1));
            
            final updatedDay = otherDay.copyWith(
              dayNumber: newDayNumber,
              date: newDate,
              updatedAt: DateTime.now(),
            );
            
            await dayRepo.updateEventDay(updatedDay);
          }
        }
        
        // Recalculate and update event end date
        final remainingDayCount = allDays.length - 1;
        if (remainingDayCount > 0) {
          final newEndDate = event.startDate.add(Duration(days: remainingDayCount - 1));
          final updatedEvent = event.copyWith(
            endDate: newEndDate,
            updatedAt: DateTime.now(),
          );
          await eventRepo.updateEvent(updatedEvent);
          
          // Invalidate providers to refresh
          ref.invalidate(eventProvider(widget.eventId));
        }
        
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Day ${day.dayNumber} deleted and schedule updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting day: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteSession(EventSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Delete ${session.name}?\n\nThis will also delete all floors and judge assignments for this session.',
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
        await EventSessionRepository().deleteEventSession(session.id);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${session.name} deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting session: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteFloor(EventFloor floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Floor'),
        content: Text(
          'Delete ${floor.name}?\n\nThis will also delete all judge assignments for this floor.',
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
        await EventFloorRepository().deleteEventFloor(floor.id);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${floor.name} deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting floor: $e')),
          );
        }
      }
    }
  }

  IconData _getExpenseIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.mileage:
        return Icons.directions_car;
      case ExpenseCategory.mealsPerDiem:
        return Icons.restaurant;
      case ExpenseCategory.lodging:
        return Icons.hotel;
      case ExpenseCategory.airfare:
        return Icons.flight;
      case ExpenseCategory.parking:
        return Icons.local_parking;
      case ExpenseCategory.tolls:
        return Icons.toll;
      case ExpenseCategory.transportation:
        return Icons.directions_bus;
      case ExpenseCategory.other:
        return Icons.more_horiz;
      case ExpenseCategory.judgeFees:
        return Icons.attach_money;
    }
  }

  String _getExpenseCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.mileage:
        return 'Mileage';
      case ExpenseCategory.mealsPerDiem:
        return 'Meals & Per Diem';
      case ExpenseCategory.lodging:
        return 'Lodging';
      case ExpenseCategory.airfare:
        return 'Airfare';
      case ExpenseCategory.parking:
        return 'Parking';
      case ExpenseCategory.tolls:
        return 'Tolls';
      case ExpenseCategory.transportation:
        return 'Transportation';
      case ExpenseCategory.other:
        return 'Other';
      case ExpenseCategory.judgeFees:
        return 'Judge Fees';
    }
  }
}
