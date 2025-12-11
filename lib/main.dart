import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/judges/judges_list_screen.dart';
import 'screens/judges/judge_import_export_screen.dart';
import 'screens/judges/judge_level_import_export_screen.dart';
import 'screens/judges/associations_screen.dart';
import 'screens/judges/judge_levels_screen.dart';
import 'screens/judges/add_edit_judge_level_screen.dart';
import 'screens/events/events_list_screen.dart';
import 'screens/events/create_event_wizard_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/event_structure_screen.dart';
import 'screens/events/event_day_detail_screen.dart';
import 'screens/events/event_session_detail_screen.dart';
import 'screens/events/event_expenses_screen.dart';
import 'screens/events/edit_event_screen.dart';
import 'screens/events/assign_judge_screen.dart';
import 'screens/events/edit_assignment_screen.dart';
import 'screens/events/add_event_day_screen.dart';
import 'screens/events/add_event_session_screen.dart';
import 'screens/events/add_event_floor_screen.dart';
import 'screens/events/floor_detail_screen.dart';
import 'screens/events/floor_apparatus_assign_screen.dart';
import 'screens/meets/meet_export_screen.dart';
import 'screens/meets/meet_import_screen.dart';
import 'screens/import_meet_screen.dart';
import 'screens/fees/manage_fees_screen.dart';
import 'screens/expenses/expense_list_screen.dart';
import 'screens/expenses/add_edit_expense_screen.dart';
import 'screens/expenses/expense_detail_screen.dart';
import 'screens/reports/reports_list_screen.dart';
import 'screens/reports/event_report_detail_screen.dart';
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
      title: 'Gymnastics Judging Expense Tracker',
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
      path: '/import-meet',
      builder: (context, state) => const ImportMeetScreen(),
    ),
    GoRoute(
      path: '/judges',
      builder: (context, state) => const JudgesListScreen(),
    ),
    GoRoute(
      path: '/judges/import-export',
      builder: (context, state) => const JudgeImportExportScreen(),
    ),
    GoRoute(
      path: '/associations',
      builder: (context, state) => const AssociationsScreen(),
    ),
    GoRoute(
      path: '/judge-levels/import-export',
      builder: (context, state) => const JudgeLevelImportExportScreen(),
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
      path: '/events/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EditEventScreen(eventId: id);
      },
    ),
    GoRoute(
      path: '/events/:eventId/structure',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        return EventStructureScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/add-day',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        return AddEventDayScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/days/:dayId/add-session',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final dayId = state.pathParameters['dayId']!;
        return AddEventSessionScreen(eventId: eventId, dayId: dayId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/sessions/:sessionId/add-floor',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final sessionId = state.pathParameters['sessionId']!;
        return AddEventFloorScreen(eventId: eventId, sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/days/:dayId/sessions/:sessionId/floors/:floorId',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final dayId = state.pathParameters['dayId']!;
        final sessionId = state.pathParameters['sessionId']!;
        final floorId = state.pathParameters['floorId']!;
        return FloorDetailScreen(
          eventId: eventId,
          dayId: dayId,
          sessionId: sessionId,
          floorId: floorId,
        );
      },
    ),
    GoRoute(
      path: '/events/:eventId/days/:dayId/sessions/:sessionId/floors/:floorId/assign-apparatus',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final dayId = state.pathParameters['dayId']!;
        final sessionId = state.pathParameters['sessionId']!;
        final floorId = state.pathParameters['floorId']!;
        final apparatus = state.uri.queryParameters['apparatus']!;
        return FloorApparatusAssignScreen(
          eventId: eventId,
          dayId: dayId,
          sessionId: sessionId,
          floorId: floorId,
          apparatus: apparatus,
        );
      },
    ),
    GoRoute(
      path: '/events/:eventId/expenses',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        return EventExpensesScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/export',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final meetName = state.uri.queryParameters['meetName'] ?? 'Meet';
        return MeetExportScreen(eventId: eventId, meetName: meetName);
      },
    ),
    GoRoute(
      path: '/events/:eventId/import',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        return MeetImportScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/days/:dayId',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final dayId = state.pathParameters['dayId']!;
        return EventDayDetailScreen(eventId: eventId, dayId: dayId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/days/:dayId/sessions/:sessionId',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final dayId = state.pathParameters['dayId']!;
        final sessionId = state.pathParameters['sessionId']!;
        return EventSessionDetailScreen(
          eventId: eventId,
          dayId: dayId,
          sessionId: sessionId,
        );
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
      path: '/assignments/:assignmentId/edit',
      builder: (context, state) {
        final assignmentId = state.pathParameters['assignmentId']!;
        final floorId = state.uri.queryParameters['floorId']!;
        final sessionId = state.uri.queryParameters['sessionId']!;
        return EditAssignmentScreen(
          assignmentId: assignmentId,
          floorId: floorId,
          sessionId: sessionId,
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/expenses',
      builder: (context, state) {
        final eventId = state.uri.queryParameters['eventId'];
        final judgeId = state.uri.queryParameters['judgeId'];
        final assignmentId = state.uri.queryParameters['assignmentId'];
        return ExpenseListScreen(
          eventId: eventId,
          judgeId: judgeId,
          assignmentId: assignmentId,
        );
      },
    ),
    GoRoute(
      path: '/expenses/add',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AddEditExpenseScreen(
          eventId: extra?['eventId'],
          judgeId: extra?['judgeId'],
          assignmentId: extra?['assignmentId'],
        );
      },
    ),
    GoRoute(
      path: '/expenses/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ExpenseDetailScreen(expenseId: id);
      },
    ),
    GoRoute(
      path: '/expenses/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AddEditExpenseScreen(expenseId: id);
      },
    ),
    // Reports
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsListScreen(),
    ),
    GoRoute(
      path: '/reports/event/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EventReportDetailScreen(eventId: id);
      },
    ),
  ],
);
