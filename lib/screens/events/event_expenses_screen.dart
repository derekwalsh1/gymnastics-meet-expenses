import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/judge_assignment.dart';
import '../../models/expense.dart';
import '../../models/judge_fee.dart';
import '../../providers/event_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../repositories/judge_assignment_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/judge_fee_repository.dart';
import '../../repositories/event_day_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/event_floor_repository.dart';
import '../../services/pdf_service.dart';

class EventExpensesScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventExpensesScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventExpensesScreen> createState() => _EventExpensesScreenState();
}

class _EventExpensesScreenState extends ConsumerState<EventExpensesScreen> {
  String? _expandedJudgeId;

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Expenses'),
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found'));
          }
          return _buildExpensesSection(context, ref);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading event: $error'),
        ),
      ),
    );
  }

  Widget _buildExpensesSection(BuildContext context, WidgetRef ref) {
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
                      'No judges assigned to this event yet.\nAssign judges from the Structure section.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              ...judges.map((judge) => _buildJudgeExpenseCard(context, ref, judge)),
          ],
        );
      },
    );
  }

  Widget _buildJudgeExpenseCard(BuildContext context, WidgetRef ref, JudgeAssignment judge) {
    final totalAsync = ref.watch(totalExpensesByJudgeAndEventProvider((
      judgeId: judge.judgeId,
      eventId: widget.eventId,
    )));
    final expensesAsync = ref.watch(expensesByJudgeAndEventProvider((
      judgeId: judge.judgeId,
      eventId: widget.eventId,
    )));
    final isExpanded = _expandedJudgeId == judge.judgeId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedJudgeId = isExpanded ? null : judge.judgeId;
              });
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
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  expensesAsync.when(
                    data: (expenses) {
                      if (expenses.isEmpty && !isExpanded) {
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
                      if (!isExpanded) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${expenses.length} expense${expenses.length != 1 ? 's' : ''} • Tap to expand',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _generateJudgeInvoice(context, ref, judge),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Generate Invoice PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.push('/expenses?eventId=${widget.eventId}&judgeId=${judge.judgeId}');
                        },
                        icon: const Icon(Icons.list),
                        label: const Text('View All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateJudgeInvoice(BuildContext context, WidgetRef ref, JudgeAssignment judge) async {
    try {
      // Show loading
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating invoice...')),
      );

      // Get event
      final event = await ref.read(eventProvider(widget.eventId).future);
      if (event == null) throw Exception('Event not found');

      // Get judge fees
      final fees = await JudgeFeeRepository().getFeesForJudgeInEvent(
        judgeId: judge.judgeId,
        eventId: widget.eventId,
      );
      final totalFees = fees.fold(0.0, (sum, fee) => sum + fee.amount);

      // Get expenses
      final expenses = await ExpenseRepository().getExpensesByJudgeAndEvent(
        judgeId: judge.judgeId,
        eventId: widget.eventId,
      );
      final totalExpenses = expenses.fold(0.0, (sum, expense) => sum + expense.amount);

      // Get all assignments for this judge to build fee descriptions
      final assignments = await JudgeAssignmentRepository().getAssignmentsByEventId(widget.eventId);
      
      // Build a map of assignment ID to floor/session/day info for fee descriptions
      final assignmentInfoMap = <String, String>{};
      for (final assignment in assignments.where((a) => a.judgeId == judge.judgeId)) {
        final floor = await EventFloorRepository().getEventFloorById(assignment.eventFloorId);
        if (floor != null) {
          final session = await EventSessionRepository().getEventSessionById(floor.eventSessionId);
          if (session != null) {
            final day = await EventDayRepository().getEventDayById(session.eventDayId);
            if (day != null && context.mounted) {
              final dayDateStr = DateFormat('MMM d, yyyy').format(day.date);
              final startTimeStr = session.startTime.format(context);
              final endTimeStr = session.endTime.format(context);
              assignmentInfoMap[assignment.id] = '$dayDateStr ${session.name} ($startTimeStr - $endTimeStr) - ${floor.name}';
            }
          }
        }
      }

      // Prepare fee breakdown with enhanced descriptions
      final feeBreakdown = fees.map((fee) {
        final baseDescription = fee.description.isNotEmpty ? fee.description : '';
        final locationInfo = assignmentInfoMap[fee.judgeAssignmentId] ?? '';
        final fullDescription = locationInfo.isNotEmpty
            ? (baseDescription.isNotEmpty ? '$baseDescription - $locationInfo' : locationInfo)
            : baseDescription;
        
        return {
          'description': fullDescription,
          'amount': fee.amount,
        };
      }).toList();

      // Prepare expense breakdown
      final dateFormat = DateFormat('MMM d, yyyy');
      final expenseBreakdown = expenses.map((expense) {
        return {
          'date': dateFormat.format(expense.date),
          'category': _formatCategory(expense.category.name),
          'description': expense.description,
          'amount': expense.amount,
        };
      }).toList();

      // Generate PDF
      final pdfService = PdfService();
      final file = await pdfService.generateJudgeInvoicePdf(
        judgeName: judge.judgeFullName,
        judgeAssociation: judge.judgeAssociation,
        judgeLevel: judge.judgeLevel,
        eventName: event.name,
        eventStartDate: event.startDate,
        eventEndDate: event.endDate,
        eventLocation: '${event.location.city}, ${event.location.state}',
        totalFees: totalFees,
        totalExpenses: totalExpenses,
        feeBreakdown: feeBreakdown,
        expenseBreakdown: expenseBreakdown,
      );

      if (!context.mounted) return;
      
      // Share the PDF - need to provide share position for iPad
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Invoice - ${judge.judgeFullName}',
        text: 'Invoice for ${event.name}',
        sharePositionOrigin: box != null 
            ? box.localToGlobal(Offset.zero) & box.size 
            : null,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice generated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    }
  }

  String _formatCategory(String category) {
    switch (category.toLowerCase()) {
      case 'mileage':
        return 'Mileage';
      case 'meals':
        return 'Meals';
      case 'lodging':
        return 'Lodging';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }
}
