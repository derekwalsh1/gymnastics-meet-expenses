import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../providers/report_provider.dart';

class ReportsListScreen extends ConsumerStatefulWidget {
  const ReportsListScreen({super.key});

  @override
  ConsumerState<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends ConsumerState<ReportsListScreen> {
  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No events available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create an event to generate reports',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Generate Reports',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select an event to view its financial summary',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ...events.map((event) => _buildEventCard(event)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading events: $error'),
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final startDate = dateFormat.format(event.startDate);
    final endDate = dateFormat.format(event.endDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/reports/event/${event.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$startDate - $endDate',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.location.city,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(event.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(event.status)),
                    ),
                    child: Text(
                      _getStatusText(event.status),
                      style: TextStyle(
                        color: _getStatusColor(event.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, child) {
                  final summaryAsync = ref.watch(financialSummaryProvider(event.id));
                  
                  return summaryAsync.when(
                    data: (summary) => Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItem(
                            '1099 Amount',
                            '\$${summary.totalFees.toStringAsFixed(2)}',
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Expenses',
                            '\$${summary.totalExpenses.toStringAsFixed(2)}',
                            Colors.orange,
                          ),
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Total Owed',
                            '\$${summary.totalOwed.toStringAsFixed(2)}',
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const Text(
                      'Error loading summary',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Colors.blue;
      case EventStatus.ongoing:
        return Colors.green;
      case EventStatus.completed:
        return Colors.grey;
      case EventStatus.archived:
        return Colors.blueGrey;
    }
  }

  String _getStatusText(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return 'UPCOMING';
      case EventStatus.ongoing:
        return 'ONGOING';
      case EventStatus.completed:
        return 'COMPLETED';
      case EventStatus.archived:
        return 'ARCHIVED';
    }
  }
}
