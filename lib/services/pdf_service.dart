import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/event_report.dart';

class PdfService {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy h:mm a');

  /// Generate a PDF report for an event
  Future<File> generateEventReportPdf(EventReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(report),
            pw.SizedBox(height: 20),
            _buildFinancialSummary(report),
            pw.SizedBox(height: 20),
            _buildJudgeBreakdownTable(report),
            pw.SizedBox(height: 20),
            _buildExpenseBreakdown(report),
            pw.SizedBox(height: 30),
            _buildFooter(report),
          ];
        },
      ),
    );

    return _savePdf(pdf, report);
  }

  pw.Widget _buildHeader(EventReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'NAWGJ',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Event Financial Report',
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated:',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  _dateTimeFormat.format(report.generatedAt),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 10),
        pw.Text(
          report.eventName ?? 'Unknown Event',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          '${_dateFormat.format(report.startDate)} - ${_dateFormat.format(report.endDate)}',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFinancialSummary(EventReport report) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Financial Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          _buildSummaryRow('Total Fees (for 1099s)', report.totalFees, PdfColors.green),
          pw.Divider(),
          _buildSummaryRow('Total Expenses (Reimbursable)', report.totalExpenses, PdfColors.orange),
          pw.Divider(thickness: 2),
          _buildSummaryRow(
            'Total Payout (All Judges)',
            report.totalOwed,
            PdfColors.blue,
            isBold: true,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, double amount, PdfColor color, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '\$${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: isBold ? 16 : 12,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildJudgeBreakdownTable(EventReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Judge Breakdown',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Judge Name', isHeader: true),
                _buildTableCell('Fees (1099)', isHeader: true),
                _buildTableCell('Expenses', isHeader: true),
                _buildTableCell('Check Amount', isHeader: true),
              ],
            ),
            // Data rows
            ...report.judgeBreakdowns.values.map((summary) {
              return pw.TableRow(
                children: [
                  _buildTableCell(summary.judgeName),
                  _buildTableCell('\$${summary.totalFees.toStringAsFixed(2)}'),
                  _buildTableCell('\$${summary.totalExpenses.toStringAsFixed(2)}'),
                  _buildTableCell(
                    '\$${summary.totalOwed.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                ],
              );
            }).toList(),
            // Totals row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('TOTAL', isBold: true),
                _buildTableCell('\$${report.totalFees.toStringAsFixed(2)}', isBold: true),
                _buildTableCell('\$${report.totalExpenses.toStringAsFixed(2)}', isBold: true),
                _buildTableCell('\$${report.totalOwed.toStringAsFixed(2)}', isBold: true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildExpenseBreakdown(EventReport report) {
    if (report.expensesByCategory.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Expense Breakdown by Category',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Category', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
              ],
            ),
            // Data rows
            ...report.expensesByCategory.entries.map((entry) {
              return pw.TableRow(
                children: [
                  _buildTableCell(_getCategoryDisplayName(entry.key)),
                  _buildTableCell('\$${entry.value.toStringAsFixed(2)}'),
                ],
              );
            }).toList(),
            // Total row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('TOTAL', isBold: true),
                _buildTableCell('\$${report.totalExpenses.toStringAsFixed(2)}', isBold: true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter(EventReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Meet Director Signature:', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),
                pw.Container(
                  width: 200,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 1)),
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Date:', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),
                pw.Container(
                  width: 100,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 1)),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'This report summarizes all fees and expenses for the event. Each judge should receive a check for the amount listed in the "Check Amount" column. 1099 forms should be filed for the amounts listed in the "Fees (1099)" column.',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          textAlign: pw.TextAlign.justify,
        ),
      ],
    );
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

  Future<File> _savePdf(pw.Document pdf, EventReport report) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'event_report_${report.eventId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
