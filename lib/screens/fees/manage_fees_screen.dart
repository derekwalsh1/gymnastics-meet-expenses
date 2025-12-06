import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/judge_fee.dart';
import '../../providers/judge_fee_provider.dart';

class ManageFeesScreen extends ConsumerStatefulWidget {
  final String assignmentId;
  final String judgeName;

  const ManageFeesScreen({
    super.key,
    required this.assignmentId,
    required this.judgeName,
  });

  @override
  ConsumerState<ManageFeesScreen> createState() => _ManageFeesScreenState();
}

class _ManageFeesScreenState extends ConsumerState<ManageFeesScreen> {
  @override
  Widget build(BuildContext context) {
    final feesAsync = ref.watch(feesByAssignmentProvider(widget.assignmentId));
    final totalFeesAsync = ref.watch(totalFeesByAssignmentProvider(widget.assignmentId));
    final taxableFeesAsync = ref.watch(totalTaxableFeesByAssignmentProvider(widget.assignmentId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Fees - ${widget.judgeName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Totals Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Fees:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      totalFeesAsync.when(
                        data: (total) => Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Error'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Taxable:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      taxableFeesAsync.when(
                        data: (taxable) => Text(
                          '\$${taxable.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        loading: () => const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => const Text('Error'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Fees List
          Expanded(
            child: feesAsync.when(
              data: (fees) {
                if (fees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No fees yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add a fee',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: fees.length,
                  itemBuilder: (context, index) {
                    final fee = fees[index];
                    return _FeeCard(
                      fee: fee,
                      onEdit: () => _showAddEditFeeDialog(fee: fee),
                      onDelete: () => _confirmDeleteFee(fee),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading fees: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditFeeDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEditFeeDialog({JudgeFee? fee}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditFeeDialog(
        assignmentId: widget.assignmentId,
        fee: fee,
        onSaved: () {
          ref.invalidate(feesByAssignmentProvider(widget.assignmentId));
          ref.invalidate(totalFeesByAssignmentProvider(widget.assignmentId));
          ref.invalidate(totalTaxableFeesByAssignmentProvider(widget.assignmentId));
        },
      ),
    );
  }

  Future<void> _confirmDeleteFee(JudgeFee fee) async {
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final repository = ref.read(judgeFeeRepositoryProvider);
        await repository.deleteFee(fee.id);
        ref.invalidate(feesByAssignmentProvider(widget.assignmentId));
        ref.invalidate(totalFeesByAssignmentProvider(widget.assignmentId));
        ref.invalidate(totalTaxableFeesByAssignmentProvider(widget.assignmentId));
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
}

class _FeeCard extends StatelessWidget {
  final JudgeFee fee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FeeCard({
    required this.fee,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: fee.isAutoCalculated
              ? Colors.blue.shade100
              : Colors.green.shade100,
          child: Icon(
            _getIconForFeeType(fee.type),
            color: fee.isAutoCalculated ? Colors.blue : Colors.green,
          ),
        ),
        title: Text(
          fee.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getFeeTypeLabel(fee.type)),
            if (fee.hours != null)
              Text('${fee.hours} hours @ \$${fee.hourlyRate?.toStringAsFixed(2) ?? '0.00'}/hr'),
            Row(
              children: [
                if (fee.isTaxable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Taxable',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
                if (fee.isAutoCalculated) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Auto',
                      style: TextStyle(fontSize: 10, color: Colors.blue),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${fee.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!fee.isAutoCalculated) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _getIconForFeeType(FeeType type) {
    switch (type) {
      case FeeType.sessionRate:
        return Icons.schedule;
      case FeeType.bonus:
        return Icons.star;
      case FeeType.meetReferee:
        return Icons.admin_panel_settings;
      case FeeType.headJudge:
        return Icons.workspace_premium;
      case FeeType.travel:
        return Icons.directions_car;
      case FeeType.other:
        return Icons.attach_money;
    }
  }

  String _getFeeTypeLabel(FeeType type) {
    switch (type) {
      case FeeType.sessionRate:
        return 'Session Rate';
      case FeeType.bonus:
        return 'Bonus';
      case FeeType.meetReferee:
        return 'Meet Referee';
      case FeeType.headJudge:
        return 'Head Judge';
      case FeeType.travel:
        return 'Travel';
      case FeeType.other:
        return 'Other';
    }
  }
}

class _AddEditFeeDialog extends ConsumerStatefulWidget {
  final String assignmentId;
  final JudgeFee? fee;
  final VoidCallback onSaved;

  const _AddEditFeeDialog({
    required this.assignmentId,
    this.fee,
    required this.onSaved,
  });

  @override
  ConsumerState<_AddEditFeeDialog> createState() => _AddEditFeeDialogState();
}

class _AddEditFeeDialogState extends ConsumerState<_AddEditFeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _hoursController;
  late TextEditingController _rateController;
  
  FeeType _selectedType = FeeType.bonus;
  bool _isTaxable = true;
  bool _useHourly = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.fee?.description ?? '');
    _amountController = TextEditingController(
      text: widget.fee?.amount.toStringAsFixed(2) ?? '',
    );
    _hoursController = TextEditingController(
      text: widget.fee?.hours?.toString() ?? '',
    );
    _rateController = TextEditingController(
      text: widget.fee?.hourlyRate?.toStringAsFixed(2) ?? '',
    );
    
    if (widget.fee != null) {
      _selectedType = widget.fee!.type;
      _isTaxable = widget.fee!.isTaxable;
      _useHourly = widget.fee!.hours != null;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _hoursController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.fee == null ? 'Add Fee' : 'Edit Fee'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                items: FeeType.values
                    .where((type) => type != FeeType.sessionRate)
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_getFeeTypeLabel(type)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
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
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Calculate by hours'),
                value: _useHourly,
                onChanged: (value) {
                  setState(() => _useHourly = value);
                },
              ),
              if (_useHourly) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hoursController,
                        decoration: const InputDecoration(
                          labelText: 'Hours',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          if (double.tryParse(value!) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _rateController,
                        decoration: const InputDecoration(
                          labelText: 'Rate/hr',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Required';
                          if (double.tryParse(value!) == null) return 'Invalid number';
                          return null;
                        },
                        onChanged: (value) => _updateAmount(),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (double.tryParse(value!) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Taxable'),
                value: _isTaxable,
                onChanged: (value) {
                  setState(() => _isTaxable = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saveFee,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _updateAmount() {
    if (_useHourly) {
      final hours = double.tryParse(_hoursController.text);
      final rate = double.tryParse(_rateController.text);
      if (hours != null && rate != null) {
        _amountController.text = (hours * rate).toStringAsFixed(2);
      }
    }
  }

  Future<void> _saveFee() async {
    if (!_formKey.currentState!.validate()) return;

    if (_useHourly) {
      _updateAmount();
    }

    try {
      final repository = ref.read(judgeFeeRepositoryProvider);
      final now = DateTime.now();

      final fee = JudgeFee(
        id: widget.fee?.id ?? const Uuid().v4(),
        judgeAssignmentId: widget.assignmentId,
        type: _selectedType,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        hours: _useHourly ? double.tryParse(_hoursController.text) : null,
        hourlyRate: _useHourly ? double.tryParse(_rateController.text) : null,
        isTaxable: _isTaxable,
        isAutoCalculated: false,
        createdAt: widget.fee?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.fee == null) {
        await repository.createFee(fee);
      } else {
        await repository.updateFee(fee);
      }

      widget.onSaved();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.fee == null ? 'Fee added' : 'Fee updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving fee: $e')),
        );
      }
    }
  }

  String _getFeeTypeLabel(FeeType type) {
    switch (type) {
      case FeeType.sessionRate:
        return 'Session Rate';
      case FeeType.bonus:
        return 'Bonus';
      case FeeType.meetReferee:
        return 'Meet Referee';
      case FeeType.headJudge:
        return 'Head Judge';
      case FeeType.travel:
        return 'Travel';
      case FeeType.other:
        return 'Other';
    }
  }
}
