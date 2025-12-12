import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/judge.dart';
import '../../models/judge_level.dart';
import '../../models/judge_certification.dart';
import '../../providers/judge_provider.dart';
import '../../providers/judge_level_provider.dart';
import '../../repositories/judge_certification_repository.dart';

class AddEditJudgeScreen extends ConsumerStatefulWidget {
  final Judge? judge;

  const AddEditJudgeScreen({super.key, this.judge});

  @override
  ConsumerState<AddEditJudgeScreen> createState() => _AddEditJudgeScreenState();
}

class _AddEditJudgeScreenState extends ConsumerState<AddEditJudgeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _notesController;
  late TextEditingController _contactInfoController;

  // Map of association -> selected level ID
  final Map<String, String> _certificationsByAssociation = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.judge?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.judge?.lastName ?? '');
    _notesController = TextEditingController(text: widget.judge?.notes ?? '');
    _contactInfoController = TextEditingController(text: widget.judge?.contactInfo ?? '');
    
    if (widget.judge != null) {
      _loadExistingCertifications();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExistingCertifications() async {
    try {
      final certRepo = JudgeCertificationRepository();
      final certs = await certRepo.getCertificationsForJudge(widget.judge!.id);
      
      // Load levels to get association info
      final levels = await ref.read(judgeLevelsProvider.future);
      final levelMap = {for (var l in levels) l.id: l};
      
      setState(() {
        for (final cert in certs) {
          final level = levelMap[cert.judgeLevelId];
          if (level != null) {
            _certificationsByAssociation[level.association] = cert.judgeLevelId;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading certifications: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _notesController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  Future<void> _saveJudge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Validate at least one certification
    if (_certificationsByAssociation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one certification'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      String judgeId;

      if (widget.judge != null) {
        // Update existing judge
        judgeId = widget.judge!.id;
        final updatedJudge = widget.judge!.copyWith(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          contactInfo: _contactInfoController.text.trim().isEmpty
              ? null
              : _contactInfoController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          updatedAt: now,
        );
        await ref.read(judgeNotifierProvider.notifier).updateJudge(updatedJudge);
      } else {
        // Add new judge and capture the returned judge ID
        final newJudge = await ref.read(judgeNotifierProvider.notifier).addJudge(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          contactInfo: _contactInfoController.text.trim().isEmpty
              ? null
              : _contactInfoController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        judgeId = newJudge.id;
      }

      // Now handle certifications
      final certRepo = JudgeCertificationRepository();
      
      if (widget.judge != null) {
        // Remove all existing certifications
        final existing = await certRepo.getCertificationsForJudge(judgeId);
        for (final cert in existing) {
          await certRepo.deleteCertification(judgeId, cert.judgeLevelId);
        }
      }
      
      // Add all selected certifications (one per association)
      for (final levelId in _certificationsByAssociation.values) {
        final certification = JudgeCertification(
          id: const Uuid().v4(),
          judgeId: judgeId,
          judgeLevelId: levelId,
          certificationDate: now,
          expirationDate: null,
          createdAt: now,
          updatedAt: now,
        );
        await certRepo.createCertification(certification);
      }

      // Refresh the judges list
      ref.invalidate(judgesWithLevelsProvider);
      ref.invalidate(filteredJudgesWithLevelsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.judge != null
                  ? 'Judge updated successfully'
                  : 'Judge added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving judge: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCertificationDialog() {
    final judgeLevelsAsync = ref.read(judgeLevelsProvider);
    
    judgeLevelsAsync.whenData((allLevels) {
      // Group levels by association
      final byAssociation = <String, List<JudgeLevel>>{};
      for (final level in allLevels) {
        byAssociation.putIfAbsent(level.association, () => []).add(level);
      }
      
      // Filter out associations already added
      final availableAssociations = byAssociation.keys
          .where((assoc) => !_certificationsByAssociation.containsKey(assoc))
          .toList()
        ..sort();
      
      if (availableAssociations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All associations already have certifications'),
          ),
        );
        return;
      }
      
      String? selectedAssociation;
      String? selectedLevelId;
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            final availableLevels = selectedAssociation != null
                ? byAssociation[selectedAssociation]!
                : <JudgeLevel>[];
            
            return AlertDialog(
              title: const Text('Add Certification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedAssociation,
                    decoration: const InputDecoration(
                      labelText: 'Association',
                      border: OutlineInputBorder(),
                    ),
                    items: availableAssociations.map((assoc) {
                      return DropdownMenuItem(
                        value: assoc,
                        child: Text(assoc),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedAssociation = value;
                        selectedLevelId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedAssociation != null)
                    DropdownButtonFormField<String>(
                      value: selectedLevelId,
                      decoration: const InputDecoration(
                        labelText: 'Level',
                        border: OutlineInputBorder(),
                      ),
                      items: availableLevels.map((level) {
                        return DropdownMenuItem(
                          value: level.id,
                          child: Text(
                            '${level.level} - \$${level.defaultHourlyRate.toStringAsFixed(2)}/hr',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLevelId = value;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selectedAssociation != null && selectedLevelId != null
                      ? () {
                          setState(() {
                            _certificationsByAssociation[selectedAssociation!] = selectedLevelId!;
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.judge != null;
    final judgeLevelsAsync = ref.watch(judgeLevelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Judge' : 'Add Judge'),
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
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactInfoController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Info',
                        hintText: 'Phone or email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Certifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('add_certification_button'),
                          onPressed: () => _showAddCertificationDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_certificationsByAssociation.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No certifications added. Tap "Add" to add certifications.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      judgeLevelsAsync.when(
                        data: (allLevels) {
                          final levelMap = {for (var l in allLevels) l.id: l};
                          
                          return Column(
                            children: _certificationsByAssociation.entries.map((entry) {
                              final level = levelMap[entry.value];
                              if (level == null) return const SizedBox.shrink();
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(entry.key[0]),
                                  ),
                                  title: Text(level.displayName),
                                  subtitle: Text('\$${level.defaultHourlyRate.toStringAsFixed(2)}/hr'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      setState(() {
                                        _certificationsByAssociation.remove(entry.key);
                                      });
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (error, stack) => Text('Error: $error'),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveJudge,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          isEditing ? 'Update Judge' : 'Add Judge',
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
