import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis/jevis.dart';

class Driver implements JevisDriver {
  int value = 0;
  bool stuck = false, fail = false;
  @override
  Future<JevisObservation> observe() async => JevisObservation(
      state: {'value': value},
      actions: [const JevisCandidate('next', 'Advance')]);
  @override
  Future<void> execute(String id) async {
    if (fail) throw StateError('Action failed');
    if (!stuck) value++;
  }
}

class Brain implements JevisBrain {
  Brain({this.id = 'next', this.confidence = 1, this.target = 2});
  final String id;
  final double confidence;
  final int target;
  final requests = <JevisRequest>[];
  @override
  Future<JevisEvaluation> evaluate(JevisRequest request) async {
    requests.add(request);
    return JevisEvaluation(
        goalProbability:
            request.observation.state['value'] == target ? .99 : .01,
        actionId: id,
        actionConfidence: confidence);
  }
}

void main() {
  test('default thresholds accept 20% actions and a 60% goal', () async {
    final driver = Driver();
    final brain = CallbackBrain((request) async => JevisEvaluation(
        goalProbability: driver.value == 0 ? .59 : .6,
        actionId: 'next',
        actionConfidence: .2));
    final report = await JevisRunner(driver: driver, brain: brain)
        .run('Advance once', 'Advance', 1);

    expect(report.status, JevisStatus.succeeded);
    expect(report.actionsExecuted, 1);
  });

  test('standalone requests default to a 60% goal threshold', () {
    final request = JevisRequest(
        goal: 'Goal',
        actionInstruction: 'Advance',
        initialState: {},
        observation: JevisObservation(state: {}, actions: []),
        history: [],
        remainingAttempts: 1);

    expect(request.goalThreshold, .6);
  });

  for (final historyLimit in [0, 1, 8]) {
    test('explicit before/action/after works with historyLimit=$historyLimit',
        () async {
      final driver = Driver();
      final brain = Brain();
      final runner = JevisRunner(
          driver: driver,
          brain: brain,
          options: JevisOptions(historyLimit: historyLimit));
      await runner.run('Reach two', 'Advance toward the requested value.', 2);
      final first = brain.requests.first.toJson();
      expect(first['previousObservation'], isNull);
      expect(first['executedAction'], isNull);
      for (var i = 1; i < brain.requests.length; i++) {
        final wire = brain.requests[i].toJson();
        expect(wire['previousObservation'],
            brain.requests[i - 1].observation.toJson());
        expect(
            wire['currentObservation'], brain.requests[i].observation.toJson());
        expect(
            wire['executedAction'], {'id': 'next', 'description': 'Advance'});
        expect(wire.containsKey('observation'), false);
        if (historyLimit > 0) {
          expect((wire['history'] as List).last['evaluation'],
              brain.requests[i].history.last.evaluation!.toJson());
        }
        expect(
            (wire['history'] as List)
                .any((h) => h['observation']?['state']?['value'] == i - 1),
            false);
      }
      brain.requests.clear();
      await runner.run(
          'Already reached', 'Advance toward the requested value.', 1);
      expect(brain.requests.single.toJson()['previousObservation'], isNull);
      expect(brain.requests.single.toJson()['executedAction'], isNull);
    });
  }

  test('final observation can complete a goal after the last allowed action',
      () async {
    final driver = Driver();
    final brain = Brain();
    final report = await JevisRunner(driver: driver, brain: brain)
        .run('Reach two', 'Advance toward the requested value.', 2);
    expect(report.status, JevisStatus.succeeded);
    expect(report.actionsExecuted, 2);
    expect(report.trace, hasLength(3));
    expect(brain.requests.last.history, hasLength(2));
    expect(brain.requests.last.initialState['value'], 0);
    expect(brain.requests.last.actionInstruction,
        'Advance toward the requested value.');
  });
  test('unknown action is rejected without execution', () async {
    final driver = Driver();
    final report = await JevisRunner(driver: driver, brain: Brain(id: 'delete'))
        .run('Goal', 'Advance toward the requested value.', 3);
    expect(report.status, JevisStatus.invalidDecision);
    expect(driver.value, 0);
    expect(report.trace.single.evaluation!.actionId, 'delete');
  });
  test('uncertain action is not executed', () async {
    final driver = Driver();
    final report = await JevisRunner(driver: driver, brain: Brain(confidence: .1))
        .run('Goal', 'Advance toward the requested value.', 3);
    expect(report.status, JevisStatus.lowConfidence);
    expect(driver.value, 0);
  });
  test('zero threshold executes uncertain actions until goal or turn limit',
      () async {
    final driver = Driver();
    final report = await JevisRunner(
            driver: driver,
            brain: Brain(confidence: 0),
            options: const JevisOptions(actionThreshold: 0))
        .run('Reach two', 'Advance toward the requested value.', 2);
    expect(report.status, JevisStatus.succeeded);
    expect(report.actionsExecuted, 2);
    final exhausted = await JevisRunner(
            driver: Driver(),
            brain: Brain(confidence: .01, target: 9),
            options: const JevisOptions(actionThreshold: 0))
        .run('Reach nine', 'Advance toward the requested value.', 2);
    expect(exhausted.status, JevisStatus.attemptsExhausted);
    expect(exhausted.actionsExecuted, 2);
  });

  test('instruction-complete stop is not goal success', () async {
    final brain = Brain(id: JevisCandidate.stopId);
    final report = await JevisRunner(driver: Driver(), brain: brain)
        .run('Goal', 'Advance toward the requested value.', 3);
    expect(report.status, JevisStatus.stopped);
    expect(report.actionsExecuted, 0);
    expect(report.message, contains('instruction'));
    expect(brain.requests, hasLength(2));
    expect(brain.requests.last.needsAction, isFalse);
    expect(report.trace, hasLength(2));
  });
  test('stop reobserves and verifies the goal without executing another action',
      () async {
    final driver = Driver();
    final requests = <JevisRequest>[];
    final brain = CallbackBrain((request) async {
      requests.add(request);
      if (requests.length == 1) {
        driver.value = 2;
        return JevisEvaluation(
            goalProbability: .01,
            actionId: JevisCandidate.stopId,
            actionConfidence: 1);
      }
      expect(request.needsAction, isFalse);
      expect(request.observation.state['value'], 2);
      expect(request.previousActions, isEmpty);
      return JevisEvaluation(goalProbability: .99);
    });
    final report = await JevisRunner(driver: driver, brain: brain)
        .run('Reach two', 'Advance toward the requested value.', 1);
    expect(report.status, JevisStatus.succeeded);
    expect(report.actionsExecuted, 0);
    expect(requests, hasLength(2));
    expect(report.trace.first.evaluation!.actionId, JevisCandidate.stopId);
    expect(report.trace.last.observation.state['value'], 2);
  });
  test('failed final verification after stop remains an error', () async {
    final brain = CallbackBrain((request) async {
      if (!request.needsAction) throw StateError('Verification unavailable');
      return JevisEvaluation(
          goalProbability: .01,
          actionId: JevisCandidate.stopId,
          actionConfidence: 1);
    });
    final report = await JevisRunner(driver: Driver(), brain: brain)
        .run('Goal', 'Advance toward the requested value.', 1);
    expect(report.status, JevisStatus.error);
    expect(report.actionsExecuted, 0);
    expect(report.trace.last.error, contains('Verification unavailable'));
  });
  test('all executed actions survive a zero history limit and reset per goal',
      () async {
    final brain = Brain(target: 10);
    final runner = JevisRunner(
        driver: Driver(),
        brain: brain,
        options: const JevisOptions(historyLimit: 0));
    final report = await runner.run('Reach ten', 'Advance ten times', 10);
    expect(report.status, JevisStatus.succeeded);
    for (var i = 0; i < brain.requests.length; i++) {
      expect(brain.requests[i].history, isEmpty);
      expect(brain.requests[i].previousActions, List.filled(i, 'Advance'));
    }
    await runner.run('Already there', 'Advance if needed', 1);
    expect(brain.requests.last.previousActions, isEmpty);
  });

  test('same state and action cannot loop forever', () async {
    final report =
        await JevisRunner(driver: Driver()..stuck = true, brain: Brain())
            .run('Goal', 'Advance toward the requested value.', 10);
    expect(report.status, JevisStatus.repeatedAction);
    expect(report.actionsExecuted, 2);
  });
  test('attempt exhaustion is not success', () async {
    final report = await JevisRunner(driver: Driver(), brain: Brain(target: 9))
        .run('Goal', 'Advance toward the requested value.', 2);
    expect(report.status, JevisStatus.attemptsExhausted);
    expect(report.trace, hasLength(3));
  });
  test('execution failure preserves selected action and evidence', () async {
    final report =
        await JevisRunner(driver: Driver()..fail = true, brain: Brain())
            .run('Goal', 'Advance toward the requested value.', 2);
    expect(report.status, JevisStatus.error);
    expect(report.trace.single.evaluation!.actionId, 'next');
    expect(report.trace.single.error, contains('Action failed'));
    expect(report.actionsExecuted, 0);
  });
  test('each run has fresh history and repetition counters', () async {
    final driver = Driver();
    final brain = Brain();
    final runner = JevisRunner(driver: driver, brain: brain);
    await runner.run('First', 'Advance toward the requested value.', 2);
    driver.value = 0;
    await runner.run('Second', 'Advance toward the requested value.', 2);
    expect(brain.requests[3].history, isEmpty);
    expect(brain.requests[3].goal, 'Second');
  });
  test('invalid input is rejected before any model request', () async {
    final brain = Brain();
    final runner = JevisRunner(driver: Driver(), brain: brain);
    await expectLater(runner.run('', 'Advance toward the requested value.', 2),
        throwsArgumentError);
    await expectLater(
        runner.run('Goal', 'Advance toward the requested value.', 0),
        throwsArgumentError);
    await expectLater(runner.run('Goal', ' ', 2), throwsArgumentError);
    expect(brain.requests, isEmpty);
  });
  test('hanging model is bounded', () async {
    final report = await JevisRunner(
            driver: Driver(),
            brain: HangingBrain(),
            options:
                const JevisOptions(decisionTimeout: Duration(milliseconds: 20)))
        .run('Goal', 'Advance toward the requested value.', 2);
    expect(report.status, JevisStatus.error);
    expect(report.message, contains('TimeoutException'));
  });
}

class HangingBrain implements JevisBrain {
  @override
  Future<JevisEvaluation> evaluate(JevisRequest request) =>
      Completer<JevisEvaluation>().future;
}

class CallbackBrain implements JevisBrain {
  CallbackBrain(this.callback);
  final Future<JevisEvaluation> Function(JevisRequest) callback;

  @override
  Future<JevisEvaluation> evaluate(JevisRequest request) => callback(request);
}
