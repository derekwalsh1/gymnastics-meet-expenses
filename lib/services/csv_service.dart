import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/event_report.dart';

class CsvService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Generate CSV files for an event report
  /// Returns a list of File objects [feesFile, expensesFile]
  Future<List<File>> generateEventReportCsvs(EventReport report) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Generate fees CSV
    final feesFile = await _generateFeesCsv(report, directory, timestamp);
    
    // Generate expenses CSV
    final expensesFile = await _generateExpensesCsv(report, directory, timestamp);
    
    return [feesFile, expensesFile];
  }

  Future<File> _generateFeesCsv(EventReport report, Directory directory, int timestamp) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln(_escapeCsvRow([
      'Event',
      'Judge Name',
      'Total Fees (1099 Amount)',
      'Total Expenses',
      'Check Amount',
      'Generated Date',
    ]));
    
    // Data rows
    for (final summary in report.judgeBreakdowns.values) {
      buffer.writeln(_escapeCsvRow([
        report.eventName ?? '',
        summary.judgeName,
        summary.totalFees.toStringAsFixed(2),
        summary.totalExpenses.toStringAsFixed(2),
        summary.totalOwed.toStringAsFixed(2),
        _dateFormat.format(report.generatedAt),
      ]));
    }
    
    // Totals row
    buffer.writeln(_escapeCsvRow([
      '',
      'TOTAL',
      report.totalFees.toStringAsFixed(2),
      report.totalExpenses.toStringAsFixed(2),
      report.totalOwed.toStringAsFixed(2),
      '',
    ]));
    
    final fileName = 'fees_${report.eventId}_$timestamp.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(buffer.toString());
    return file;
  }

  Future<File> _generateExpensesCsv(EventReport report, Directory directory, int timestamp) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln(_escapeCsvRow([
      'Event',
      'Judge Name',
      'Category',
      'Amount',
      'Generated Date',
    ]));
    
    // Data rows - one row per judge per category
    for (final summary in report.judgeBreakdowns.values) {
      for (final categoryEntry in summary.expensesByCategory.entries) {
        buffer.writeln(_escapeCsvRow([
          report.eventName ?? '',
          summary.judgeName,
          _getCategoryDisplayName(categoryEntry.key),
          categoryEntry.value.toStringAsFixed(2),
          _dateFormat.format(report.generatedAt),
        ]));
      }
    }
    
    final fileName = 'expenses_${report.eventId}_$timestamp.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(buffer.toString());
    return file;
  }

  String _escapeCsvRow(List<String> fields) {
    return fields.map((field) => _escapeCsvField(field)).join(',');
  }

  String _escapeCsvField(String field) {
    // If field contains comma, quote, or newline, wrap in quotes and escape quotes
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'airfare':
        return 'Airfare';
      case 'mileage':
        return 'Mileage';
      case 'parking':
        return 'Parking';
      case 'mealsAndPerDiem':
        return 'Meals & Per Diem';
      case 'lodging':
        return 'Lodging';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }
}
