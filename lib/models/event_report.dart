import 'package:json_annotation/json_annotation.dart';

part 'event_report.g.dart';

enum ReportType {
  event,
  judge,
  dateRange,
}

@JsonSerializable()
class EventReport {
  final String id;
  final ReportType reportType;
  final String? eventId;
  final String? eventName;
  final String? judgeId;
  final String? judgeName;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  
  // Financial data
  final Map<String, JudgeFinancialSummary> judgeBreakdowns;
  final Map<String, double> expensesByCategory;
  final double totalFees; // Sum of all judge fees (for 1099 reporting)
  final double totalExpenses; // Sum of all reimbursable expenses
  
  // Total payout across all judges (sum of all individual checks)
  double get totalOwed => totalFees + totalExpenses;
  
  // Metadata
  final String? notes;

  EventReport({
    required this.id,
    required this.reportType,
    this.eventId,
    this.eventName,
    this.judgeId,
    this.judgeName,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    required this.judgeBreakdowns,
    required this.expensesByCategory,
    required this.totalFees,
    required this.totalExpenses,
    this.notes,
  });

  double getTotalOwedForJudge(String judgeId) {
    final summary = judgeBreakdowns[judgeId];
    if (summary == null) return 0.0;
    return summary.totalOwed;
  }

  factory EventReport.fromJson(Map<String, dynamic> json) =>
      _$EventReportFromJson(json);

  Map<String, dynamic> toJson() => _$EventReportToJson(this);

  EventReport copyWith({
    String? id,
    ReportType? reportType,
    String? eventId,
    String? eventName,
    String? judgeId,
    String? judgeName,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? generatedAt,
    Map<String, JudgeFinancialSummary>? judgeBreakdowns,
    Map<String, double>? expensesByCategory,
    double? totalFees,
    double? totalExpenses,
    String? notes,
  }) {
    return EventReport(
      id: id ?? this.id,
      reportType: reportType ?? this.reportType,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      judgeId: judgeId ?? this.judgeId,
      judgeName: judgeName ?? this.judgeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      generatedAt: generatedAt ?? this.generatedAt,
      judgeBreakdowns: judgeBreakdowns ?? this.judgeBreakdowns,
      expensesByCategory: expensesByCategory ?? this.expensesByCategory,
      totalFees: totalFees ?? this.totalFees,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      notes: notes ?? this.notes,
    );
  }
}

@JsonSerializable()
class JudgeFinancialSummary {
  final String judgeId;
  final String judgeName;
  final double totalFees; // Judging fees - amount for 1099 (taxable income)
  final double totalExpenses; // Reimbursable expenses (not taxable, not on 1099)
  final Map<String, double> feesBySession;
  final Map<String, double> expensesByCategory;

  // Check amount - what to pay this specific judge (fees + expenses)
  double get totalOwed => totalFees + totalExpenses;
  
  // 1099 amount - taxable income for this judge (fees only)
  double get amount1099 => totalFees;

  JudgeFinancialSummary({
    required this.judgeId,
    required this.judgeName,
    required this.totalFees,
    required this.totalExpenses,
    required this.feesBySession,
    required this.expensesByCategory,
  });

  factory JudgeFinancialSummary.fromJson(Map<String, dynamic> json) =>
      _$JudgeFinancialSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$JudgeFinancialSummaryToJson(this);
}

@JsonSerializable()
class FinancialSummary {
  final String eventId;
  final String eventName;
  final DateTime startDate;
  final DateTime endDate;
  final double totalFees; // Total for 1099s
  final double totalExpenses; // Total reimbursable expenses
  final int numberOfJudges;
  final Map<String, double> expenseBreakdown;
  
  // Total amount owed to all judges (fees + expenses)
  double get totalOwed => totalFees + totalExpenses;

  FinancialSummary({
    required this.eventId,
    required this.eventName,
    required this.startDate,
    required this.endDate,
    required this.totalFees,
    required this.totalExpenses,
    required this.numberOfJudges,
    required this.expenseBreakdown,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) =>
      _$FinancialSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$FinancialSummaryToJson(this);
}
