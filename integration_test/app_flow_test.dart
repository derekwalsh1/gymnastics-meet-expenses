import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:nawgj_expense_tracker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete app flow: Create AAU association, judges, and meet', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Give home screen extra time if initial load lags
    if (find.text('Judges').evaluate().isEmpty) {
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // Navigate to Judges
    final judgesTile = find.text('Judges');
    expect(judgesTile, findsOneWidget);
    await tester.tap(judgesTile);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Judges'), findsOneWidget);

    // Open associations screen via settings icon
    await tester.tap(find.byTooltip('Manage Judge Levels'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Judge Associations'), findsOneWidget);

    Future<void> openAAULevels() async {
      final aauLevelsAppBar = find.widgetWithText(AppBar, 'AAU Levels');
      if (aauLevelsAppBar.evaluate().isNotEmpty) {
        return;
      }

      final aauTile = find.text('AAU');
      if (aauTile.evaluate().isEmpty) {
        // Add association through dialog
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'AAU');
        await tester.tap(find.widgetWithText(TextButton, 'Create'));
        await tester.pumpAndSettle();
        return;
      }

      await tester.tap(aauTile);
      await tester.pumpAndSettle();
    }

    await openAAULevels();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'AAU Levels'), findsOneWidget);

    Future<void> ensureLevel(String levelName, String hourlyRate) async {
      final levelFinder = find.text(levelName);
      if (levelFinder.evaluate().isNotEmpty) {
        return;
      }

      // Open add-level form (empty-state button or FAB)
      final addFirstLevelButton = find.widgetWithText(ElevatedButton, 'Add First Level');
      if (addFirstLevelButton.evaluate().isNotEmpty) {
        await tester.tap(addFirstLevelButton);
      } else {
        await tester.tap(find.byType(FloatingActionButton));
      }
      await tester.pumpAndSettle();

      await tester.enterText(find.bySemanticsLabel('Level'), levelName);
      await tester.enterText(find.bySemanticsLabel('Default Hourly Rate'), hourlyRate);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Judge Level'));
      await tester.pumpAndSettle();
    }

    await ensureLevel('Local', '25');
    await ensureLevel('Regional', '35');
    await ensureLevel('National', '45');

    // Return to Judges screen
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Judges'), findsOneWidget);

    Future<void> addJudgeWithLevel(String first, String last, String levelDisplay) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Add Judge'), findsOneWidget);

      await tester.enterText(find.bySemanticsLabel('First Name'), first);
      await tester.enterText(find.bySemanticsLabel('Last Name'), last);

      // Add certification via keyed button
      final addCertificationButton = find.byKey(const Key('add_certification_button'));
      expect(addCertificationButton, findsOneWidget);
      await tester.tap(addCertificationButton);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Association'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AAU').last);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Level'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(levelDisplay).last);
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Add'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Judge'));
      await tester.pumpAndSettle();
    }

    await addJudgeWithLevel('Alice', 'Local', 'Local - \$25.00/hr');
    await addJudgeWithLevel('Bella', 'Regional', 'Regional - \$35.00/hr');
    await addJudgeWithLevel('Nina', 'National', 'National - \$45.00/hr');

    // Should now be back on Judges list - verify judges exist
    expect(find.widgetWithText(AppBar, 'Judges'), findsOneWidget);
    expect(find.text('Alice Local'), findsOneWidget);
    expect(find.text('Bella Regional'), findsOneWidget);
    expect(find.text('Nina National'), findsOneWidget);

    // Now create a meet
    final uniqueMeetName = 'Test Meet ${DateTime.now().millisecondsSinceEpoch}';

    // Navigate back to Home
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);

    // Navigate to Events → Create Event
    await tester.tap(find.byKey(const Key('events_quick_action')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Events'), findsOneWidget);
    
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Create Event'), findsOneWidget);

    // Step 1: Basic info
    await tester.enterText(find.bySemanticsLabel('Event Name *'), uniqueMeetName);
    await tester.enterText(find.bySemanticsLabel('Venue Name *'), 'Test Venue');
    await tester.enterText(find.bySemanticsLabel('Address *'), '123 Main St');
    await tester.enterText(find.bySemanticsLabel('City *'), 'Springfield');
    await tester.enterText(find.bySemanticsLabel('State *'), 'CA');
    await tester.enterText(find.bySemanticsLabel('Zip *'), '90210');

    // Select AAU association from dropdown if available
    final associationDropdown = find.bySemanticsLabel('Association');
    if (associationDropdown.evaluate().isNotEmpty) {
      await tester.tap(associationDropdown);
      await tester.pumpAndSettle();
      final aauOption = find.text('AAU').last;
      if (aauOption.evaluate().isNotEmpty) {
        await tester.tap(aauOption);
        await tester.pumpAndSettle();
      }
    }

    // Pick start date (accept default)
    await tester.tap(find.text('Start Date *'));
    await tester.pumpAndSettle();
    final okButton = find.text('OK');
    final doneButton = find.text('Done');
    if (okButton.evaluate().isNotEmpty) {
      await tester.tap(okButton);
    } else if (doneButton.evaluate().isNotEmpty) {
      await tester.tap(doneButton);
    }
    await tester.pumpAndSettle();

    // Ensure start date is no longer the placeholder
    if (find.text('Not selected').evaluate().isNotEmpty) {
      fail('Start date was not selected; date picker interaction likely failed');
    }

    // Next to template selection
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // Step 2: Choose Quick Meet template
    await tester.tap(find.text('Quick Meet').first);
    await tester.pumpAndSettle();

    // Next through structure step
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    // Step 4: Review and create
    final createEventButton = find.widgetWithText(ElevatedButton, 'Create Event');
    expect(createEventButton, findsOneWidget);
    await tester.tap(createEventButton);
    await tester.pump();
    // Allow up to 12 seconds for event creation/navigation
    await tester.pumpAndSettle(const Duration(seconds: 12));

    // Look for success or error snackbars to understand creation result
    final successSnack = find.text('Event created successfully!');
    final errorSnack = find.textContaining('Error creating event');
    final startDateSnack = find.text('Please select start date');

    if (startDateSnack.evaluate().isNotEmpty) {
      fail('Event creation blocked: missing start date');
    }

    if (successSnack.evaluate().isEmpty && errorSnack.evaluate().isNotEmpty) {
      // Surface the error snackbar
      fail('Event creation failed: ${(tester.widget<Text>(errorSnack.first)).data}');
    }

    if (successSnack.evaluate().isEmpty && errorSnack.evaluate().isEmpty) {
      if (find.widgetWithText(AppBar, 'Create Event').evaluate().isNotEmpty) {
        fail('Event creation did not submit: still on Create Event screen (validation likely failed)');
      }
    }

    Future<void> navigateHome() async {
      for (int i = 0; i < 3; i++) {
        if (find.text('Welcome').evaluate().isNotEmpty) return;

        final backIcon = find.byIcon(Icons.arrow_back);
        if (backIcon.evaluate().isNotEmpty) {
          await tester.tap(backIcon);
          await tester.pumpAndSettle();
          continue;
        }

        final closeIcon = find.byIcon(Icons.close);
        if (closeIcon.evaluate().isNotEmpty) {
          await tester.tap(closeIcon);
          await tester.pumpAndSettle();
          continue;
        }

        break;
      }
    }

    Future<void> openEventsList() async {
      if (find.widgetWithText(AppBar, 'Events').evaluate().isNotEmpty) {
        return;
      }
      await navigateHome();
      if (find.text('Welcome').evaluate().isNotEmpty) {
        final eventsQuickAction = find.byKey(const Key('events_quick_action'));
        if (eventsQuickAction.evaluate().isNotEmpty) {
          await tester.tap(eventsQuickAction);
          await tester.pumpAndSettle();
        }
      }
    }

    Future<void> waitForEventsToLoad() async {
      // Ensure we are on Events list
      await openEventsList();

      // Wait for loading spinner to disappear
      await tester.pumpAndSettle(const Duration(seconds: 2));
      if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      // Wait for either an event card/list tile or the empty-state text
      final listTileFinder = find.byType(ListTile);
      final emptyTextFinder = find.text('No events yet');
      for (int i = 0; i < 5; i++) {
        if (listTileFinder.evaluate().isNotEmpty || emptyTextFinder.evaluate().isNotEmpty) {
          break;
        }
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    }

    await waitForEventsToLoad();

    if (find.text(uniqueMeetName).evaluate().isEmpty) {
      final texts = tester.widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      // ignore: avoid_print
      print('DEBUG visible texts: ${texts.take(50).toList()}');
    }

    expect(find.text(uniqueMeetName), findsOneWidget);
  });
}
