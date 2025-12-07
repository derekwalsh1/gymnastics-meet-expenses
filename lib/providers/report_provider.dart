import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_report.dart';
import '../repositories/report_repository.dart';

// Repository provider
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

// Event report provider
final eventReportProvider = FutureProvider.family<EventReport, String>((ref, eventId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.generateEventReport(eventId);
});

// Judge report provider
final judgeReportProvider = FutureProvider.family<EventReport, ({String judgeId, DateTime startDate, DateTime endDate})>(
  (ref, params) async {
    final repository = ref.watch(reportRepositoryProvider);
    return repository.generateJudgeReport(
      judgeId: params.judgeId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  },
);

// Financial summary provider
final financialSummaryProvider = FutureProvider.family<FinancialSummary, String>((ref, eventId) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getEventFinancialSummary(eventId);
});

// Judge earnings breakdown provider
final judgeEarningsBreakdownProvider = FutureProvider.family<JudgeFinancialSummary, ({String judgeId, String eventId})>(
  (ref, params) async {
    final repository = ref.watch(reportRepositoryProvider);
    return repository.getJudgeEarningsBreakdown(
      judgeId: params.judgeId,
      eventId: params.eventId,
    );
  },
);
