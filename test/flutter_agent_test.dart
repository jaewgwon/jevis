import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis_flutter/jevis_flutter.dart';
import 'runner_test.dart' show HangingBrain;

class DoneBrain implements JevisBrain {
  final requests = <JevisRequest>[];
  @override
  Future<JevisEvaluation> evaluate(JevisRequest request) async {
    requests.add(request);
    return JevisEvaluation(goalProbability: .99);
  }
}

void main() {
  for (final instruction in [null, 'Tap Save.']) {
    testWidgets('named test parameters with instruction=$instruction',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Text('Saved')));
      final brain = DoneBrain();
      final agent = JevisTester(tester: tester, actions: [], brain: brain);
      final report = instruction == null
          ? await agent.test(goal: 'Saved is visible.', attempts: 3)
          : await agent.test(
              goal: 'Saved is visible.', instruction: instruction, attempts: 3);
      expect(report.succeeded, isTrue);
      expect(brain.requests.single.goal, 'Saved is visible.');
      expect(brain.requests.single.actionInstruction,
          instruction ?? 'Saved is visible.');
      expect(brain.requests.single.remainingAttempts, 3);
    });
  }
  testWidgets('disabled and offstage actions are not offered', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Column(children: [
      ElevatedButton(
          key: ValueKey('disabled'), onPressed: null, child: Text('Disabled')),
      Offstage(
          child: TextButton(
              key: ValueKey('hidden'), onPressed: null, child: Text('Hidden'))),
    ])));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.tap('Disabled', key: 'disabled'),
      JevisAction.tap('Hidden', key: 'hidden'),
    ]);
    expect((await driver.observe()).actions, isEmpty);
  });
  testWidgets('disappeared action is rejected at execution time',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: TextButton(
            key: const ValueKey('go'),
            onPressed: () {},
            child: const Text('Go'))));
    final driver = JevisFlutterDriver(
        tester: tester, actions: [JevisAction.tap('Go', key: 'go')]);
    final id = (await driver.observe()).actions.single.id;
    await tester.pumpWidget(const SizedBox());
    await expectLater(driver.execute(id), throwsStateError);
  });
  testWidgets('obscured fields do not expose their value to observations',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: TextField(key: ValueKey('password'), obscureText: true))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.enterText('Enter password', key: 'password', value: 'secret')
    ]);
    await driver.execute((await driver.observe()).actions.single.id);
    final control =
        ((await driver.observe()).state['controls'] as List).single as Map;
    expect(control.containsKey('value'), isFalse);
    expect(control['empty'], isFalse);
  });
  testWidgets('optional assertion can reject a false model completion',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Not completed')));
    final agent = JevisTester(tester: tester, actions: [], brain: DoneBrain());
    await expectLater(
        agent.test(
            goal: 'Goal',
            instruction: 'Use the available controls to create and complete the requested items.',
            attempts: 3,
            verify: () => false),
        throwsA(isA<JevisTestFailure>().having(
            (e) => e.report.status, 'status', JevisStatus.verificationFailed)));
    expect(agent.lastReport!.completionBasis, 'model+assertion');
  });
  testWidgets('timeout operates in real async zone', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final agent = JevisTester(
        tester: tester,
        actions: [],
        brain: HangingBrain(),
        options: const JevisOptions(decisionTimeout: Duration(milliseconds: 20)));
    await expectLater(
        agent.test(
            goal: 'Goal',
            instruction: 'Use the available controls to create and complete the requested items.',
            attempts: 1),
        throwsA(isA<JevisTestFailure>().having(
            (e) => e.report.message, 'message', contains('TimeoutException'))));
  }, timeout: const Timeout(Duration(seconds: 3)));
  test('target selector must be unambiguous', () {
    expect(() => JevisAction.tap('Go'), throwsArgumentError);
    expect(() => JevisAction.tap('Go', key: 'go', finder: find.text('Go')),
        throwsArgumentError);
  });
}
