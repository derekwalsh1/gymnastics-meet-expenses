import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_level_provider.dart';
import '../../repositories/event_repository.dart';
import '../../repositories/judge_assignment_repository.dart';
import '../../repositories/event_day_repository.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EditEventScreen({super.key, required this.eventId});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _startDate;
  String? _selectedAssociationId;
  bool _isLoading = true;
  bool _hasJudgesAssigned = false;
  Event? _event;
  List<dynamic> _eventDays = [];

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final event = await EventRepository().getEventById(widget.eventId);
      
      // Check if any judges are assigned
      final assignments = await JudgeAssignmentRepository().getAssignmentsByEventId(widget.eventId);
      
      // Load event days
      final eventDays = await EventDayRepository().getEventDaysByEventId(widget.eventId);
      
      if (event != null && mounted) {
        setState(() {
          _event = event;
          _hasJudgesAssigned = assignments.isNotEmpty;
          _eventDays = eventDays;
          _nameController.text = event.name;
          _venueController.text = event.location.venueName;
          _addressController.text = event.location.address;
          _cityController.text = event.location.city;
          _stateController.text = event.location.state;
          _zipController.text = event.location.zipCode;
          _descriptionController.text = event.description ?? '';
          _startDate = event.startDate;
          _selectedAssociationId = event.associationId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  EventStatus _calculateStatus(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (now.isBefore(start)) {
      return EventStatus.upcoming;
    } else if (now.isAfter(end)) {
      return EventStatus.completed;
    } else {
      return EventStatus.ongoing;
    }
  }

  Future<void> _recalculateEventDayDates() async {
    final dayRepo = EventDayRepository();
    
    // Update each event day to have consecutive dates from new start date
    for (int i = 0; i < _eventDays.length; i++) {
      final day = _eventDays[i];
      final newDate = _startDate!.add(Duration(days: i));
      
      final updatedDay = day.copyWith(
        date: newDate,
        updatedAt: DateTime.now(),
      );
      
      await dayRepo.updateEventDay(updatedDay);
      _eventDays[i] = updatedDay;
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date')),
      );
      return;
    }

    try {
      // Recalculate event day dates if start date changed
      final originalStartDate = _event!.startDate;
      if (_startDate!.isAtSameMomentAs(originalStartDate) == false) {
        await _recalculateEventDayDates();
      }
      
      // Calculate end date from event days count
      final dayCount = _eventDays.length;
      final endDate = dayCount > 0 
        ? _startDate!.add(Duration(days: dayCount - 1))
        : _startDate!;
      
      final updatedEvent = _event!.copyWith(
        name: _nameController.text.trim(),
        location: EventLocation(
          venueName: _venueController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          state: _stateController.text.trim(),
          zipCode: _zipController.text.trim(),
        ),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        startDate: _startDate!,
        endDate: endDate,
        associationId: _selectedAssociationId,
        status: _calculateStatus(_startDate!, endDate),
        updatedAt: DateTime.now(),
      );

      await EventRepository().updateEvent(updatedEvent);
      
      // Invalidate providers to refresh data
      ref.invalidate(eventProvider(widget.eventId));
      ref.invalidate(eventsProvider);
      ref.invalidate(filteredEventsProvider);
      ref.invalidate(upcomingEventsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final judgeLevelsAsync = ref.watch(judgeLevelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Event Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter event name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    judgeLevelsAsync.when(
                      data: (levels) {
                        final associations = levels.map((l) => l.association).toSet().toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedAssociationId,
                              decoration: InputDecoration(
                                labelText: 'Association',
                                border: const OutlineInputBorder(),
                                helperText: _hasJudgesAssigned 
                                  ? 'Cannot change association after judges are assigned'
                                  : null,
                                helperStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                              items: associations.map((assoc) {
                                return DropdownMenuItem(
                                  value: assoc,
                                  child: Text(assoc),
                                );
                              }).toList(),
                              onChanged: _hasJudgesAssigned ? null : (value) {
                                setState(() {
                                  _selectedAssociationId = value;
                                });
                              },
                            ),
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error loading associations'),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Dates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setState(() {
                            _startDate = date;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _startDate == null
                            ? 'Start Date'
                            : 'Start: ${DateFormat('MMM d, yyyy').format(_startDate!)}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_startDate != null && _eventDays.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'End Date: ${DateFormat('MMM d, yyyy').format(_startDate!.add(Duration(days: _eventDays.length - 1)))}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        '${_eventDays.length} day${_eventDays.length == 1 ? '' : 's'} (consecutive dates)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _venueController,
                      decoration: const InputDecoration(
                        labelText: 'Venue Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter venue name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _zipController,
                            decoration: const InputDecoration(
                              labelText: 'ZIP',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Additional Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveEvent,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
