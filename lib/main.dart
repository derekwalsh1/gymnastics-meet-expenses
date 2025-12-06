import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/judges/judges_list_screen.dart';
import 'screens/judges/associations_screen.dart';
import 'screens/judges/judge_levels_screen.dart';
import 'screens/judges/add_edit_judge_level_screen.dart';
import 'screens/events/events_list_screen.dart';
import 'screens/events/create_event_wizard_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/assign_judge_screen.dart';
import 'screens/fees/manage_fees_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await DatabaseService.instance.database;
  
  runApp(
    const ProviderScope(
      child: NAWGJExpenseTrackerApp(),
    ),
  );
}

class NAWGJExpenseTrackerApp extends StatelessWidget {
  const NAWGJExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NAWGJ Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/judges',
      builder: (context, state) => const JudgesListScreen(),
    ),
    GoRoute(
      path: '/associations',
      builder: (context, state) => const AssociationsScreen(),
    ),
    GoRoute(
      path: '/judge-levels/:association',
      builder: (context, state) {
        final association = state.pathParameters['association']!;
        return JudgeLevelsScreen(association: association);
      },
    ),
    GoRoute(
      path: '/judge-levels/:association/add',
      builder: (context, state) {
        final association = state.pathParameters['association']!;
        return AddEditJudgeLevelScreen(association: association);
      },
    ),
    GoRoute(
      path: '/judge-levels/:association/edit/:id',
      builder: (context, state) {
        final association = state.pathParameters['association']!;
        final id = state.pathParameters['id']!;
        return AddEditJudgeLevelScreen(
          association: association,
          judgeLevelId: id,
        );
      },
    ),
    GoRoute(
      path: '/events',
      builder: (context, state) => const EventsListScreen(),
    ),
    GoRoute(
      path: '/events/create',
      builder: (context, state) => const CreateEventWizardScreen(),
    ),
    GoRoute(
      path: '/events/:eventId/floors/:floorId/assign-judge',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final floorId = state.pathParameters['floorId']!;
        final sessionId = state.uri.queryParameters['sessionId']!;
        return AssignJudgeScreen(
          eventId: eventId,
          floorId: floorId,
          sessionId: sessionId,
        );
      },
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventDetailScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/events/:eventId/floors/:floorId/assign-judge',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final floorId = state.pathParameters['floorId']!;
        final sessionId = state.uri.queryParameters['sessionId']!;
        return AssignJudgeScreen(
          eventId: eventId,
          floorId: floorId,
          sessionId: sessionId,
        );
      },
    ),
    GoRoute(
      path: '/assignments/:assignmentId/fees',
      builder: (context, state) {
        final assignmentId = state.pathParameters['assignmentId']!;
        final judgeName = state.uri.queryParameters['judgeName'] ?? 'Judge';
        return ManageFeesScreen(
          assignmentId: assignmentId,
          judgeName: judgeName,
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
