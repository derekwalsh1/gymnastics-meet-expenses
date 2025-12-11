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
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              _buildHeader(report),
              pw.SizedBox(height: 14),
              _buildFinancialSummary(report),
              pw.SizedBox(height: 14),
              _buildJudgeBreakdownTable(report),
              pw.SizedBox(height: 14),
              _buildExpenseBreakdown(report),
              pw.SizedBox(height: 20),
              _buildFooter(report),
            ];
          },
        ),
      );

      final file = await _savePdf(pdf, report);
      return file;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Unexpected error generating report PDF: $e');
    }
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
                  'Gymnastics Judging',
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
    const judgesPerPage = 30; // Optimized for large meets: 30 judges per table chunk
    final allJudges = report.judgeBreakdowns.values.toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Judge Breakdown',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        
        // Split judges into chunks to avoid too many table rows
        ...List.generate((allJudges.length / judgesPerPage).ceil(), (chunkIndex) {
          final start = chunkIndex * judgesPerPage;
          final end = (start + judgesPerPage).clamp(0, allJudges.length);
          final judgesChunk = allJudges.sublist(start, end);
          final isLastChunk = end == allJudges.length;
          
          return pw.Column(
            children: [
              if (chunkIndex > 0) pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header row (only on first chunk)
                  if (chunkIndex == 0)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Judge Name', isHeader: true),
                        _buildTableCell('Fees (1099)', isHeader: true),
                        _buildTableCell('Expenses', isHeader: true),
                        _buildTableCell('Check Amount', isHeader: true),
                      ],
                    ),
                  // Data rows for this chunk
                  ...judgesChunk.map((summary) {
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
                  // Totals row (only on last chunk)
                  if (isLastChunk)
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
        }),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
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
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
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
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'event_report_${report.eventId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      
      final pdfBytes = await pdf.save();
      if (pdfBytes.isEmpty) {
        throw Exception('PDF byte stream is empty after generation.');
      }
      
      await file.writeAsBytes(pdfBytes);
      
      final stat = await file.stat();
      if (stat.size == 0) {
        throw Exception('PDF file written but size is 0 bytes.');
      }
      
      return file;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Generate a PDF invoice for a specific judge
  Future<File> generateJudgeInvoicePdf({
    required String judgeName,
    required String judgeAssociation,
    required String judgeLevel,
    required String eventName,
    required DateTime eventStartDate,
    required DateTime eventEndDate,
    required String eventLocation,
    required double totalFees,
    required double totalExpenses,
    required List<Map<String, dynamic>> feeBreakdown,
    required List<Map<String, dynamic>> expenseBreakdown,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildInvoiceHeader(
              judgeName: judgeName,
              judgeAssociation: judgeAssociation,
              judgeLevel: judgeLevel,
            ),
              pw.SizedBox(height: 14),
            _buildInvoiceEventInfo(
              eventName: eventName,
              eventStartDate: eventStartDate,
              eventEndDate: eventEndDate,
              eventLocation: eventLocation,
            ),
              pw.SizedBox(height: 14),
            _buildInvoiceFeesSection(feeBreakdown, totalFees),
              pw.SizedBox(height: 14),
            _buildInvoiceExpensesSection(expenseBreakdown, totalExpenses),
              pw.SizedBox(height: 14),
            _buildInvoiceTotalSection(totalFees, totalExpenses),
              pw.SizedBox(height: 20),
            _buildInvoiceFooter(),
          ];
        },
      ),
    );

    return _saveJudgeInvoicePdf(pdf, judgeName);
  }

  pw.Widget _buildInvoiceHeader({
    required String judgeName,
    required String judgeAssociation,
    required String judgeLevel,
  }) {
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
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                  pw.SizedBox(height: 3),
                pw.Text(
                  judgeName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '$judgeAssociation - $judgeLevel',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Date:',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  _dateFormat.format(DateTime.now()),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
          pw.SizedBox(height: 4),
        pw.Divider(thickness: 1.5, color: PdfColors.blue900),
      ],
    );
  }

  pw.Widget _buildInvoiceEventInfo({
    required String eventName,
    required DateTime eventStartDate,
    required DateTime eventEndDate,
    required String eventLocation,
  }) {
    return pw.Container(
        padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EVENT INFORMATION',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
            pw.SizedBox(height: 3),
          pw.Text(
            eventName,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Date: ${_dateFormat.format(eventStartDate)} - ${_dateFormat.format(eventEndDate)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            'Location: $eventLocation',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceFeesSection(List<Map<String, dynamic>> feeBreakdown, double totalFees) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'JUDGING FEES',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
          pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
            ...feeBreakdown.map((fee) {
              final description = (fee['description'] as String?) ?? '';
              return pw.TableRow(
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('\$${fee['amount'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                  ),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Total Fees', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('\$${totalFees.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceExpensesSection(List<Map<String, dynamic>> expenseBreakdown, double totalExpenses) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'REIMBURSABLE EXPENSES',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
          pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(2.5),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
            ...expenseBreakdown.map((expense) {
              final description = (expense['description'] as String?) ?? '';
              return pw.TableRow(
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(expense['date'] ?? '', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(expense['category'] ?? '', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(description, style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('\$${expense['amount'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right),
                  ),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(''),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(''),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Total Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('\$${totalExpenses.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInvoiceTotalSection(double totalFees, double totalExpenses) {
    final grandTotal = totalFees + totalExpenses;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TOTAL AMOUNT DUE',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.Text(
            '\$${grandTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
          pw.SizedBox(height: 7),
        pw.Text(
          'Please remit payment to the judge listed above.',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
        pw.Text(
          'This invoice was generated by Gymnastics Judging Expense Tracker.',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey500,
          ),
        ),
      ],
    );
  }

  Future<File> _saveJudgeInvoicePdf(pw.Document pdf, String judgeName) async {
    final directory = await getApplicationDocumentsDirectory();
    final sanitizedName = judgeName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final fileName = 'invoice_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildSummaryRowPdf(String label, double amount, PdfColor color, {bool isBold = false}) {
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

  /// Generate a combined invoice PDF with summary page and individual judge invoices
  Future<File> generateCombinedInvoicesPdf({
    required String eventName,
    required DateTime eventStartDate,
    required DateTime eventEndDate,
    required String eventLocation,
    required double totalFees,
    required double totalExpenses,
    required List<Map<String, dynamic>> judgeInvoices,
    required EventReport report,
    List<Map<String, dynamic>>? eventStructure,
  }) async {
    final pdf = pw.Document();

    // Add financial summary page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EVENT FINANCIAL REPORT',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        eventName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        eventLocation,
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date:',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        _dateFormat.format(DateTime.now()),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 20),

              // Event Info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Event Dates:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${_dateFormat.format(eventStartDate)} - ${_dateFormat.format(eventEndDate)}',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Financial Summary
              pw.Text(
                'FINANCIAL SUMMARY',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  children: [
                    _buildSummaryRowPdf('Total Fees (for 1099s)', totalFees, PdfColors.green),
                    pw.Divider(color: PdfColors.grey300),
                    _buildSummaryRowPdf('Total Expenses (Reimbursable)', totalExpenses, PdfColors.orange),
                    pw.Divider(color: PdfColors.grey300),
                    _buildSummaryRowPdf('Total Payout (All Judges)', totalFees + totalExpenses, PdfColors.blue, isBold: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Event Structure
              if (eventStructure != null && eventStructure.isNotEmpty) ...[
                pw.Text(
                  'EVENT STRUCTURE',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: eventStructure.map((day) {
                      final sessions = day['sessions'] as List<Map<String, dynamic>>;
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 8,
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.blue900,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.SizedBox(width: 6),
                              pw.Text(
                                day['name'] as String,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Text(
                                '(${day['date']})',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          ...sessions.map((session) {
                            final floors = session['floors'] as List<Map<String, dynamic>>;
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 20, bottom: 6),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Row(
                                    children: [
                                      pw.Container(
                                        width: 6,
                                        height: 6,
                                        decoration: pw.BoxDecoration(
                                          color: PdfColors.blue700,
                                          shape: pw.BoxShape.circle,
                                        ),
                                      ),
                                      pw.SizedBox(width: 6),
                                      pw.Text(
                                        session['name'] as String,
                                        style: pw.TextStyle(
                                          fontSize: 11,
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                                      pw.SizedBox(width: 6),
                                      pw.Text(
                                        '(${floors.length} floor${floors.length != 1 ? 's' : ''})',
                                        style: pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColors.grey600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (floors.isNotEmpty)
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 18, top: 4),
                                      child: pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: floors.map((floor) {
                                          final judges = floor['judges'] as List<Map<String, dynamic>>;
                                          return pw.Padding(
                                            padding: const pw.EdgeInsets.only(bottom: 3),
                                            child: pw.Column(
                                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                                              children: [
                                                pw.Text(
                                                  floor['name'] as String,
                                                  style: pw.TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: pw.FontWeight.bold,
                                                    color: PdfColors.blue800,
                                                  ),
                                                ),
                                                if (judges.isNotEmpty)
                                                  pw.Padding(
                                                    padding: const pw.EdgeInsets.only(left: 10, top: 2),
                                                    child: pw.Column(
                                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                                      children: judges.map((judge) {
                                                        return pw.Padding(
                                                          padding: const pw.EdgeInsets.only(bottom: 1),
                                                          child: pw.Text(
                                                            '- ${judge['name']} (${judge['role']})',
                                                            style: pw.TextStyle(
                                                              fontSize: 8,
                                                              color: PdfColors.grey700,
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  )
                                                else
                                                  pw.Padding(
                                                    padding: const pw.EdgeInsets.only(left: 10, top: 2),
                                                    child: pw.Text(
                                                      '- No judges assigned',
                                                      style: pw.TextStyle(
                                                        fontSize: 8,
                                                        color: PdfColors.grey500,
                                                        fontStyle: pw.FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (eventStructure.indexOf(day) < eventStructure.length - 1)
                            pw.SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Judge earnings chart (text-based)
              pw.Text(
                'JUDGE EARNINGS BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Top earners
                    pw.Text(
                      'Top 10 Judges by Total Payout:',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    ...(report.judgeBreakdowns.values.toList()
                      ..sort((a, b) => b.totalOwed.compareTo(a.totalOwed)))
                      .take(10)
                      .map((summary) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  summary.judgeName,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Text(
                                'Fees: \$${summary.totalFees.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontSize: 9, color: PdfColors.green800),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Text(
                                'Exp: \$${summary.totalExpenses.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontSize: 9, color: PdfColors.orange800),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Text(
                                'Total: \$${summary.totalOwed.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Expense breakdown by category
              if (report.expensesByCategory.isNotEmpty) ...[
                pw.Text(
                  'EXPENSE BREAKDOWN BY CATEGORY',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: report.expensesByCategory.entries.map((entry) {
                    return pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 12,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue700,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                        ),
                        pw.SizedBox(width: 4),
                        pw.Text(
                          '${_getCategoryDisplayName(entry.key)}: \$${entry.value.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Note about individual invoices
              pw.Expanded(child: pw.SizedBox()),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Individual judge invoices and detailed breakdown follow on subsequent pages.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Add judge summary page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'COMBINED INVOICES',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        eventName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '$eventLocation',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date:',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        _dateFormat.format(DateTime.now()),
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 20),

              // Event Info
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Event Dates:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${_dateFormat.format(eventStartDate)} - ${_dateFormat.format(eventEndDate)}',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary heading
              pw.Text(
                'JUDGE SUMMARY',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 10),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Judge Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Level', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Fees', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Data rows
                  ...judgeInvoices.map((invoice) {
                    final fees = invoice['totalFees'] as double;
                    final expenses = invoice['totalExpenses'] as double;
                    final total = fees + expenses;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(invoice['judgeName'] as String),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${invoice['judgeAssociation']} - ${invoice['judgeLevel']}', style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('\$${fees.toStringAsFixed(2)}', textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('\$${expenses.toStringAsFixed(2)}', textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }),
                  // Total row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('\$${totalFees.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('\$${totalExpenses.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('\$${(totalFees + totalExpenses).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Grand total box
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL AMOUNT DUE (ALL JUDGES)',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      '\$${(totalFees + totalExpenses).toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Expanded(child: pw.SizedBox()),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Individual judge invoices follow on subsequent pages.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Add individual judge invoice pages - one page per judge
    // Limit to prevent excessive PDF size
    final maxInvoices = 100;
    final invoicesToGenerate = judgeInvoices.length > maxInvoices 
        ? judgeInvoices.sublist(0, maxInvoices)
        : judgeInvoices;
    
    for (final invoice in invoicesToGenerate) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInvoiceHeader(
                  judgeName: invoice['judgeName'] as String,
                  judgeAssociation: invoice['judgeAssociation'] as String,
                  judgeLevel: invoice['judgeLevel'] as String,
                ),
                pw.SizedBox(height: 10),
                _buildInvoiceEventInfo(
                  eventName: eventName,
                  eventStartDate: eventStartDate,
                  eventEndDate: eventEndDate,
                  eventLocation: eventLocation,
                ),
                pw.SizedBox(height: 10),
                _buildInvoiceFeesSection(
                  invoice['feeBreakdown'] as List<Map<String, dynamic>>,
                  invoice['totalFees'] as double,
                ),
                pw.SizedBox(height: 10),
                _buildInvoiceExpensesSection(
                  invoice['expenseBreakdown'] as List<Map<String, dynamic>>,
                  invoice['totalExpenses'] as double,
                ),
                pw.SizedBox(height: 10),
                _buildInvoiceTotalSection(
                  invoice['totalFees'] as double,
                  invoice['totalExpenses'] as double,
                ),
                pw.Expanded(child: pw.SizedBox()),
                _buildInvoiceFooter(),
              ],
            );
          },
        ),
      );
    }

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final sanitizedEventName = eventName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final fileName = 'combined_invoices_${sanitizedEventName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

