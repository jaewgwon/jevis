import 'package:flutter_test/flutter_test.dart';
import 'package:jevis/jevis.dart';

void main() {
  test('failure includes confidence and every choice probability', () {
    final failure = JevisTestFailure(
        JevisReport(
          goal: 'Save',
          status: JevisStatus.lowConfidence,
          trace: [
            JevisTrace(
              observation: JevisObservation(state: {}, actions: const [
                JevisCandidate('save', 'Tap Save'),
                JevisCandidate('cancel', 'Tap Cancel'),
              ]),
              evaluation: JevisEvaluation(
                goalProbability: .1234,
                actionId: 'save',
                actionConfidence: .4321,
                probabilities: {'save': .6, 'cancel': .3, '__stop__': .1},
              ),
            ),
          ],
        ),
        useColors: false);

    final log = failure.toString();
    expect(log, contains('Jevis goal not reached: lowConfidence'));
    expect(log, contains('Goal probability: 12.34%'));
    expect(log, contains('Confidence: 43.21%'));
    expect(log, contains('Selected action: save'));
    expect(log, contains('Probability'));
    expect(log, contains('Action ID'));
    expect(log, matches(RegExp(r'▶\s+\|\s+60.00%\s+\| save\s+\| Tap Save')));
    expect(log, matches(RegExp(r'30.00%\s+\| cancel\s+\| Tap Cancel')));
    expect(log, matches(RegExp(r'10.00%\s+\| __stop__')));
    expect(log, contains('🧭 Step 1:'));
    expect(log, isNot(contains('\x1B[')));
  });

  test('table sorts choices and summarizes UI descriptions without JSON', () {
    final report = JevisReport(
        goal: 'Settings',
        status: JevisStatus.lowConfidence,
        trace: [
          JevisTrace(
            observation: JevisObservation(state: {}, actions: const [
              JevisCandidate('low',
                  'Tap {"target":"w8","widget":"InkWell","text":["설정"],"state":{"available":true}}'),
              JevisCandidate('high',
                  'Open dropdown {"widget":"DropdownButton<Locale?>","text":["시스템 설정 따름"]}'),
              JevisCandidate(
                  'empty', 'Tap {"target":"w10","widget":"InkWell"}'),
              JevisCandidate('custom', 'Custom {invalid JSON}'),
            ]),
            evaluation: JevisEvaluation(
                goalProbability: .2,
                actionId: 'high',
                actionConfidence: .59,
                probabilities: {
                  'low': .2,
                  'empty': 0,
                  'custom': 0,
                  'high': .8
                }),
          )
        ]);
    final log = JevisTestFailure(report, useColors: false).toString();
    expect(log, contains('Tap 설정 [InkWell]'));
    expect(log, contains('Open dropdown 시스템 설정 따름 [DropdownButton<Locale?>]'));
    expect(log, contains('Tap InkWell (w10)'));
    expect(log, contains('Custom {invalid JSON}'));
    expect(log, isNot(contains('"state"')));
    expect(log.indexOf('80.00%'), lessThan(log.indexOf('20.00% |')));
  });

  test('ANSI colors follow probability boundaries and reset after each value',
      () {
    final report =
        JevisReport(goal: 'Goal', status: JevisStatus.lowConfidence, trace: [
      JevisTrace(
        observation: JevisObservation(state: {}, actions: []),
        evaluation: JevisEvaluation(
            goalProbability: 0,
            actionId: 'a',
            actionConfidence: 1,
            probabilities: {'a': .2, 'b': .2001, 'c': .21, 'd': .59, 'e': .6}),
      )
    ]);
    final log = JevisTestFailure(report, useColors: true).toString();
    for (final value in ['0.00%', '20.00%']) {
      expect(log, contains('\x1B[31m$value\x1B[0m'));
    }
    for (final value in ['20.01%', '21.00%', '59.00%']) {
      expect(log, contains('\x1B[33m$value\x1B[0m'));
    }
    for (final value in ['60.00%', '100.00%']) {
      expect(log, contains('\x1B[32m$value\x1B[0m'));
    }
  });

  test('final verification preserves earlier choice diagnostics', () {
    final observation = JevisObservation(state: {}, actions: []);
    final failure = JevisTestFailure(
        JevisReport(
          goal: 'Save',
          status: JevisStatus.stopped,
          trace: [
            JevisTrace(
              observation: observation,
              evaluation: JevisEvaluation(
                goalProbability: .2,
                actionId: JevisCandidate.stopId,
                actionConfidence: .8,
                probabilities: {'__stop__': 1},
              ),
            ),
            JevisTrace(
              observation: observation,
              evaluation: JevisEvaluation(goalProbability: .3),
            ),
          ],
        ),
        useColors: false);

    final log = failure.toString();
    expect(log, contains('Step 1:'));
    expect(log, contains('Confidence: 80.00%'));
    expect(log, contains('Step 2:'));
    expect(log, contains('Goal probability: 30.00%'));
    expect(log, isNot(contains('Confidence: 0.00%')));
  });

  test('failure without evaluation includes the error without invented scores',
      () {
    final failure = JevisTestFailure(
        JevisReport(
          goal: 'Save',
          status: JevisStatus.error,
          message: 'Connection failed',
          trace: [],
        ),
        useColors: false);

    expect(failure.toString(), contains('Connection failed'));
    expect(failure.toString(), isNot(contains('Confidence:')));
  });
}
