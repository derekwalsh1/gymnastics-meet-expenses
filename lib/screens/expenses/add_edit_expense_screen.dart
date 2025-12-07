import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../repositories/expense_repository.dart';

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  final String? expenseId;
  final String? eventId;
  final String? judgeId;
  final String? assignmentId;

  const AddEditExpenseScreen({
    super.key,
    this.expenseId,
    this.eventId,
    this.judgeId,
    this.assignmentId,
  });

  @override
  ConsumerState<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _distanceController = TextEditingController();
  final _mileageRateController = TextEditingController();
  final _perDiemRateController = TextEditingController();
  final _numberOfNightsController = TextEditingController();
  final _transportationTypeController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.mileage;
  MealType? _selectedMealType;
  DateTime _selectedDate = DateTime.now();
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  bool _isAutoCalculated = false;
  String? _receiptPhotoPath;
  bool _isLoading = true;
  Expense? _expense;

  @override
  void initState() {
    super.initState();
    _mileageRateController.text = '0.67'; // IRS standard rate 2024
    _loadExpense();
  }

  Future<void> _loadExpense() async {
    if (widget.expenseId != null) {
      try {
        final expense = await ExpenseRepository().getExpenseById(widget.expenseId!);
        if (expense != null && mounted) {
          setState(() {
            _expense = expense;
            _selectedCategory = expense.category;
            _descriptionController.text = expense.description ?? '';
            _amountController.text = expense.amount.toString();
            _selectedDate = expense.date;
            _isAutoCalculated = expense.isAutoCalculated;
            _receiptPhotoPath = expense.receiptPhotoPath;

            // Category-specific fields
            if (expense.distance != null) {
              _distanceController.text = expense.distance!.toString();
            }
            if (expense.mileageRate != null) {
              _mileageRateController.text = expense.mileageRate!.toString();
            }
            if (expense.mealType != null) {
              _selectedMealType = expense.mealType;
            }
            if (expense.perDiemRate != null) {
              _perDiemRateController.text = expense.perDiemRate!.toString();
            }
            if (expense.transportationType != null) {
              _transportationTypeController.text = expense.transportationType!;
            }
            if (expense.checkInDate != null) {
              _checkInDate = expense.checkInDate;
            }
            if (expense.checkOutDate != null) {
              _checkOutDate = expense.checkOutDate;
            }
            if (expense.numberOfNights != null) {
              _numberOfNightsController.text = expense.numberOfNights!.toString();
            }

            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading expense: $e')),
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _distanceController.dispose();
    _mileageRateController.dispose();
    _perDiemRateController.dispose();
    _numberOfNightsController.dispose();
    _transportationTypeController.dispose();
    super.dispose();
  }

  void _calculateAmount() {
    double? calculatedAmount;

    switch (_selectedCategory) {
      case ExpenseCategory.mileage:
        final distance = double.tryParse(_distanceController.text);
        final rate = double.tryParse(_mileageRateController.text);
        if (distance != null && rate != null) {
          calculatedAmount = distance * rate;
        }
        break;
      case ExpenseCategory.mealsPerDiem:
        final rate = double.tryParse(_perDiemRateController.text);
        if (rate != null) {
          calculatedAmount = rate;
        }
        break;
      case ExpenseCategory.lodging:
        if (_checkInDate != null && _checkOutDate != null) {
          final nights = _checkOutDate!.difference(_checkInDate!).inDays;
          _numberOfNightsController.text = nights.toString();
          // Amount is manual for lodging
        }
        break;
      default:
        break;
    }

    if (calculatedAmount != null) {
      setState(() {
        _amountController.text = calculatedAmount!.toStringAsFixed(2);
        _isAutoCalculated = true;
      });
    }
  }

  Future<void> _pickReceipt() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      // Copy to app documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = '${const Uuid().v4()}.jpg';
      final String filePath = '${appDir.path}/receipts/$fileName';
      
      // Create receipts directory if it doesn't exist
      final receiptsDir = Directory('${appDir.path}/receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      await File(image.path).copy(filePath);
      
      setState(() {
        _receiptPhotoPath = filePath;
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      // Copy to app documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = '${const Uuid().v4()}.jpg';
      final String filePath = '${appDir.path}/receipts/$fileName';
      
      // Create receipts directory if it doesn't exist
      final receiptsDir = Directory('${appDir.path}/receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      await File(image.path).copy(filePath);
      
      setState(() {
        _receiptPhotoPath = filePath;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields based on category
    if (_selectedCategory == ExpenseCategory.mileage && _distanceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter distance for mileage expense')),
      );
      return;
    }

    if (_selectedCategory == ExpenseCategory.lodging && (_checkInDate == null || _checkOutDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select check-in and check-out dates for lodging')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text);
      
      if (widget.expenseId != null) {
        // Update existing expense
        final updatedExpense = _expense!.copyWith(
          category: _selectedCategory,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          amount: amount,
          date: _selectedDate,
          isAutoCalculated: _isAutoCalculated,
          receiptPhotoPath: _receiptPhotoPath,
          distance: _distanceController.text.isEmpty ? null : double.parse(_distanceController.text),
          mileageRate: _mileageRateController.text.isEmpty ? null : double.parse(_mileageRateController.text),
          mealType: _selectedMealType,
          perDiemRate: _perDiemRateController.text.isEmpty ? null : double.parse(_perDiemRateController.text),
          transportationType: _transportationTypeController.text.trim().isEmpty ? null : _transportationTypeController.text.trim(),
          checkInDate: _checkInDate,
          checkOutDate: _checkOutDate,
          numberOfNights: _numberOfNightsController.text.isEmpty ? null : int.parse(_numberOfNightsController.text),
          updatedAt: DateTime.now(),
        );
        await ExpenseRepository().updateExpense(updatedExpense);
      } else {
        // Create new expense
        await ExpenseRepository().createExpense(
          eventId: widget.eventId ?? '',
          judgeId: widget.judgeId,
          judgeAssignmentId: widget.assignmentId,
          category: _selectedCategory,
          description: _descriptionController.text.trim().isEmpty ? 'No description' : _descriptionController.text.trim(),
          amount: amount,
          date: _selectedDate,
          isAutoCalculated: _isAutoCalculated,
          receiptPhotoPath: _receiptPhotoPath,
          distance: _distanceController.text.isEmpty ? null : double.parse(_distanceController.text),
          mileageRate: _mileageRateController.text.isEmpty ? null : double.parse(_mileageRateController.text),
          mealType: _selectedMealType,
          perDiemRate: _perDiemRateController.text.isEmpty ? null : double.parse(_perDiemRateController.text),
          transportationType: _transportationTypeController.text.trim().isEmpty ? null : _transportationTypeController.text.trim(),
          checkInDate: _checkInDate,
          checkOutDate: _checkOutDate,
          numberOfNights: _numberOfNightsController.text.isEmpty ? null : int.parse(_numberOfNightsController.text),
        );
      }

      // Invalidate providers
      if (widget.eventId != null) {
        ref.invalidate(expensesByEventProvider(widget.eventId!));
        ref.invalidate(totalExpensesByEventProvider(widget.eventId!));
      }
      if (widget.judgeId != null) {
        ref.invalidate(expensesByJudgeProvider(widget.judgeId!));
        ref.invalidate(totalExpensesByJudgeProvider(widget.judgeId!));
      }
      if (widget.eventId != null && widget.judgeId != null) {
        ref.invalidate(expensesByJudgeAndEventProvider((
          judgeId: widget.judgeId!,
          eventId: widget.eventId!,
        )));
        ref.invalidate(totalExpensesByJudgeAndEventProvider((
          judgeId: widget.judgeId!,
          eventId: widget.eventId!,
        )));
      }
      if (widget.assignmentId != null) {
        ref.invalidate(expensesByAssignmentProvider(widget.assignmentId!));
        ref.invalidate(totalExpensesByAssignmentProvider(widget.assignmentId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense ${widget.expenseId != null ? 'updated' : 'created'} successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseId != null ? 'Edit Expense' : 'Add Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveExpense,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Category selector
            DropdownButtonFormField<ExpenseCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: ExpenseCategory.values.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(_getCategoryName(category)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                    _isAutoCalculated = false;
                    _amountController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Date picker
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat('MMMM d, y').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Category-specific fields
            ..._buildCategoryFields(),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: const OutlineInputBorder(),
                prefixText: '\$',
                suffixIcon: _isAutoCalculated
                    ? const Icon(Icons.auto_awesome, color: Colors.green)
                    : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              onChanged: (value) {
                if (_isAutoCalculated) {
                  setState(() {
                    _isAutoCalculated = false;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Receipt photo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Receipt Photo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_receiptPhotoPath != null)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_receiptPhotoPath!),
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _receiptPhotoPath = null;
                              });
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Remove Photo'),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickReceipt,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Choose Photo'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton(
              onPressed: _saveExpense,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(widget.expenseId != null ? 'Update Expense' : 'Add Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryFields() {
    switch (_selectedCategory) {
      case ExpenseCategory.mileage:
        return [
          TextFormField(
            controller: _distanceController,
            decoration: const InputDecoration(
              labelText: 'Distance (miles)',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _calculateAmount(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mileageRateController,
            decoration: const InputDecoration(
              labelText: 'Rate per mile',
              border: OutlineInputBorder(),
              prefixText: '\$',
              helperText: 'IRS standard rate: \$0.67/mile (2024)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _calculateAmount(),
          ),
        ];

      case ExpenseCategory.mealsPerDiem:
        return [
          DropdownButtonFormField<MealType>(
            value: _selectedMealType,
            decoration: const InputDecoration(
              labelText: 'Meal Type',
              border: OutlineInputBorder(),
            ),
            items: MealType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getMealTypeName(type)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedMealType = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _perDiemRateController,
            decoration: const InputDecoration(
              labelText: 'Per Diem Rate',
              border: OutlineInputBorder(),
              prefixText: '\$',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _calculateAmount(),
          ),
        ];

      case ExpenseCategory.lodging:
        return [
          ListTile(
            title: const Text('Check-in Date'),
            subtitle: Text(_checkInDate != null ? DateFormat('MMM d, y').format(_checkInDate!) : 'Not selected'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _checkInDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() {
                  _checkInDate = date;
                  _calculateAmount();
                });
              }
            },
          ),
          ListTile(
            title: const Text('Check-out Date'),
            subtitle: Text(_checkOutDate != null ? DateFormat('MMM d, y').format(_checkOutDate!) : 'Not selected'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _checkOutDate ?? _checkInDate ?? DateTime.now(),
                firstDate: _checkInDate ?? DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() {
                  _checkOutDate = date;
                  _calculateAmount();
                });
              }
            },
          ),
          if (_numberOfNightsController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Number of nights: ${_numberOfNightsController.text}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
        ];

      case ExpenseCategory.transportation:
        return [
          TextFormField(
            controller: _transportationTypeController,
            decoration: const InputDecoration(
              labelText: 'Transportation Type',
              border: OutlineInputBorder(),
              helperText: 'e.g., Uber, Lyft, Taxi, Bus',
            ),
          ),
        ];

      default:
        return [];
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
