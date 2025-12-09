class MeetExportResult {
  final bool success;
  final String message;
  final String? filePath;
  final String? meetId;
  final String meetName;

  MeetExportResult({
    required this.success,
    required this.message,
    this.filePath,
    this.meetId,
    required this.meetName,
  });
}

class MeetImportResult {
  final bool success;
  final String message;
  final String? meetId;
  final String? meetName;
  final int sessionsCreated;
  final int floorsCreated;
  final int daysCreated;
  final int judgesCreated;
  final int assignmentsCreated;
  final int feesCreated;
  final int expensesCreated;
  final List<String> errors;
  final List<String> warnings;

  MeetImportResult({
    required this.success,
    required this.message,
    this.meetId,
    this.meetName,
    this.sessionsCreated = 0,
    this.floorsCreated = 0,
    this.daysCreated = 0,
    this.judgesCreated = 0,
    this.assignmentsCreated = 0,
    this.feesCreated = 0,
    this.expensesCreated = 0,
    this.errors = const [],
    this.warnings = const [],
  });

  int get totalItemsCreated => 
    sessionsCreated + floorsCreated + daysCreated + judgesCreated + 
    assignmentsCreated + feesCreated + expensesCreated;
}
