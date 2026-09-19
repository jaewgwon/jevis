import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jevis/jevis.dart';
import 'package:jevis_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  todoTest(
    'Add multiple todos, select 2 of them.',
    actions: [
      JevisActions.enterText(values: [
        'Buy milk',
        'Clean up',
        'Send email',
        'Call mom',
      ])
    ],
    run: (agent) async {
      await agent.test(
        goal: 'Can find "Total: 4 | Completed: 2',
        instruction:
            'Add four todos: "Buy milk, Clean up, Send email, Call mom". Then set Call mom and Clean up finished.',
        attempts: 60,
      );
    },
  );
  catalogTest(
    'Jevis submits a form through keyboard actions',
    discoverTaps: false,
    actions: [
      JevisActions.enterText(values: ['Alex', 'alex@example.com']),
      JevisActions.keyboardAction(),
    ],
    run: (agent) async {
      await agent.test(
        goal:
            'The Widget Catalog displays "Submitted name: Alex; email: alex@example.com".',
        instruction:
            'Navigate to Widget Catalog. Enter Alex in Name and alex@example.com in Email, then submit with the Email keyboard Done action.',
        attempts: 60,
      );
      expect(find.text('Submitted name: Alex; email: alex@example.com'),
          findsOneWidget);
    },
  );

  catalogTest(
    'Jevis clears previously entered form values',
    discoverTaps: false,
    actions: [
      JevisActions.enterText(values: ['Alex', 'alex@example.com']),
      JevisActions.clearText(),
      JevisActions.keyboardAction(),
    ],
    run: (agent) async {
      await agent.test(
        goal:
            'The Widget Catalog displays "Submitted name: Alex; email: alex@example.com".',
        instruction:
            'Navigate to Widget Catalog. Enter Alex in Name and alex@example.com in Email, then submit with the Email keyboard Done action.',
        attempts: 60,
      );
      expect(find.text('Submitted name: Alex; email: alex@example.com'),
          findsOneWidget);
      await agent.test(
        goal: 'The Widget Catalog displays "Submitted name: ; email: ".',
        instruction:
            'Clear the Name and Email inputs, then submit the empty form with the Email keyboard Done action.',
        attempts: 40,
      );
      expect(find.text('Submitted name: ; email: '), findsOneWidget);
    },
  );

  catalogTest(
    'Jevis reveals a delete button by holding a note and deletes it',
    actions: [
      JevisActions.longPress(
        instruction: 'Hold Sample note in Long press to reveal Delete note.',
      ),
    ],
    run: (agent) async {
      await agent.test(
        goal: 'The Widget Catalog displays "Delete button: Hidden".',
        instruction:
            'Navigate to Widget Catalog, and scroll until you see "Delete button: Hidden".',
        attempts: 20,
      );
      await agent.test(
        goal: 'The Widget Catalog displays "Delete button: Visible".',
        instruction: 'Hold sample note to reveal the delete button.',
        attempts: 20,
      );
      expect(find.text('Delete button: Visible'), findsOneWidget);
      await agent.test(
        goal: 'The Widget Catalog displays "Item deleted".',
        instruction:
            'Delete Sample note using the revealed Delete note button.',
        attempts: 20,
      );
      expect(find.text('Item deleted'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog_long_press')), findsNothing);
    },
  );

  catalogTest(
    'Jevis swipes a message to archive it',
    actions: [
      JevisActions.drag(
        offset: const Offset(-300, 0),
        instruction: 'Swipe Sample message left in Swipe to archive.',
      ),
    ],
    run: (agent) async {
      await agent.test(
        goal: 'The Widget Catalog displays "Message archived".',
        instruction:
            'Navigate to Widget Catalog. Scroll to Sample message in Swipe to archive, then swipe the message left.',
        attempts: 40,
      );
      expect(find.byKey(const ValueKey('catalog_swipe_item')), findsNothing);
    },
  );

  catalogTest(
    'Jevis holds and delivers a parcel to the drop zone',
    actions: [
      JevisActions.dragTo(
        destination: find.byKey(const ValueKey('catalog_drop_target')),
        holdDuration: const Duration(milliseconds: 1000),
        instruction: 'Hold Parcel, then move it onto Drop zone.',
      ),
    ],
    run: (agent) async {
      await agent.test(
        goal: 'The Widget Catalog displays "Drop status: Delivered".',
        instruction:
            'Navigate to Widget Catalog. Scroll until Parcel and Drop zone are visible, then hold Parcel and drag it onto Drop zone.',
        attempts: 50,
      );
      expect(find.text('Drop status: Delivered'), findsOneWidget);
    },
  );

  catalogTest(
    'Jevis changes dropdown priority in both directions',
    actions: [JevisActions.selectOption()],
    run: (agent) async {
      await agent.test(
        goal: 'The Widget Catalog displays "Selected priority: High".',
        instruction:
            'Navigate to Widget Catalog. Scroll to Priority, open its dropdown and select High priority.',
        attempts: 50,
      );
      expect(find.text('Selected priority: High'), findsOneWidget);
      await agent.test(
        goal: 'The Widget Catalog displays "Selected priority: Low".',
        instruction: 'Open the Priority dropdown and select Low priority.',
        attempts: 30,
      );
      expect(find.text('Selected priority: Low'), findsOneWidget);
    },
  );

  catalogTest(
    'Jevis accepts and unchecks the terms checkbox',
    actions: [],
    run: (agent) async {
      await agent.test(
        goal: 'The Widget Catalog displays "Terms: Accepted".',
        instruction:
            'Navigate to Widget Catalog. Scroll to Accept terms and check the checkbox.',
        attempts: 40,
      );
      expect(find.text('Terms: Accepted'), findsOneWidget);
      await agent.test(
        goal: 'The Widget Catalog displays "Terms: Not accepted".',
        instruction: 'Uncheck the Accept terms checkbox.',
        attempts: 30,
      );
      expect(find.text('Terms: Not accepted'), findsOneWidget);
    },
  );

  catalogTest(
    'Jevis switches notifications on and off',
    actions: [],
    run: (agent) async {
      await agent.test(
        goal: 'The Widget Catalog displays "Notifications: On".',
        instruction:
            'Navigate to Widget Catalog. Scroll to Notifications and turn the switch on.',
        attempts: 40,
      );
      expect(find.text('Notifications: On'), findsOneWidget);
      await agent.test(
        goal: 'The Widget Catalog displays "Notifications: Off".',
        instruction: 'Turn the Notifications switch off.',
        attempts: 30,
      );
      expect(find.text('Notifications: Off'), findsOneWidget);
    },
  );

  catalogTest(
    'Jevis increases the volume slider',
    actions: [JevisActions.adjustSlider()],
    run: (agent) async {
      await agent.test(
        goal: 'The Widget Catalog displays "Volume: 70%".',
        instruction:
            'Navigate to Widget Catalog. Scroll to the Volume slider and increase it to 70 percent.',
        attempts: 50,
      );
      expect(find.text('Volume: 70%'), findsOneWidget);
    },
  );

  catalogTest(
    'Jevis loads data and observes the ready result',
    actions: [JevisActions.wait()],
    run: (agent) async {
      // Normal settling may finish the loading before a separate wait is chosen.
      await agent.test(
        goal:
            'The Widget Catalog displays "Load status: Ready" and "Data is ready".',
        instruction:
            'Navigate to Widget Catalog. Scroll to Async loading, press Load data and wait for loading to finish.',
        attempts: 50,
      );
      expect(find.text('Load status: Ready'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog_loaded')), findsOneWidget);
      expect(find.byKey(const ValueKey('catalog_loading')), findsNothing);
    },
  );
}

@isTest
void todoTest(
  String name, {
  required List<JevisAction> actions,
  required Future<void> Function(JevisTester agent) run,
}) {
  testWidgets(
    name,
    (tester) async {
      app.main();
      await tester.pumpAndSettle();
      final agent = JevisTester(
        tester: tester,
        options: const JevisOptions(goalThreshold: .6, actionThreshold: .2),
        actions: [
          JevisActions.tap(),
          JevisActions.scroll(),
          ...actions,
        ],
      );
      await run(agent);
    },
    timeout: const Timeout(
      Duration(minutes: 5),
    ),
  );
}

@isTest
void catalogTest(
  String name, {
  required List<JevisAction> actions,
  required Future<void> Function(JevisTester agent) run,
  bool discoverTaps = true,
}) {
  testWidgets(
    name,
    (tester) async {
      app.main();
      await tester.pumpAndSettle();
      final agent = JevisTester(
        tester: tester,
        options: const JevisOptions(goalThreshold: .6, actionThreshold: .2),
        actions: [
          if (discoverTaps)
            JevisActions.tap()
          else
            JevisAction.tap('Open the Widget Catalog tab.', key: 'tab_catalog'),
          JevisActions.scroll(),
          ...actions,
        ],
        onReport: (report) {
          if (const bool.fromEnvironment('JEVIS_DIAGNOSTICS')) {
            _logHttpBody(
              jsonEncode(
                {
                  'test': name,
                  'goal': report.goal,
                  'status': report.status.name,
                  'actionsExecuted': report.actionsExecuted,
                  if (report.message != null) 'message': report.message,
                },
              ),
            );
          }
        },
      );
      await run(agent);
    },
    timeout: const Timeout(
      Duration(minutes: 5),
    ),
  );
}

void _logHttpBody(String body) {
  var formatted = body;
  try {
    formatted = const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
  } on FormatException {
    // Preserve non-JSON error responses as received.
  }
  for (final line in formatted.split('\n')) {
    // ignore: avoid_print
    print(line);
  }
  // ignore: avoid_print
  print('');
}
