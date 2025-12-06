import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/event.dart';
import '../../models/event_floor.dart';
import '../../models/event_session.dart';
import '../../models/judge_with_level.dart';
import '../../models/judge_level.dart';
import '../../providers/event_provider.dart';
import '../../providers/judge_provider.dart';
import '../../providers/judge_assignment_provider.dart';
import '../../repositories/event_floor_repository.dart';
import '../../repositories/event_session_repository.dart';
import '../../repositories/judge_assignment_repository.dart';

class AssignJudgeScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String floorId;
  final String sessionId;

  const AssignJudgeScreen({
    super.key,
    required this.eventId,
    required this.floorId,
    required this.sessionId,
  });

  @override
  ConsumerState<AssignJudgeScreen> createState() => _AssignJudgeScreenState();
}

class _AssignJudgeScreenState extends ConsumerState<AssignJudgeScreen> {
  final Set<String> selectedJudgeIds = {};
  String? selectedRole;
  double? customHourlyRate;
  final TextEditingController _rateController = TextEditingController();
  String _searchQuery = '';
  bool _assigningJudges = false;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Assign Judge'),
      ),
      body: eventAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text('Event not found'));
          }
          return _buildContent(event);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading event: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(Event event) {
    return FutureBuilder<(EventFloor?, EventSession?)>(
      future: () async {
        final floor = await EventFloorRepository().getEventFloorById(widget.floorId);
        final session = await EventSessionRepository().getEventSessionById(widget.sessionId);
        return (floor, session);
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final (floor, session) = snapshot.data ?? (null, null);

        if (floor == null || session == null) {
          return const Center(child: Text('Floor or session not found'));
        }

        return Column(
          children: [
            _buildHeader(event, floor, session),
            const Divider(height: 1),
            _buildSearchBar(),
            const Divider(height: 1),
            Expanded(child: _buildJudgesList(event, session)),
            if (selectedJudgeIds.isNotEmpty) ...[
              const Divider(height: 1),
              _buildAssignmentDetails(event, session),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(Event event, EventFloor floor, EventSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('${session.name} - ${floor.name}'),
                  ],
                ),
              ),
              if (selectedJudgeIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${selectedJudgeIds.length} selected',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (event.associationId != null) ...[
            const SizedBox(height: 4),
            Chip(
              label: Text(event.associationId!, style: const TextStyle(fontSize: 12)),
              backgroundColor: Colors.blue[100],
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Search judges...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
      ),
    );
  }

  Widget _buildJudgesList(Event event, EventSession session) {
    // Get all judges with their certifications
    final judgesAsync = ref.watch(judgesWithLevelsProvider);
    
    // Get available judge IDs (no conflicts)
    final availableJudgesAsync = ref.watch(
      availableJudgesForSessionProvider(widget.sessionId),
    );

    return judgesAsync.when(
      data: (allJudges) {
        return availableJudgesAsync.when(
          data: (availableJudgeIds) {
            // Filter judges by association and availability
            final filteredJudges = allJudges.where((judgeWithLevels) {
              // Check if judge has certification for event's association
              if (event.associationId != null) {
                final hasCertification = judgeWithLevels.levels.any(
                  (level) => level.association == event.associationId,
                );
                if (!hasCertification) return false;
              }

              // Check if judge is available (no conflicts)
              if (!availableJudgeIds.contains(judgeWithLevels.judge.id)) {
                return false;
              }

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                final fullName = '${judgeWithLevels.judge.firstName} ${judgeWithLevels.judge.lastName}'.toLowerCase();
                if (!fullName.contains(_searchQuery)) {
                  return false;
                }
              }

              return true;
            }).toList();

            if (filteredJudges.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No judges match your search'
                            : event.associationId != null
                                ? 'No available ${event.associationId} judges'
                                : 'No available judges',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (allJudges.length > filteredJudges.length) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${allJudges.length - filteredJudges.length} judges already assigned or in conflict',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: filteredJudges.length,
              itemBuilder: (context, index) {
                final judgeWithLevels = filteredJudges[index];
                return _buildJudgeCard(judgeWithLevels, event);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildJudgeCard(JudgeWithLevels judgeWithLevels, Event event) {
    final judge = judgeWithLevels.judge;
    final isSelected = selectedJudgeIds.contains(judge.id);

    // Get the level for this event's association
    JudgeLevel? relevantLevel;
    if (event.associationId != null) {
      try {
        relevantLevel = judgeWithLevels.levels.firstWhere(
          (level) => level.association == event.associationId,
        );
      } catch (_) {
        // No level found
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected ? Colors.blue[50] : null,
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                selectedJudgeIds.add(judge.id);
              } else {
                selectedJudgeIds.remove(judge.id);
              }
            });
          },
        ),
        title: Text('${judge.firstName} ${judge.lastName}'),
        subtitle: relevantLevel != null
            ? Text(
                '${relevantLevel.association} - ${relevantLevel.level}',
                style: const TextStyle(fontSize: 12),
              )
            : null,
        trailing: relevantLevel != null
            ? Text(
                '\$${relevantLevel.defaultHourlyRate.toStringAsFixed(2)}/hr',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              )
            : null,
        selected: isSelected,
        onTap: () {
          setState(() {
            if (isSelected) {
              selectedJudgeIds.remove(judge.id);
            } else {
              selectedJudgeIds.add(judge.id);
            }
          });
        },
      ),
    );
  }

  Widget _buildAssignmentDetails(Event event, EventSession session) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Assign ${selectedJudgeIds.length} ${selectedJudgeIds.length == 1 ? 'Judge' : 'Judges'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Role (Optional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            initialValue: selectedRole,
            items: const [
              DropdownMenuItem(value: null, child: Text('No specific role')),
              DropdownMenuItem(value: 'Meet Referee', child: Text('Meet Referee')),
              DropdownMenuItem(value: 'Head Judge', child: Text('Head Judge')),
              DropdownMenuItem(value: 'Panel Judge', child: Text('Panel Judge')),
              DropdownMenuItem(value: 'Floor Judge', child: Text('Floor Judge')),
            ],
            onChanged: (value) {
              setState(() {
                selectedRole = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rateController,
            decoration: const InputDecoration(
              labelText: 'Custom Hourly Rate (Optional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixText: '\$ ',
              helperText: 'Leave empty to use default rate for each judge',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              setState(() {
                customHourlyRate = parsed;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _assigningJudges ? null : () {
                    setState(() {
                      selectedJudgeIds.clear();
                      selectedRole = null;
                      customHourlyRate = null;
                      _rateController.clear();
                    });
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _assigningJudges ? null : _assignJudges,
                  child: _assigningJudges
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Assign Judges'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _assignJudges() async {
    if (selectedJudgeIds.isEmpty) return;

    setState(() {
      _assigningJudges = true;
    });

    try {
      final judges = await ref.read(judgesWithLevelsProvider.future);
      final event = await ref.read(eventProvider(widget.eventId).future);
      if (event == null) throw Exception('Event not found');

      int successCount = 0;
      int failCount = 0;

      // Assign all selected judges
      for (final judgeId in selectedJudgeIds) {
        try {
          final selectedJudge = judges.firstWhere((j) => j.judge.id == judgeId);

          await JudgeAssignmentRepository().createAssignment(
            eventFloorId: widget.floorId,
            judge: selectedJudge,
            association: event.associationId ?? '',
            role: selectedRole,
            customHourlyRate: customHourlyRate,
          );
          successCount++;
        } catch (e) {
          failCount++;
          print('Error assigning judge $judgeId: $e');
        }
      }

      if (mounted) {
        // Invalidate providers to refresh data
        ref.invalidate(assignmentsByFloorProvider(widget.floorId));
        ref.invalidate(availableJudgesForSessionProvider(widget.sessionId));

        // Clear selection after successful assignment
        setState(() {
          selectedJudgeIds.clear();
          selectedRole = null;
          customHourlyRate = null;
          _rateController.clear();
          _assigningJudges = false;
        });

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failCount > 0
                    ? '$successCount judge(s) assigned successfully, $failCount failed'
                    : '$successCount judge(s) assigned successfully',
              ),
            ),
          );
        }

        // Don't pop - allow assigning more judges
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _assigningJudges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning judges: $e')),
        );
      }
    }
  }
}
