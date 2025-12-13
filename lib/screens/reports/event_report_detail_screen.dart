import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/event_report.dart';
import '../../models/event.dart';
import '../../providers/report_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/csv_service.dart';
import '../../repositories/judge_fee_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/judge_assignment_repository.dart';
import '../../repositories/event_day_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/event_floor_repository.dart';
import '../../widgets/charts/expense_pie_chart.dart';
import '../../widgets/charts/judge_earnings_bar_chart.dart';

class EventReportDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventReportDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventReportDetailScreen> createState() => _EventReportDetailScreenState();
}

class _EventReportDetailScreenState extends ConsumerState<EventReportDetailScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the report when the app resumes (e.g., after navigating back)
      ref.invalidate(eventReportProvider(widget.eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(eventReportProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Financial Report'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final report = reportAsync.value;
              if (report == null) return;
              
              if (value == 'pdf') {
                await _handlePdfExport(context, report);
              } else if (value == 'csv') {
                await _handleCsvExport(context, report);
              } else if (value == 'combined_invoices') {
                await _generateCombinedInvoices(context, ref, report);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'combined_invoices',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long),
                    SizedBox(width: 8),
                    Text('Combined Invoices PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) => _buildReportContent(context, report),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error generating report: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, EventReport report) {
    final dateFormat = DateFormat('MMMM d, yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Report Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.eventName ?? 'Event Report',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${dateFormat.format(report.startDate)} - ${dateFormat.format(report.endDate)}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generated: ${DateFormat('MMM d, yyyy h:mm a').format(report.generatedAt)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Financial Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Financial Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('Total Fees (for 1099s)', report.totalFees, Colors.green),
                const Divider(),
                _buildSummaryRow('Total Expenses (Reimbursable)', report.totalExpenses, Colors.orange),
                const Divider(),
                _buildSummaryRow(
                  'Total Payout (All Judges)',
                  report.totalOwed,
                  Colors.blue,
                  isLarge: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Judge Breakdowns
        if (report.judgeBreakdowns.isNotEmpty) ...[
          const Text(
            'Judge Breakdowns',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...report.judgeBreakdowns.values.map((summary) => _buildJudgeCard(summary)),
        ],
        const SizedBox(height: 24),

        // Visual Analytics
        const Text(
          'Visual Analytics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Judge Earnings Comparison
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Judge Earnings Comparison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                JudgeEarningsBarChart(report: report),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Expense Distribution
        if (report.expensesByCategory.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense Distribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ExpensePieChart(report: report),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Expense Breakdown
        if (report.expensesByCategory.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expense Breakdown by Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...report.expensesByCategory.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getCategoryDisplayName(entry.key),
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            '\$${entry.value.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color, {bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isLarge ? 17 : 15,
                fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isLarge ? 18 : 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgeCard(JudgeFinancialSummary summary) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Consumer(
        builder: (context, ref, child) {
          return ExpansionTile(
            title: Text(
              summary.judgeName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Text('Check Amount: '),
                Text(
                  '\$${summary.totalOwed.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Fees (1099):', style: TextStyle(fontSize: 16)),
                        Text(
                          '\$${summary.totalFees.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expenses (Reimbursable):', style: TextStyle(fontSize: 16)),
                        Text(
                          '\$${summary.totalExpenses.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '\$${summary.totalOwed.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    if (summary.expensesByCategory.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Expense Details:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...summary.expensesByCategory.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getCategoryDisplayName(entry.key),
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              ),
                              Text(
                                '\$${entry.value.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _generateJudgeInvoice(context, ref, summary),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Generate Invoice PDF'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getCategoryDisplayName(String categoryName) {
    switch (categoryName) {
      case 'mileage':
        return 'Mileage';
      case 'mealsPerDiem':
        return 'Meals & Per Diem';
      case 'lodging':
        return 'Lodging';
      case 'airfare':
        return 'Airfare';
      case 'parking':
        return 'Parking';
      case 'tolls':
        return 'Tolls';
      case 'transportation':
        return 'Transportation';
      case 'other':
        return 'Other';
      case 'judgeFees':
        return 'Judge Fees';
      default:
        return categoryName;
    }
  }

  Future<void> _handlePdfExport(BuildContext context, EventReport report) async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );

      print('[PDF] Starting PDF generation for ${report.eventName}');

      // Run PDF generation on background thread to avoid blocking UI
      final pdfService = PdfService();
      final file = await Future(() async {
        return await pdfService.generateEventReportPdf(report);
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('PDF generation timed out after 30 seconds'),
      );

      print('[PDF] PDF file created: ${file.path}');

      // Verify file exists and has content
      final stat = await file.stat();
      print('[PDF] File size: ${stat.size} bytes (${(stat.size / 1024 / 1024).toStringAsFixed(1)} MB)');
      
      if (stat.size <= 0) {
        throw Exception('Generated PDF file is empty.');
      }

      if (!context.mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('PDF ready (${(stat.size / 1024 / 1024).toStringAsFixed(1)} MB). Attempting to share...')),
      );

      // Brief delay to show the success message
      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;

      print('[PDF] Attempting Share.shareXFiles...');

      // Try to open share sheet
      final box = context.findRenderObject() as RenderBox?;
      print('[PDF] RenderBox: ${box != null ? "available" : "null"}');
      
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Event Financial Report - ${report.eventName}',
          sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
        print('[PDF] Share completed (user may have cancelled or saved)');
      } catch (shareError) {
        print('[PDF] Share error: $shareError');
        rethrow;
      }

      // After share attempt, show file location for reference
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to:\n${file.path}'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      print('[PDF] Export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleCsvExport(BuildContext context, EventReport report) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating CSV files...')),
      );

      final csvService = CsvService();
      final files = await csvService.generateEventReportCsvs(report);

      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        files.map((f) => XFile(f.path)).toList(),
        subject: 'Event Financial Report - ${report.eventName}',
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating CSV: $e')),
        );
      }
    }
  }

  Future<void> _handleShare(BuildContext context, EventReport report) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Report'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'pdf'),
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'csv'),
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (action == 'pdf') {
      await _handlePdfExport(context, report);
    } else if (action == 'csv') {
      await _handleCsvExport(context, report);
    }
  }

  Future<void> _generateJudgeInvoice(
    BuildContext context,
    WidgetRef ref,
    JudgeFinancialSummary summary,
  ) async {
    try {
      // Show loading
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating invoice...')),
      );

      // Get event
      final event = await ref.read(eventProvider(widget.eventId).future);
      if (event == null) throw Exception('Event not found');

      // Get judge assignment to get association and level
      final assignments = await JudgeAssignmentRepository().getAssignmentsByEventId(widget.eventId);
      final judgeAssignment = assignments.firstWhere(
        (a) => a.judgeId == summary.judgeId,
        orElse: () => throw Exception('Judge assignment not found'),
      );

      // Get judge fees - need to get the actual fee details
      final fees = await JudgeFeeRepository().getFeesForJudgeInEvent(
        judgeId: summary.judgeId,
        eventId: widget.eventId,
      );

      // Get expenses
      final expenses = await ExpenseRepository().getExpensesByJudgeAndEvent(
        judgeId: summary.judgeId,
        eventId: widget.eventId,
      );

      // Build a map of assignment ID to floor/session/day info for fee descriptions
      final assignmentInfoMap = <String, String>{};
      for (final assignment in assignments.where((a) => a.judgeId == summary.judgeId)) {
        final floor = await EventFloorRepository().getEventFloorById(assignment.eventFloorId);
        if (floor != null) {
          final session = await EventSessionRepository().getEventSessionById(floor.eventSessionId);
          if (session != null) {
            final day = await EventDayRepository().getEventDayById(session.eventDayId);
            if (day != null) {
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
        final locationInfo = assignmentInfoMap[fee.judgeAssignmentId] ?? '';
        // If we have location info (date, session, time, floor), use that as the description
        // Otherwise fall back to the fee description
        final fullDescription = locationInfo.isNotEmpty
            ? 'Session Fee: $locationInfo'
            : fee.description;
        
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
          'category': _formatExpenseCategory(expense.category.name),
          'description': expense.description,
          'amount': expense.amount,
        };
      }).toList();

      // Generate PDF
      final pdfService = PdfService();
      final file = await pdfService.generateJudgeInvoicePdf(
        judgeName: summary.judgeName,
        judgeAssociation: judgeAssignment.judgeAssociation,
        judgeLevel: judgeAssignment.judgeLevel,
        eventName: event.name,
        eventStartDate: event.startDate,
        eventEndDate: event.endDate,
        eventLocation: '${event.location.city}, ${event.location.state}',
        totalFees: summary.totalFees,
        totalExpenses: summary.totalExpenses,
        feeBreakdown: feeBreakdown,
        expenseBreakdown: expenseBreakdown,
      );

      if (!context.mounted) return;

      // Share the PDF - need to provide share position for iPad
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Invoice - ${summary.judgeName}',
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

  String _formatExpenseCategory(String category) {
    switch (category.toLowerCase()) {
      case 'mileage':
        return 'Mileage';
      case 'mealsperdiem':
        return 'Meals & Per Diem';
      case 'airfare':
        return 'Airfare';
      case 'transportation':
        return 'Transportation';
      case 'parking':
        return 'Parking';
      case 'tolls':
        return 'Tolls';
      case 'lodging':
        return 'Lodging';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  Future<void> _generateCombinedInvoices(
    BuildContext context,
    WidgetRef ref,
    EventReport report,
  ) async {
    try {
      if (!context.mounted) return;
      
      // Show loading dialog to keep UI responsive
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Generating PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Creating combined invoices...'),
              const SizedBox(height: 8),
              Text(
                '${report.judgeBreakdowns.length} judges',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

      // Get event
      final event = await ref.read(eventProvider(widget.eventId).future);
      if (event == null) throw Exception('Event not found');

      // Get event structure (days, sessions, floors)
      final eventStructure = <Map<String, dynamic>>[];
      final days = await EventDayRepository().getEventDaysByEventId(widget.eventId);
      final dateFormat = DateFormat('MMM d, yyyy');
      
      for (final day in days) {
        final sessions = await EventSessionRepository().getEventSessionsByDayId(day.id);
        final sessionData = <Map<String, dynamic>>[];
        
        for (final session in sessions) {
          final floors = await EventFloorRepository().getEventFloorsBySessionId(session.id);
          final floorData = <Map<String, dynamic>>[];
          
          for (final floor in floors) {
            // Get judge assignments for this floor
            final floorAssignments = await JudgeAssignmentRepository().getAssignmentsByFloorId(floor.id);
            floorData.add({
              'name': floor.name,
              'judges': floorAssignments.map((a) => {
                'name': a.judgeFullName,
                'role': a.role,
              }).toList(),
            });
          }
          
          sessionData.add({
            'name': session.name,
            'floors': floorData,
          });
        }
        
        eventStructure.add({
          'name': 'Day ${day.dayNumber}',
          'date': dateFormat.format(day.date),
          'sessions': sessionData,
        });
      }

      // Build invoice data for each judge
      final judgeInvoices = <Map<String, dynamic>>[];
      
      for (final summary in report.judgeBreakdowns.values) {
        // Get judge assignment
        final assignments = await JudgeAssignmentRepository().getAssignmentsByEventId(widget.eventId);
        final judgeAssignment = assignments.firstWhere(
          (a) => a.judgeId == summary.judgeId,
          orElse: () => throw Exception('Judge assignment not found for ${summary.judgeName}'),
        );

        // Get judge fees
        final fees = await JudgeFeeRepository().getFeesForJudgeInEvent(
          judgeId: summary.judgeId,
          eventId: widget.eventId,
        );

        // Get expenses
        final expenses = await ExpenseRepository().getExpensesByJudgeAndEvent(
          judgeId: summary.judgeId,
          eventId: widget.eventId,
        );

        // Build a map of assignment ID to floor/session/day info for fee descriptions
        final assignmentInfoMap = <String, String>{};
        final timeFormat = DateFormat('h:mm a');
        for (final assignment in assignments.where((a) => a.judgeId == summary.judgeId)) {
          final floor = await EventFloorRepository().getEventFloorById(assignment.eventFloorId);
          if (floor != null) {
            final session = await EventSessionRepository().getEventSessionById(floor.eventSessionId);
            if (session != null) {
              final day = await EventDayRepository().getEventDayById(session.eventDayId);
              if (day != null) {
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
            'category': _formatExpenseCategory(expense.category.name),
            'description': expense.description,
            'amount': expense.amount,
          };
        }).toList();

        judgeInvoices.add({
          'judgeName': summary.judgeName,
          'judgeAssociation': judgeAssignment.judgeAssociation,
          'judgeLevel': judgeAssignment.judgeLevel,
          'totalFees': summary.totalFees,
          'totalExpenses': summary.totalExpenses,
          'feeBreakdown': feeBreakdown,
          'expenseBreakdown': expenseBreakdown,
        });
      }

      // Sort judges by name
      judgeInvoices.sort((a, b) => (a['judgeName'] as String).compareTo(b['judgeName'] as String));

      // Generate combined PDF
      final pdfService = PdfService();
      print('[COMBINED] Starting PDF generation with ${judgeInvoices.length} judges');
      
      final file = await Future(() async {
        return await pdfService.generateCombinedInvoicesPdf(
          eventName: event.name,
          eventStartDate: event.startDate,
          eventEndDate: event.endDate,
          eventLocation: '${event.location.city}, ${event.location.state}',
          totalFees: report.totalFees,
          totalExpenses: report.totalExpenses,
          judgeInvoices: judgeInvoices,
          report: report,
          eventStructure: eventStructure,
        );
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Combined PDF generation timed out after 60 seconds'),
      );

      print('[COMBINED] PDF file created: ${file.path}');
      final stat = await file.stat();
      print('[COMBINED] File size: ${stat.size} bytes (${(stat.size / 1024 / 1024).toStringAsFixed(1)} MB)');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF ready (${(stat.size / 1024 / 1024).toStringAsFixed(1)} MB). Sharing...')),
      );

      await Future.delayed(const Duration(milliseconds: 300));

      if (!context.mounted) return;

      print('[COMBINED] Attempting to open PDF for printing/sharing...');
      
      if (!context.mounted) return;
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Use Printing.sharePdf which works reliably on all platforms including simulator
      try {
        final pdfBytes = await file.readAsBytes();
        if (context.mounted) {
          await Printing.sharePdf(
            bytes: pdfBytes,
            filename: 'combined_invoices_${event.name}.pdf',
          );
          print('[COMBINED] PDF opened for printing/sharing');
        }
      } catch (printError) {
        print('[COMBINED] Printing open error: $printError');
        // If that fails, just show the file path
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved: ${file.path}'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog if still open
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating combined invoices: $e')),
        );
      }
    }
  }
}
