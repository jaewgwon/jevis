import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis_flutter/jevis_flutter.dart';

class ReactiveBrain implements JevisBrain {
  final requests = <JevisRequest>[];
  @override
  Future<JevisEvaluation> evaluate(JevisRequest request) async {
    requests.add(request);
    final text = request.observation.state['visibleText'] as List;
    return JevisEvaluation(
      goalProbability: text.contains('Count: 2') ? .99 : .01,
      actionId: request.observation.actions.isEmpty
          ? null
          : request.observation.actions.last.id,
      actionConfidence: .95,
    );
  }
}

void main() {
  testWidgets('test pumps an app started with runApp before observing',
      (tester) async {
    runApp(const MaterialApp(home: Text('Count: 2')));
    final report = await JevisTester(
            tester: tester, brain: ReactiveBrain(), actions: [])
        .test(goal: 'Reach count two', instruction: 'Tap Increment until the count is two.', attempts: 2);
    expect(report.succeeded, isTrue);
  });

  testWidgets(
      'two-call API observes new state and lets brain choose every action',
      (tester) async {
    var count = 0;
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
                    body: Column(children: [
                  Text('Count: $count'),
                  TextButton(
                      key: const ValueKey('increment'),
                      onPressed: () => setState(() => count++),
                      child: const Text('Increment')),
                ])))));
    final brain = ReactiveBrain();
    final agent = JevisTester(tester: tester, brain: brain, actions: [
      JevisAction.tap('Increment count', key: 'increment'),
    ]);
    final report = await agent.test(
        goal: 'Reach count two', instruction: 'Tap Increment until the count is two.', attempts: 2);
    expect(report.succeeded, isTrue);
    expect(report.actionsExecuted, 2);
    expect(brain.requests, hasLength(3));
    expect(
        brain.requests.every((r) =>
            r.actionInstruction == 'Tap Increment until the count is two.'),
        isTrue);
    expect(brain.requests.last.remainingAttempts, 0);
    expect(
        brain.requests.last.initialState['visibleText'], contains('Count: 0'));
    expect(report.completionBasis, 'model');
  });

  testWidgets('unreached goal throws instead of silently returning failure',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Not done')));
    final agent =
        JevisTester(tester: tester, brain: ReactiveBrain(), actions: []);
    await expectLater(
        agent.test(
            goal: 'Reach count two', instruction: 'Tap Increment until the count is two.', attempts: 3),
        throwsA(isA<JevisTestFailure>()
            .having((e) => e.report.status, 'status', JevisStatus.noActions)));
  });

  testWidgets('goal can be reached on a screen with no available actions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Count: 2')));
    final report = await JevisTester(
            tester: tester, brain: ReactiveBrain(), actions: [])
        .test(goal: 'Reach count two', instruction: 'Tap Increment until the count is two.', attempts: 2);
    expect(report.actionsExecuted, 0);
  });

  testWidgets(
      'inline values and checkbox state are observable without callbacks',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      TextField(key: const ValueKey('title'), controller: controller),
      CheckboxListTile(
          key: const ValueKey('item'),
          title: const Text('Milk'),
          value: true,
          onChanged: (_) {}),
    ]))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.enterText('Enter title', key: 'title', value: 'Milk'),
      JevisAction.tap('Toggle item', key: 'item'),
    ]);
    var observation = await driver.observe();
    expect((observation.state['controls'] as List).last['checked'], true);
    await driver.execute(observation.actions.first.id);
    observation = await driver.observe();
    expect((observation.state['controls'] as List).first['value'], 'Milk');
  });
}
