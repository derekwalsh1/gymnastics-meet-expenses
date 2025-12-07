import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/judge_assignment.dart';
import '../../models/judge_fee.dart';
import '../../models/event_session.dart';
import '../../repositories/judge_assignment_repository.dart';
import '../../repositories/judge_fee_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/event_day_repository.dart';
import '../../providers/judge_assignment_provider.dart';
import '../../providers/judge_fee_provider.dart';
import '../../providers/expense_provider.dart';

class EditAssignmentScreen extends ConsumerStatefulWidget {
  final String assignmentId;
  final String floorId;
  final String sessionId;

  const EditAssignmentScreen({
    super.key,
    required this.assignmentId,
    required this.floorId,
    required this.sessionId,
  });

  @override
  ConsumerState<EditAssignmentScreen> createState() => _EditAssignmentScreenState();
}

class _EditAssignmentScreenState extends ConsumerState<EditAssignmentScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _roleController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  
  bool _isLoading = true;
  JudgeAssignment? _assignment;
  String? _eventId;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roleController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when the app resumes (e.g., after navigating back)
      _loadData();
      // Also invalidate the providers to refresh the UI
      if (_assignment != null && _eventId != null) {
        ref.invalidate(feesForJudgeInEventProvider((judgeId: _assignment!.judgeId, eventId: _eventId!)));
        ref.invalidate(expensesByJudgeAndEventProvider((judgeId: _assignment!.judgeId, eventId: _eventId!)));
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final assignmentRepo = JudgeAssignmentRepository();
      final floorRepo = EventFloorRepository();
      
      final assignment = await assignmentRepo.getAssignmentById(widget.assignmentId);
      
      // Get event ID from floor -> session -> day -> event
      String? eventId;
      if (assignment != null) {
        final floor = await floorRepo.getEventFloorById(assignment.eventFloorId);
        if (floor != null) {
          final session = await EventSessionRepository().getEventSessionById(floor.eventSessionId);
          if (session != null) {
            final day = await EventDayRepository().getEventDayById(session.eventDayId);
            eventId = day?.eventId;
          }
        }
      }
      
      if (mounted && assignment != null) {
        setState(() {
          _assignment = assignment;
          _eventId = eventId;
          _roleController.text = assignment.role ?? '';
          _hourlyRateController.text = assignment.hourlyRate.toStringAsFixed(2);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assignment: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _invalidateFeeTotals() async {
    // Invalidate floor total
    ref.invalidate(totalFeesForFloorProvider(widget.floorId));
    
    // Invalidate session total
    ref.invalidate(totalFeesForSessionProvider(widget.sessionId));
    
    // Fetch session to get day ID and invalidate day total
    try {
      final session = await EventSessionRepository().getEventSessionById(widget.sessionId);
      if (session != null) {
        ref.invalidate(totalFeesForDayProvider(session.eventDayId));
      }
    } catch (e) {
      // If we can't get the session, just skip invalidating the day total
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final updatedAssignment = _assignment!.copyWith(
        role: _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
        hourlyRate: double.parse(_hourlyRateController.text),
        updatedAt: DateTime.now(),
      );

      await JudgeAssignmentRepository().updateAssignment(updatedAssignment);
      
      // Invalidate providers
      ref.invalidate(assignmentsByFloorProvider(widget.floorId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating assignment: $e')),
        );
      }
    }
  }

  void _showAddRoleFeeDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddRoleFeeDialog(
        assignmentId: widget.assignmentId,
        onFeeAdded: () {
          ref.invalidate(feesByAssignmentProvider(widget.assignmentId));
          ref.invalidate(totalFeesByAssignmentProvider(widget.assignmentId));
          _invalidateFeeTotals();
        },
      ),
    );
  }

  Future<void> _deleteFee(JudgeFee fee) async {
    if (fee.isAutoCalculated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete auto-calculated fees')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fee'),
        content: Text('Delete ${fee.description}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await JudgeFeeRepository().deleteFee(fee.id);
        ref.invalidate(feesByAssignmentProvider(widget.assignmentId));
        ref.invalidate(totalFeesByAssignmentProvider(widget.assignmentId));
        await _invalidateFeeTotals();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fee deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting fee: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Assignment')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Assignment'),
        actions: [
          TextButton(
            onPressed: _saveAssignment,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Judge Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _assignment!.judgeFullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_assignment!.judgeAssociation} - ${_assignment!.judgeLevel}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Role Field
            TextFormField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role (Optional)',
                hintText: 'e.g., Head Judge, Meet Referee',
                border: OutlineInputBorder(),
                helperText: 'Custom role for this assignment',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Hourly Rate Field
            TextFormField(
              controller: _hourlyRateController,
              decoration: const InputDecoration(
                labelText: 'Hourly Rate',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                helperText: 'Base hourly rate for session fees',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final rate = double.tryParse(value);
                if (rate == null || rate < 0) {
                  return 'Invalid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Role Fees Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Role-Based Fees',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _showAddRoleFeeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Fee'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Fees List - Watch provider instead of local state
            Consumer(
              builder: (context, ref, child) {
                final feesAsync = ref.watch(feesByAssignmentProvider(widget.assignmentId));
                
                return feesAsync.when(
                  data: (fees) {
                    if (fees.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No additional fees. Add role-based fees like Meet Referee or Head Judge bonuses.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    
                    return Column(
                      children: fees.map((fee) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: fee.isAutoCalculated 
                              ? Colors.blue.shade100 
                              : Colors.green.shade100,
                            child: Icon(
                              _getIconForFeeType(fee.feeType),
                              size: 20,
                              color: fee.isAutoCalculated ? Colors.blue : Colors.green,
                            ),
                          ),
                          title: Text(fee.description),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getFeeTypeLabel(fee.feeType)),
                              if (!fee.isTaxable)
                                const Text(
                                  'Non-taxable',
                                  style: TextStyle(fontSize: 11, color: Colors.orange),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${fee.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (!fee.isAutoCalculated) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _deleteFee(fee),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading fees: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Expenses Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expenses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () {
                    context.push('/expenses/add', extra: {
                      'eventId': _eventId,
                      'judgeId': _assignment!.judgeId,
                      'assignmentId': widget.assignmentId,
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Expense Summary
            Consumer(
              builder: (context, ref, child) {
                if (_assignment == null || _eventId == null) {
                  return const SizedBox.shrink();
                }
                
                final expensesAsync = ref.watch(expensesByJudgeAndEventProvider((judgeId: _assignment!.judgeId, eventId: _eventId!)));
                final totalAsync = ref.watch(totalExpensesByJudgeAndEventProvider((judgeId: _assignment!.judgeId, eventId: _eventId!)));
                
                return expensesAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No expenses recorded. Add expenses like mileage, meals, or lodging.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    
                    return Column(
                      children: [
                        // Total expenses card
                        totalAsync.when(
                          data: (total) => Card(
                            color: Colors.orange.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Expenses',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 8),
                        // Expenses list - show all expenses
                        ...expenses.map((expense) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(_getExpenseIcon(expense.category)),
                            title: Text(
                              expense.description ?? _getExpenseCategoryName(expense.category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_getExpenseCategoryName(expense.category)),
                            trailing: Text(
                              '\$${expense.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onTap: () {
                              context.push('/expenses/${expense.id}');
                            },
                          ),
                        )),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stack) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading expenses: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getExpenseIcon(dynamic category) {
    final categoryName = category.toString().split('.').last;
    switch (categoryName) {
      case 'mileage':
        return Icons.directions_car;
      case 'mealsPerDiem':
        return Icons.restaurant;
      case 'lodging':
        return Icons.hotel;
      case 'airfare':
        return Icons.flight;
      case 'parking':
        return Icons.local_parking;
      case 'tolls':
        return Icons.toll;
      case 'transportation':
        return Icons.directions_bus;
      case 'judgeFees':
        return Icons.attach_money;
      default:
        return Icons.more_horiz;
    }
  }

  String _getExpenseCategoryName(dynamic category) {
    final categoryName = category.toString().split('.').last;
    switch (categoryName) {
      case 'mileage':
        return 'Mileage';
      case 'mealsPerDiem':
        return 'Meals & Per Diem';
      case 'lodging':
        return 'Lodging';
      case 'airfare':
        return 'Airfare';
      case 'parking':
        return 'Parking';
      case 'tolls':
        return 'Tolls';
      case 'transportation':
        return 'Transportation';
      case 'judgeFees':
        return 'Judge Fees';
      default:
        return 'Other';
    }
  }

  IconData _getIconForFeeType(FeeType type) {
    switch (type) {
      case FeeType.sessionRate:
        return Icons.schedule;
      case FeeType.meetReferee:
        return Icons.admin_panel_settings;
      case FeeType.headJudge:
        return Icons.workspace_premium;
      case FeeType.custom:
        return Icons.attach_money;
    }
  }

  String _getFeeTypeLabel(FeeType type) {
    switch (type) {
      case FeeType.sessionRate:
        return 'Session Rate';
      case FeeType.meetReferee:
        return 'Meet Referee';
      case FeeType.headJudge:
        return 'Head Judge';
      case FeeType.custom:
        return 'Custom';
    }
  }
}

// Dialog for adding role-based fees
class _AddRoleFeeDialog extends ConsumerStatefulWidget {
  final String assignmentId;
  final VoidCallback onFeeAdded;

  const _AddRoleFeeDialog({
    required this.assignmentId,
    required this.onFeeAdded,
  });

  @override
  ConsumerState<_AddRoleFeeDialog> createState() => _AddRoleFeeDialogState();
}

class _AddRoleFeeDialogState extends ConsumerState<_AddRoleFeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  FeeType _selectedType = FeeType.meetReferee;
  bool _isTaxable = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveFee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await JudgeFeeRepository().createFee(
        judgeAssignmentId: widget.assignmentId,
        feeType: _selectedType,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        isTaxable: _isTaxable,
        isAutoCalculated: false,
      );

      widget.onFeeAdded();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee added successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding fee: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Role-Based Fee'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<FeeType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Fee Type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  FeeType.meetReferee,
                  FeeType.headJudge,
                  FeeType.custom,
                ].map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_getFeeTypeLabel(type)),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      // Auto-fill description based on type
                      if (value == FeeType.meetReferee) {
                        _descriptionController.text = 'Meet Referee';
                      } else if (value == FeeType.headJudge) {
                        _descriptionController.text = 'Head Judge';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0) {
                    return 'Invalid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Taxable'),
                subtitle: const Text('Include in taxable income'),
                value: _isTaxable,
                onChanged: (value) => setState(() => _isTaxable = value),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveFee,
          child: _isSaving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Add Fee'),
        ),
      ],
    );
  }

  String _getFeeTypeLabel(FeeType type) {
    switch (type) {
      case FeeType.sessionRate:
        return 'Session Rate';
      case FeeType.meetReferee:
        return 'Meet Referee';
      case FeeType.headJudge:
        return 'Head Judge';
      case FeeType.custom:
        return 'Custom';
    }
  }
}
