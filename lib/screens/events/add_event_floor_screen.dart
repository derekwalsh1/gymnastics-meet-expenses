import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_fee_provider.dart';

class AddEventFloorScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String sessionId;

  const AddEventFloorScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
  });

  @override
  ConsumerState<AddEventFloorScreen> createState() => _AddEventFloorScreenState();
}

class _AddEventFloorScreenState extends ConsumerState<AddEventFloorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _selectedColor;

  final List<Map<String, dynamic>> _floorColors = [
    {'name': 'Red', 'value': 'red', 'color': Colors.red},
    {'name': 'Blue', 'value': 'blue', 'color': Colors.blue},
    {'name': 'Green', 'value': 'green', 'color': Colors.green},
    {'name': 'White', 'value': 'white', 'color': Colors.white},
    {'name': 'Black', 'value': 'black', 'color': Colors.black},
    {'name': 'Pink', 'value': 'pink', 'color': Colors.pink},
    {'name': 'Yellow', 'value': 'yellow', 'color': Colors.yellow},
    {'name': 'Orange', 'value': 'orange', 'color': Colors.orange},
    {'name': 'Lavender', 'value': 'lavender', 'color': const Color(0xFFE6E6FA)},
    {'name': 'Beige', 'value': 'beige', 'color': const Color(0xFFF5F5DC)},
    {'name': 'Silver', 'value': 'silver', 'color': const Color(0xFFC0C0C0)},
    {'name': 'Bronze', 'value': 'bronze', 'color': const Color(0xFFCD7F32)},
    {'name': 'Gold', 'value': 'gold', 'color': const Color(0xFFFFD700)},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveFloor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get next floor number
      final existingFloors = await EventFloorRepository().getEventFloorsBySessionId(widget.sessionId);
      final nextFloorNumber = existingFloors.length + 1;

      final floor = await EventFloorRepository().createEventFloor(
        eventSessionId: widget.sessionId,
        floorNumber: nextFloorNumber,
        name: _nameController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        color: _selectedColor,
      );

      // Get session to invalidate day fees
      final session = await EventSessionRepository().getEventSessionById(widget.sessionId);

      ref.invalidate(eventProvider(widget.eventId));
      ref.invalidate(totalFeesForSessionProvider(widget.sessionId));
      if (session != null) {
        ref.invalidate(totalFeesForDayProvider(session.eventDayId));
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Floor added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding floor: $e')),
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
        title: const Text('Add Floor'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Floor Name',
                hintText: 'e.g., Vault, Bars, Beam, Floor',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a floor name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Additional information',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Floor Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _floorColors.map((colorData) {
                final isSelected = _selectedColor == colorData['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorData['value']),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorData['color'],
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade400,
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: colorData['value'] == 'white' || colorData['value'] == 'yellow' || colorData['value'] == 'beige' ? Colors.black : Colors.white,
                            size: 30,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveFloor,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Floor'),
            ),
          ],
        ),
      ),
    );
  }
}
