import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../repositories/event_repository.dart';
import '../repositories/event_day_repository.dart';
import '../repositories/event_session_repository.dart';
import '../repositories/event_floor_repository.dart';

// Repository providers
final eventRepositoryProvider = Provider((ref) => EventRepository());
final eventDayRepositoryProvider = Provider((ref) => EventDayRepository());
final eventSessionRepositoryProvider = Provider((ref) => EventSessionRepository());
final eventFloorRepositoryProvider = Provider((ref) => EventFloorRepository());

// Event list provider
final eventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  return await repository.getAllEvents();
});

// Upcoming events provider
final upcomingEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  return await repository.getUpcomingEvents();
});

// Past events provider
final pastEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  return await repository.getPastEvents();
});

// Single event provider
final eventProvider = FutureProvider.family<Event?, String>((ref, id) async {
  final repository = ref.watch(eventRepositoryProvider);
  return await repository.getEventById(id);
});

// Events by status provider
final eventsByStatusProvider = FutureProvider.family<List<Event>, EventStatus>((ref, status) async {
  final repository = ref.watch(eventRepositoryProvider);
  return await repository.getAllEvents(status: status);
});

// Events by association provider
final eventsByAssociationProvider = FutureProvider.family<List<Event>, String>((ref, associationId) async {
  final repository = ref.watch(eventRepositoryProvider);
  return await repository.getEventsByAssociation(associationId);
});

// Event filter state
final eventStatusFilterProvider = StateProvider<EventStatus?>((ref) => null);
final eventSearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered events provider
final filteredEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  final statusFilter = ref.watch(eventStatusFilterProvider);
  final searchQuery = ref.watch(eventSearchQueryProvider);

  var events = await repository.getAllEvents(status: statusFilter);

  if (searchQuery.isNotEmpty) {
    final query = searchQuery.toLowerCase();
    events = events.where((event) {
      return event.name.toLowerCase().contains(query) ||
             event.location.venueName.toLowerCase().contains(query) ||
             event.location.city.toLowerCase().contains(query) ||
             event.description.toLowerCase().contains(query);
    }).toList();
  }

  return events;
});
