import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../services/database_service.dart';

class ExpenseRepository {
  final DatabaseService _dbService = DatabaseService.instance;
  final _uuid = const Uuid();

  // Create
  Future<Expense> createExpense({
    required String eventId,
    String? judgeId,
    String? judgeAssignmentId,
    required ExpenseCategory category,
    required double amount,
    required DateTime date,
    required String description,
    double? distance,
    double? mileageRate,
    MealType? mealType,
    double? perDiemRate,
    String? transportationType,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? numberOfNights,
    String? receiptPhotoPath,
    bool isAutoCalculated = false,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now();

    final expense = Expense(
      id: _uuid.v4(),
      eventId: eventId,
      judgeId: judgeId,
      judgeAssignmentId: judgeAssignmentId,
      category: category,
      amount: amount,
      date: date,
      description: description,
      distance: distance,
      mileageRate: mileageRate,
      mealType: mealType,
      perDiemRate: perDiemRate,
      transportationType: transportationType,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      numberOfNights: numberOfNights,
      receiptPhotoPath: receiptPhotoPath,
      isAutoCalculated: isAutoCalculated,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('expenses', expense.toMap());
    return expense;
  }

  // Read
  Future<Expense?> getExpenseById(String id) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Expense.fromMap(maps.first);
  }

  Future<List<Expense>> getExpensesByEventId(String eventId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'expenses',
      where: 'eventId = ?',
      whereArgs: [eventId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByJudgeId(String judgeId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'expenses',
      where: 'judgeId = ?',
      whereArgs: [judgeId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByAssignmentId(String assignmentId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'expenses',
      where: 'judgeAssignmentId = ?',
      whereArgs: [assignmentId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByJudgeAndEvent({
    required String judgeId,
    required String eventId,
  }) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'expenses',
      where: 'judgeId = ? AND eventId = ?',
      whereArgs: [judgeId, eventId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByCategory({
    required String eventId,
    required ExpenseCategory category,
  }) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'expenses',
      where: 'eventId = ? AND category = ?',
      whereArgs: [eventId, category.name],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? eventId,
    String? judgeId,
  }) async {
    final db = await _dbService.database;
    final conditions = <String>['date >= ? AND date <= ?'];
    final args = <dynamic>[
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    if (eventId != null) {
      conditions.add('eventId = ?');
      args.add(eventId);
    }

    if (judgeId != null) {
      conditions.add('judgeId = ?');
      args.add(judgeId);
    }

    final maps = await db.query(
      'expenses',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC',
    );

    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  // Update
  Future<void> updateExpense(Expense expense) async {
    final db = await _dbService.database;
    final updatedExpense = expense.copyWith(updatedAt: DateTime.now());
    
    await db.update(
      'expenses',
      updatedExpense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Delete
  Future<void> deleteExpense(String id) async {
    final db = await _dbService.database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Calculations
  Future<double> getTotalExpensesByEvent(String eventId) async {
    final expenses = await getExpensesByEventId(eventId);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<double> getTotalExpensesByJudge(String judgeId) async {
    final expenses = await getExpensesByJudgeId(judgeId);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<double> getTotalExpensesByAssignment(String assignmentId) async {
    final expenses = await getExpensesByAssignmentId(assignmentId);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<double> getTotalExpensesByCategory({
    required String eventId,
    required ExpenseCategory category,
  }) async {
    final expenses = await getExpensesByCategory(
      eventId: eventId,
      category: category,
    );
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<Map<ExpenseCategory, double>> getExpenseBreakdownByEvent(String eventId) async {
    final expenses = await getExpensesByEventId(eventId);
    final breakdown = <ExpenseCategory, double>{};

    for (final expense in expenses) {
      breakdown[expense.category] = (breakdown[expense.category] ?? 0.0) + expense.amount;
    }

    return breakdown;
  }
}
