import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../repositories/expense_repository.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push('/expenses/$expenseId/edit');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: FutureBuilder<Expense?>(
        future: ExpenseRepository().getExpenseById(expenseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading expense: ${snapshot.error}'),
            );
          }

          final expense = snapshot.data;
          if (expense == null) {
            return const Center(
              child: Text('Expense not found'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Category and Amount Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getCategoryIcon(expense.category), size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getCategoryName(expense.category),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMMM d, y').format(expense.date),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${expense.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              if (expense.isAutoCalculated)
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 14, color: Colors.green.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Auto-calculated',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              if (expense.description != null && expense.description!.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(expense.description!),
                      ],
                    ),
                  ),
                ),

              // Category-specific details
              if (_hasCategoryDetails(expense)) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildCategoryDetails(expense),
                      ],
                    ),
                  ),
                ),
              ],

              // Receipt photo
              if (expense.receiptPhotoPath != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Receipt Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showFullImage(context, expense.receiptPhotoPath!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(expense.receiptPhotoPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Text('Image not available'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Metadata
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Metadata',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMetadataRow('Created', DateFormat('MMM d, y h:mm a').format(expense.createdAt)),
                      _buildMetadataRow('Updated', DateFormat('MMM d, y h:mm a').format(expense.updatedAt)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(value),
        ],
      ),
    );
  }

  bool _hasCategoryDetails(Expense expense) {
    return expense.distance != null ||
        expense.mileageRate != null ||
        expense.mealType != null ||
        expense.perDiemRate != null ||
        expense.transportationType != null ||
        expense.checkInDate != null ||
        expense.checkOutDate != null ||
        expense.numberOfNights != null;
  }

  List<Widget> _buildCategoryDetails(Expense expense) {
    final details = <Widget>[];

    if (expense.distance != null) {
      details.add(_buildDetailRow('Distance', '${expense.distance} miles'));
    }
    if (expense.mileageRate != null) {
      details.add(_buildDetailRow('Mileage Rate', '\$${expense.mileageRate}/mile'));
    }
    if (expense.mealType != null) {
      details.add(_buildDetailRow('Meal Type', _getMealTypeName(expense.mealType!)));
    }
    if (expense.perDiemRate != null) {
      details.add(_buildDetailRow('Per Diem Rate', '\$${expense.perDiemRate}'));
    }
    if (expense.transportationType != null) {
      details.add(_buildDetailRow('Transportation Type', expense.transportationType!));
    }
    if (expense.checkInDate != null) {
      details.add(_buildDetailRow('Check-in', DateFormat('MMM d, y').format(expense.checkInDate!)));
    }
    if (expense.checkOutDate != null) {
      details.add(_buildDetailRow('Check-out', DateFormat('MMM d, y').format(expense.checkOutDate!)));
    }
    if (expense.numberOfNights != null) {
      details.add(_buildDetailRow('Number of Nights', '${expense.numberOfNights}'));
    }

    return details;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(File(imagePath)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ExpenseRepository().deleteExpense(expenseId);
        
        // Invalidate all expense providers
        ref.invalidate(expensesByEventProvider);
        ref.invalidate(expensesByJudgeProvider);
        ref.invalidate(expensesByAssignmentProvider);
        ref.invalidate(expensesByJudgeAndEventProvider);
        ref.invalidate(totalExpensesByEventProvider);
        ref.invalidate(totalExpensesByJudgeProvider);
        ref.invalidate(totalExpensesByAssignmentProvider);
        ref.invalidate(totalExpensesByJudgeAndEventProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting expense: $e')),
          );
        }
      }
    }
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

  String _getMealTypeName(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.fullDay:
        return 'Full Day';
    }
  }
}
