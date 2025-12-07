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
