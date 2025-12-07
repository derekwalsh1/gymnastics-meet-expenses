import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  final String? eventId;
  final String? judgeId;
  final String? assignmentId;

  const ExpenseListScreen({
    super.key,
    this.eventId,
    this.judgeId,
    this.assignmentId,
  });

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  ExpenseCategory? _selectedCategory;
  String _searchQuery = '';
  bool _groupByCategory = true;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = _getExpensesProvider();
    final totalAsync = _getTotalProvider();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: Icon(_groupByCategory ? Icons.calendar_today : Icons.category),
            tooltip: _groupByCategory ? 'Group by date' : 'Group by category',
            onPressed: () {
              setState(() {
                _groupByCategory = !_groupByCategory;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search expenses...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Total expenses badge
          totalAsync.when(
            data: (total) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Expenses',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Expenses list
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                final filteredExpenses = _filterExpenses(expenses);
                if (filteredExpenses.isEmpty) {
                  return const Center(
                    child: Text('No expenses found'),
                  );
                }
                return _groupByCategory
                    ? _buildGroupedByCategory(filteredExpenses)
                    : _buildGroupedByDate(filteredExpenses);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error loading expenses: $error'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add expense screen
          context.push('/expenses/add', extra: {
            'eventId': widget.eventId,
            'judgeId': widget.judgeId,
            'assignmentId': widget.assignmentId,
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  AsyncValue<List<Expense>> _getExpensesProvider() {
    if (widget.assignmentId != null) {
      return ref.watch(expensesByAssignmentProvider(widget.assignmentId!));
    } else if (widget.eventId != null && widget.judgeId != null) {
      return ref.watch(expensesByJudgeAndEventProvider((
        judgeId: widget.judgeId!,
        eventId: widget.eventId!,
      )));
    } else if (widget.eventId != null) {
      return ref.watch(expensesByEventProvider(widget.eventId!));
    } else if (widget.judgeId != null) {
      return ref.watch(expensesByJudgeProvider(widget.judgeId!));
    }
    // Default: show all expenses from current event if available
    return const AsyncValue.data([]);
  }

  AsyncValue<double> _getTotalProvider() {
    if (widget.assignmentId != null) {
      return ref.watch(totalExpensesByAssignmentProvider(widget.assignmentId!));
    } else if (widget.eventId != null && widget.judgeId != null) {
      return ref.watch(totalExpensesByJudgeAndEventProvider((
        judgeId: widget.judgeId!,
        eventId: widget.eventId!,
      )));
    } else if (widget.eventId != null) {
      return ref.watch(totalExpensesByEventProvider(widget.eventId!));
    } else if (widget.judgeId != null) {
      return ref.watch(totalExpensesByJudgeProvider(widget.judgeId!));
    }
    return const AsyncValue.data(0.0);
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    return expenses.where((expense) {
      // Filter by category
      if (_selectedCategory != null && expense.category != _selectedCategory) {
        return false;
      }
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final description = expense.description?.toLowerCase() ?? '';
        final category = expense.category.name.toLowerCase();
        if (!description.contains(query) && !category.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildGroupedByCategory(List<Expense> expenses) {
    final grouped = <ExpenseCategory, List<Expense>>{};
    for (final expense in expenses) {
      grouped.putIfAbsent(expense.category, () => []).add(expense);
    }

    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView.builder(
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final categoryExpenses = grouped[category]!;
        final categoryTotal = categoryExpenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        );

        return ExpansionTile(
          title: Row(
            children: [
              Icon(_getCategoryIcon(category), size: 20),
              const SizedBox(width: 8),
              Text(_getCategoryName(category)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  '\$${categoryTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Text('${categoryExpenses.length} expense${categoryExpenses.length != 1 ? 's' : ''}'),
          children: categoryExpenses.map((expense) => _buildExpenseTile(expense)).toList(),
        );
      },
    );
  }

  Widget _buildGroupedByDate(List<Expense> expenses) {
    final grouped = <String, List<Expense>>{};
    for (final expense in expenses) {
      final dateKey = DateFormat('yyyy-MM-dd').format(expense.date);
      grouped.putIfAbsent(dateKey, () => []).add(expense);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Most recent first

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dateExpenses = grouped[dateKey]!;
        final dateTotal = dateExpenses.fold<double>(
          0,
          (sum, expense) => sum + expense.amount,
        );
        final date = DateTime.parse(dateKey);

        return ExpansionTile(
          title: Row(
            children: [
              Text(DateFormat('EEEE, MMMM d, y').format(date)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  '\$${dateTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Text('${dateExpenses.length} expense${dateExpenses.length != 1 ? 's' : ''}'),
          children: dateExpenses.map((expense) => _buildExpenseTile(expense)).toList(),
        );
      },
    );
  }

  Widget _buildExpenseTile(Expense expense) {
    return ListTile(
      leading: Icon(_getCategoryIcon(expense.category)),
      title: Text(
        expense.description ?? _getCategoryName(expense.category),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('MMM d, y').format(expense.date)),
          if (expense.receiptPhotoPath != null)
            Row(
              children: [
                Icon(Icons.receipt, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Receipt attached',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
        ],
      ),
      trailing: Text(
        '\$${expense.amount.toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        context.push('/expenses/${expense.id}');
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ExpenseCategory?>(
              title: const Text('All Categories'),
              value: null,
              groupValue: _selectedCategory,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
                Navigator.pop(context);
              },
            ),
            ...ExpenseCategory.values.map((category) {
              return RadioListTile<ExpenseCategory?>(
                title: Row(
                  children: [
                    Icon(_getCategoryIcon(category), size: 20),
                    const SizedBox(width: 8),
                    Text(_getCategoryName(category)),
                  ],
                ),
                value: category,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.mileage:
        return 'Mileage';
      case ExpenseCategory.mealsPerDiem:
        return 'Meals & Per Diem';
      case ExpenseCategory.lodging:
        return 'Lodging';
      case ExpenseCategory.airfare:
        return 'Airfare';
      case ExpenseCategory.parking:
        return 'Parking';
      case ExpenseCategory.tolls:
        return 'Tolls';
      case ExpenseCategory.transportation:
        return 'Transportation';
      case ExpenseCategory.other:
        return 'Other';
      case ExpenseCategory.judgeFees:
        return 'Judge Fees';
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.mileage:
        return Icons.directions_car;
      case ExpenseCategory.mealsPerDiem:
        return Icons.restaurant;
      case ExpenseCategory.lodging:
        return Icons.hotel;
      case ExpenseCategory.airfare:
        return Icons.flight;
      case ExpenseCategory.parking:
        return Icons.local_parking;
      case ExpenseCategory.tolls:
        return Icons.toll;
      case ExpenseCategory.transportation:
        return Icons.directions_bus;
      case ExpenseCategory.other:
        return Icons.more_horiz;
      case ExpenseCategory.judgeFees:
        return Icons.attach_money;
    }
  }
}
