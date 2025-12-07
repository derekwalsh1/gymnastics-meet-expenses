import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/event.dart';
import '../../models/event_template.dart';
import '../../models/judge_level.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_level_provider.dart';
import '../../repositories/event_day_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/event_floor_repository.dart';

class CreateEventWizardScreen extends ConsumerStatefulWidget {
  const CreateEventWizardScreen({super.key});

  @override
  ConsumerState<CreateEventWizardScreen> createState() => _CreateEventWizardScreenState();
}

class _CreateEventWizardScreenState extends ConsumerState<CreateEventWizardScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Basic Info
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

  // Step 2: Template Selection
  EventTemplate? _selectedTemplate;

  // Step 3: Customize Structure
  int _numberOfDays = 1;
  int _sessionsPerDay = 1;
  int _floorsPerSession = 1;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (_startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start date')),
        );
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createEvent() async {
    // Validate basic info
    if (_formKey.currentState?.validate() == false) return;
    
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date')),
      );
      return;
    }

    print('DEBUG: Starting event creation...');
    
    try {
      final eventRepo = ref.read(eventRepositoryProvider);
      final dayRepo = EventDayRepository();
      final sessionRepo = EventSessionRepository();
      final floorRepo = EventFloorRepository();

      print('DEBUG: Creating event with name: ${_nameController.text}');
      
      // Calculate end date from start date and number of days
      final endDate = _startDate!.add(Duration(days: _numberOfDays - 1));
      
      // Calculate status based on dates
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      
      final EventStatus eventStatus;
      if (today.isAfter(end)) {
        eventStatus = EventStatus.completed;
      } else if (today.isBefore(start)) {
        eventStatus = EventStatus.upcoming;
      } else {
        // Today is between start and end (inclusive)
        eventStatus = EventStatus.ongoing;
      }
      
      // Create the event
      final event = await eventRepo.createEvent(
        name: _nameController.text,
        startDate: _startDate!,
        endDate: endDate,
        status: eventStatus,
        location: EventLocation(
          venueName: _venueController.text,
          address: _addressController.text,
          city: _cityController.text,
          state: _stateController.text,
          zipCode: _zipController.text,
        ),
        description: _descriptionController.text,
        associationId: _selectedAssociationId,
      );

      print('DEBUG: Event created with ID: ${event.id}');
      print('DEBUG: Creating $_numberOfDays days, $_sessionsPerDay sessions, $_floorsPerSession floors');

      // Create event structure based on template/customization
      final sessionTimes = _selectedTemplate?.sessionTimes ?? [];
      
      for (int dayNum = 1; dayNum <= _numberOfDays; dayNum++) {
        final dayDate = _startDate!.add(Duration(days: dayNum - 1));
        final eventDay = await dayRepo.createEventDay(
          eventId: event.id,
          dayNumber: dayNum,
          date: dayDate,
        );
        
        print('DEBUG: Created day $dayNum with ID: ${eventDay.id}');

        for (int sessionNum = 1; sessionNum <= _sessionsPerDay; sessionNum++) {
          final sessionTemplate = sessionNum <= sessionTimes.length
              ? sessionTimes[sessionNum - 1]
              : sessionTimes.isNotEmpty
                  ? sessionTimes[0]
                  : null;

          final session = await sessionRepo.createEventSession(
            eventDayId: eventDay.id,
            sessionNumber: sessionNum,
            name: sessionTemplate?.name ?? 'Session $sessionNum',
            startTime: sessionTemplate?.startTime ?? const TimeOfDay(hour: 9, minute: 0),
            endTime: sessionTemplate?.endTime ?? const TimeOfDay(hour: 17, minute: 0),
          );
          
          print('DEBUG: Created session $sessionNum with ID: ${session.id}');

          for (int floorNum = 1; floorNum <= _floorsPerSession; floorNum++) {
            await floorRepo.createEventFloor(
              eventSessionId: session.id,
              floorNumber: floorNum,
              name: _floorsPerSession > 1 ? 'Floor $floorNum' : 'Main Floor',
            );
            print('DEBUG: Created floor $floorNum');
          }
        }
      }

      print('DEBUG: Event structure creation complete!');

      // Invalidate providers to refresh data
      ref.invalidate(filteredEventsProvider);
      ref.invalidate(eventsProvider);
      ref.invalidate(upcomingEventsProvider);
      
      print('DEBUG: Providers invalidated');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
        context.go('/events');
      }
    } catch (e, stackTrace) {
      print('DEBUG: Error creating event: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/events'),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(),
          
          // Page view
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildBasicInfoStep(),
                _buildTemplateSelectionStep(),
                _buildCustomizeStructureStep(),
                _buildReviewStep(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStepCircle(0, 'Info'),
          Expanded(child: _buildStepLine(0)),
          _buildStepCircle(1, 'Template'),
          Expanded(child: _buildStepLine(1)),
          _buildStepCircle(2, 'Structure'),
          Expanded(child: _buildStepLine(2)),
          _buildStepCircle(3, 'Review'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Theme.of(context).primaryColor : Colors.grey[300],
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Theme.of(context).primaryColor : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = _currentStep > step;
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isActive ? Theme.of(context).primaryColor : Colors.grey[300],
    );
  }

  Widget _buildBasicInfoStep() {
    final judgeLevelsAsync = ref.watch(judgeLevelsProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Basic Event Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Event Name *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          judgeLevelsAsync.when(
            data: (levels) {
              final associations = levels.map((l) => l.association).toSet().toList()..sort();
              return DropdownButtonFormField<String>(
                value: _selectedAssociationId,
                decoration: const InputDecoration(
                  labelText: 'Association',
                  border: OutlineInputBorder(),
                ),
                items: associations.map((assoc) {
                  return DropdownMenuItem(value: assoc, child: Text(assoc));
                }).toList(),
                onChanged: (value) => setState(() => _selectedAssociationId = value),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Error loading associations'),
          ),
          const SizedBox(height: 16),

          ListTile(
            title: const Text('Start Date *'),
            subtitle: Text(_startDate?.toString().split(' ')[0] ?? 'Not selected'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 3650)), // 10 years ago
                lastDate: DateTime.now().add(const Duration(days: 730)), // 2 years ahead
              );
              if (date != null) setState(() => _startDate = date);
            },
          ),
          if (_startDate != null && _numberOfDays > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'End Date: ${_startDate!.add(Duration(days: _numberOfDays - 1)).toString().split(' ')[0]}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _venueController,
            decoration: const InputDecoration(
              labelText: 'Venue Name *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'Zip *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelectionStep() {
    final templates = EventTemplate.predefinedTemplates;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Select Event Template',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a template to quickly set up your event structure',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        ...templates.map((template) {
          final isSelected = _selectedTemplate?.type == template.type;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected 
                ? Theme.of(context).colorScheme.primaryContainer 
                : null,
            elevation: isSelected ? 4 : 1,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTemplate = template;
                  _numberOfDays = template.days;
                  _sessionsPerDay = template.sessionsPerDay;
                  _floorsPerSession = template.floorsPerSession;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Radio<EventTemplateType>(
                      value: template.type,
                      groupValue: _selectedTemplate?.type,
                      onChanged: (value) {
                        setState(() {
                          _selectedTemplate = template;
                          _numberOfDays = template.days;
                          _sessionsPerDay = template.sessionsPerDay;
                          _floorsPerSession = template.floorsPerSession;
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${template.days} day(s) • ${template.sessionsPerDay} session(s)/day • ${template.floorsPerSession} floor(s)/session',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomizeStructureStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Customize Event Structure',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Adjust the structure to fit your event needs',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),

        ListTile(
          title: const Text('Number of Days'),
          subtitle: Text('$_numberOfDays day(s)'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _numberOfDays > 1
                    ? () => setState(() => _numberOfDays--)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _numberOfDays++),
              ),
            ],
          ),
        ),
        const Divider(),

        ListTile(
          title: const Text('Sessions Per Day'),
          subtitle: Text('$_sessionsPerDay session(s)'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _sessionsPerDay > 1
                    ? () => setState(() => _sessionsPerDay--)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _sessionsPerDay++),
              ),
            ],
          ),
        ),
        const Divider(),

        ListTile(
          title: const Text('Floors Per Session'),
          subtitle: Text('$_floorsPerSession floor(s)'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _floorsPerSession > 1
                    ? () => setState(() => _floorsPerSession--)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _floorsPerSession++),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event Summary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Total Days: $_numberOfDays'),
                Text('Total Sessions: ${_numberOfDays * _sessionsPerDay}'),
                Text('Total Floors: ${_numberOfDays * _sessionsPerDay * _floorsPerSession}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Review Event Details',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildReviewSection('Event Information', [
          _buildReviewItem('Name', _nameController.text),
          _buildReviewItem('Association', _selectedAssociationId ?? 'None'),
          _buildReviewItem('Dates', '${_startDate?.toString().split(' ')[0]} - ${_startDate?.add(Duration(days: _numberOfDays - 1)).toString().split(' ')[0]}'),
          _buildReviewItem('Venue', _venueController.text),
          _buildReviewItem('Location', '${_cityController.text}, ${_stateController.text}'),
        ]),

        const SizedBox(height: 16),

        _buildReviewSection('Event Structure', [
          _buildReviewItem('Template', _selectedTemplate?.name ?? 'Custom'),
          _buildReviewItem('Days', '$_numberOfDays'),
          _buildReviewItem('Sessions per Day', '$_sessionsPerDay'),
          _buildReviewItem('Floors per Session', '$_floorsPerSession'),
          _buildReviewItem('Total Sessions', '${_numberOfDays * _sessionsPerDay}'),
          _buildReviewItem('Total Floors', '${_numberOfDays * _sessionsPerDay * _floorsPerSession}'),
        ]),
      ],
    );
  }

  Widget _buildReviewSection(String title, List<Widget> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep == 3 ? _createEvent : _nextStep,
              child: Text(_currentStep == 3 ? 'Create Event' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}
