import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/event_report.dart';
import '../../providers/report_provider.dart';

class EventReportDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventReportDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(eventReportProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Financial Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality coming soon')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pdf') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export coming soon')),
                );
              } else if (value == 'csv') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV export coming soon')),
                );
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
                _buildSummaryRow('Total Fees', report.totalFees, Colors.green),
                const Divider(),
                _buildSummaryRow('Total Expenses', report.totalExpenses, Colors.orange),
                const Divider(),
                _buildSummaryRow(
                  'Net Total',
                  report.netTotal,
                  report.netTotal >= 0 ? Colors.blue : Colors.red,
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
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 18 : 16,
              fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isLarge ? 20 : 16,
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
      child: ExpansionTile(
        title: Text(
          summary.judgeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text('Net: '),
            Text(
              '\$${summary.netTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: summary.netTotal >= 0 ? Colors.blue : Colors.red,
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
                    const Text('Total Fees:', style: TextStyle(fontSize: 16)),
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
                    const Text('Total Expenses:', style: TextStyle(fontSize: 16)),
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
              ],
            ),
          ),
        ],
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
}
