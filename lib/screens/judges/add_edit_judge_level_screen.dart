import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/judge_level.dart';
import '../../providers/judge_level_provider.dart';

class AddEditJudgeLevelScreen extends ConsumerStatefulWidget {
  final String association;
  final String? judgeLevelId;

  const AddEditJudgeLevelScreen({
    super.key,
    required this.association,
    this.judgeLevelId,
  });

  @override
  ConsumerState<AddEditJudgeLevelScreen> createState() => _AddEditJudgeLevelScreenState();
}

class _AddEditJudgeLevelScreenState extends ConsumerState<AddEditJudgeLevelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _levelController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  
  late String _selectedAssociation;
  bool _isLoading = false;
  JudgeLevel? _existingLevel;

  @override
  void initState() {
    super.initState();
    _selectedAssociation = widget.association;
    if (widget.judgeLevelId != null) {
      _loadJudgeLevel();
    }
  }

  Future<void> _loadJudgeLevel() async {
    setState(() => _isLoading = true);
    try {
      final level = await ref.read(judgeLevelNotifierProvider.notifier).getJudgeLevel(widget.judgeLevelId!);
      if (level != null && mounted) {
        setState(() {
          _existingLevel = level;
          _selectedAssociation = level.association;
          _levelController.text = level.level;
          _hourlyRateController.text = level.defaultHourlyRate.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading judge level: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _levelController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _saveJudgeLevel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hourlyRate = double.parse(_hourlyRateController.text.trim());
      
      if (_existingLevel != null) {
        // Update existing level
        final updatedLevel = JudgeLevel(
          id: _existingLevel!.id,
          association: _selectedAssociation,
          level: _levelController.text.trim(),
          defaultHourlyRate: hourlyRate,
          sortOrder: _existingLevel!.sortOrder,
          createdAt: _existingLevel!.createdAt,
          updatedAt: DateTime.now(),
          isArchived: _existingLevel!.isArchived,
        );
        await ref.read(judgeLevelNotifierProvider.notifier).updateJudgeLevel(updatedLevel);
      } else {
        // Add new level
        await ref.read(judgeLevelNotifierProvider.notifier).addJudgeLevel(
          association: _selectedAssociation,
          level: _levelController.text.trim(),
          defaultHourlyRate: hourlyRate,
          sortOrder: 999, // Default to end of list
        );
      }

      // Refresh the judge levels list
      ref.invalidate(judgeLevelsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingLevel != null
                  ? 'Judge level updated successfully'
                  : 'Judge level added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving judge level: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.judgeLevelId != null ? 'Edit Judge Level' : 'Add Judge Level'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Display association (read-only)
                    TextFormField(
                      initialValue: _selectedAssociation,
                      decoration: const InputDecoration(
                        labelText: 'Association',
                        border: OutlineInputBorder(),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _levelController,
                      decoration: const InputDecoration(
                        labelText: 'Level',
                        hintText: 'e.g., Nine, Ten, Elite',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a level';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hourlyRateController,
                      decoration: const InputDecoration(
                        labelText: 'Default Hourly Rate',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an hourly rate';
                        }
                        final rate = double.tryParse(value.trim());
                        if (rate == null || rate <= 0) {
                          return 'Please enter a valid rate';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveJudgeLevel,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          widget.judgeLevelId != null ? 'Update Judge Level' : 'Add Judge Level',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
