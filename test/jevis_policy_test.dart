import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jevis/jevis.dart';

JevisRequest request(
        {int remaining = 3,
        bool actions = true,
        List<JevisCandidate> candidates = const [
          JevisCandidate('add', 'Add todo')
        ]}) =>
    JevisRequest(
        goal: 'Create and complete a todo',
        actionInstruction: 'Action-only instruction',
        initialState: {'empty': true},
        observation: JevisObservation(state: {
          'visibleText': ['Todos']
        }, actions: actions ? candidates : []),
        history: [],
        remainingAttempts: remaining);
Map<String, Object?> response(
        {double goal = .01,
        String choice = 'add',
        Map<String, double>? probabilities}) =>
    {
      'model': 'jev-1.13.0',
      'answers': {
        'goal_reached': {'type': 'noul', 'noul': goal},
        'next_action': {
          'type': 'choice',
          'choice': choice,
          'confidence': .8,
          'probabilities': probabilities ?? {'add': .9, '__stop__': .1}
        },
      },
    };
void main() {
  test('Choice offers instruction-complete stop and accepts zero confidence',
      () async {
    var calls = 0;
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((r) async {
          calls++;
          final body = jsonDecode(r.body);
          if (calls == 2) {
            expect((body['questions']['next_action']['criteria'] as Map).keys,
                ['add', '__stop__']);
            expect(body['questions']['next_action']['instructions'],
                contains('previousActions'));
            expect(body['state']['previousActions'], isEmpty);
          }
          final result = response();
          ((result['answers'] as Map)['next_action'] as Map)['confidence'] = 0;
          return http.Response(jsonEncode(result), 200);
        }));
    final result = await client.evaluate(request());
    expect(result.actionId, 'add');
    expect(result.actionConfidence, 0);
    expect(calls, 2);
  });

  test('instruction-complete stop is accepted without claiming goal success',
      () async {
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((_) async => http.Response(
            jsonEncode(response(
                choice: '__stop__',
                probabilities: {'add': .1, '__stop__': .9})),
            200)));
    final result = await client.evaluate(request());
    expect(result.actionId, JevisCandidate.stopId);
    expect(result.goalProbability, .01);
  });

  test('only Choice receives ordered executed actions including repeats',
      () async {
    var calls = 0;
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((r) async {
          calls++;
          final body = jsonDecode(r.body);
          if (calls == 1) {
            expect(body['state'].containsKey('previousActions'), isFalse);
            expect(r.body, isNot(contains('doubleTap')));
          } else {
            expect(body['state']['previousActions'],
                ['scroll()', 'doubleTap()', 'doubleTap()']);
            expect(body['state'].containsKey('goal'), isFalse);
          }
          return http.Response(jsonEncode(response()), 200);
        }));
    final original = request();
    await client.evaluate(JevisRequest(
        goal: original.goal,
        actionInstruction: 'Repeat the requested gesture.',
        initialState: {},
        observation: original.observation,
        history: [],
        remainingAttempts: 5,
        previousActions: ['scroll()', 'doubleTap()', 'doubleTap()']));
    expect(calls, 2);
  });

  test('candidate instructions are not presented as observed UI evidence',
      () async {
    var calls = 0;
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((r) async {
          calls++;
          final body = jsonDecode(r.body);
          final screen = body['state']['screen'];
          expect(screen['widgets'].single, {
            'widget': 'ListTile',
            'text': ['Buy milk']
          });
          if (calls == 2) {
            expect(body['questions']['next_action']['criteria']['add'],
                'Long press to reveal delete');
          }
          return http.Response(jsonEncode(response()), 200);
        }));
    await client.evaluate(JevisRequest(
        goal: 'Reveal delete',
        actionInstruction: 'Action-only instruction',
        initialState: {},
        observation: JevisObservation(state: {
          'controls': [
            {
              'id': 'add',
              'widgetType': 'ListTile',
              'labels': ['Buy milk'],
              'description': 'Long press to reveal delete',
              'kind': 'longPress'
            },
            {'id': 'offscreen', 'description': 'Hidden target'}
          ]
        }, actions: [
          const JevisCandidate('add', 'Long press to reveal delete')
        ]),
        history: [],
        remainingAttempts: 2));
    expect(calls, 2);
  });

  test('screen projection preserves evidence and drops internal metadata',
      () async {
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((r) async {
          final screen = jsonDecode(r.body)['state']['screen'];
          expect(screen, {
            'visibleText': ['Drop status: Delivered'],
            'widgets': [
              {
                'target': 'w1',
                'widget': 'TextField',
                'text': ['Name'],
                'state': {'focused': true, 'empty': false, 'value': 'Alex'}
              },
              {
                'target': 'w2',
                'widget': 'Checkbox',
                'state': {'checked': false}
              },
              {
                'target': 'w3',
                'widget': 'Checkbox',
                'state': {'checked': false}
              },
              {
                'widget': 'TextField',
                'state': {'obscured': true, 'empty': false}
              },
            ],
          });
          expect(r.body, isNot(contains('internal/path')));
          return http.Response(jsonEncode(response(goal: .99)), 200);
        }));
    await client.evaluate(JevisRequest(
        goal: 'Deliver parcel',
        actionInstruction: 'Action-only instruction',
        initialState: {},
        observation: JevisObservation(state: {
          'visibleText': ['Drop status: Delivered'],
          'elements': [
            {
              'id': 'internal/path',
              'identity': 'stableKey',
              'target': 'w1',
              'widgetType': 'TextField',
              'labels': ['Name'],
              'label': 'Name',
              'focused': true,
              'empty': false,
              'value': 'Alex',
              'role': 'input'
            },
            {'target': 'w2', 'widgetType': 'Checkbox', 'checked': false},
            {'target': 'w3', 'widgetType': 'Checkbox', 'checked': false},
            {
              'widgetType': 'TextField',
              'obscured': true,
              'empty': false,
              'value': 'secret'
            },
          ],
          'controls': [
            {
              'target': 'w1',
              'widgetType': 'TextField',
              'labels': ['Name'],
              'focused': true,
              'empty': false,
              'value': 'Alex',
              'description': 'unproven effect'
            }
          ],
          'memory': {'hidden': true},
        }, actions: []),
        history: [],
        remainingAttempts: 0));
  });

  test('onResponse receives status and body before HTTP error validation',
      () async {
    final responses = <(int, String)>[];
    final client = JevisClient(
        apiKey: 'key',
        onResponse: (status, body) => responses.add((status, body)),
        client:
            MockClient((_) async => http.Response('service unavailable', 503)));
    await expectLater(client.evaluate(request()), throwsStateError);
    expect(responses, [(503, 'service unavailable')]);
  });
  test('onResponse receives the full UTF-8 JSON before parsing', () async {
    final payload = jsonEncode({...response(), 'message': '응답 확인'});
    final responses = <(int, String)>[];
    final client = JevisClient(
        apiKey: 'key',
        onResponse: (status, body) => responses.add((status, body)),
        client: MockClient(
            (_) async => http.Response.bytes(utf8.encode(payload), 200)));
    await client.evaluate(request());
    expect(responses, [(200, payload), (200, payload)]);
  });

  test('onRequest receives the exact posted body before HTTP dispatch',
      () async {
    final bodies = <String>[];
    final client = JevisClient(
        apiKey: 'secret-key',
        onRequest: bodies.add,
        client: MockClient((r) async {
          expect(bodies.last, r.body);
          expect(bodies.last, isNot(contains('secret-key')));
          expect((jsonDecode(bodies.last)['questions'] as Map).keys,
              bodies.length == 1 ? ['goal_reached'] : ['next_action']);
          return http.Response(jsonEncode(response()), 200);
        }));
    await client.evaluate(request());
  });

  test('Noul receives only goal and Choice receives only action instruction',
      () async {
    final sent = <Map>[];
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map;
          sent.add(body);
          expect(body['state'], {
            if (sent.length == 1)
              'goal': 'Create and complete a todo'
            else
              'actionInstruction': 'Action-only instruction',
            if (sent.length > 1) 'previousActions': <String>[],
            'screen': {
              'visibleText': ['Todos']
            }
          });
          expect(
              r.body,
              isNot(contains(sent.length == 1
                  ? 'Action-only instruction'
                  : 'Create and complete a todo')));
          expect((body['questions'] as Map).keys,
              sent.length == 1 ? ['goal_reached'] : ['next_action']);
          return http.Response(jsonEncode(response()), 200);
        }));
    final original = request();
    final evaluation = await client.evaluate(JevisRequest(
        goal: original.goal,
        actionInstruction: 'Action-only instruction',
        initialState: {'hidden': 'initial'},
        observation: JevisObservation(state: {
          ...original.observation.state,
          'memory': {'hidden': 'old'},
          'changes': {'hidden': 'delta'},
          'app': {'hidden': 'internal'}
        }, actions: original.observation.actions),
        history: [],
        remainingAttempts: 3));
    expect(sent, hasLength(2));
    expect(evaluation.actionId, 'add');
    expect(evaluation.goalProbability, .01);
  });
  test('configured completion threshold skips Choice', () async {
    var calls = 0;
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((r) async {
          calls++;
          expect(
              (jsonDecode(r.body)['questions'] as Map).keys, ['goal_reached']);
          return http.Response(jsonEncode(response(goal: .6)), 200);
        }));
    final original = request();
    final result = await client.evaluate(JevisRequest(
        goal: original.goal,
        actionInstruction: 'Action-only instruction',
        initialState: original.initialState,
        observation: original.observation,
        history: [],
        remainingAttempts: 3,
        goalThreshold: .6));
    expect(calls, 1);
    expect(result.goalProbability, .6);
    expect(result.actionId, isNull);
  });
  for (final noActions in [false, true]) {
    test(
        'goal-only assessment when ${noActions ? 'no actions' : 'budget exhausted'}',
        () async {
      final client = JevisClient(
          apiKey: 'key',
          client: MockClient((r) async {
            expect((jsonDecode(r.body)['questions'] as Map).keys,
                ['goal_reached']);
            return http.Response(
                '{"answers":{"goal_reached":{"type":"noul","noul":0.2}}}', 200);
          }));
      final evaluation = await client
          .evaluate(request(remaining: noActions ? 3 : 0, actions: !noActions));
      expect(evaluation.goalProbability, .2);
      expect(evaluation.actionId, isNull);
    });
  }
  test('failed Noul does not dispatch Choice', () async {
    var calls = 0;
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(response(goal: 2)), 200);
        }));
    await expectLater(client.evaluate(request()), throwsFormatException);
    expect(calls, 1);
  });
  test('Choice failure after valid unfinished Noul remains an error', () async {
    var calls = 0;
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response(jsonEncode(response()), 200)
              : http.Response('unavailable', 503);
        }));
    await expectLater(client.evaluate(request()), throwsStateError);
    expect(calls, 2);
  });
  test('rejects malformed goal probability', () async {
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient(
            (_) async => http.Response(jsonEncode(response(goal: 2)), 200)));
    await expectLater(client.evaluate(request()), throwsFormatException);
  });
  test('rejects unknown action probability entries', () async {
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((_) async => http.Response(
            jsonEncode(response(probabilities: {'add': .9, 'unknown': .1})),
            200)));
    await expectLater(client.evaluate(request()), throwsFormatException);
  });
  test('reports contradictory Choice without executing a lower ranked option',
      () async {
    final client = JevisClient(
        apiKey: 'key',
        client: MockClient((_) async => http.Response(
            jsonEncode(response(
                probabilities: {'add': .49, 'other': .51, '__stop__': 0})),
            200)));
    await expectLater(
        client.evaluate(request(candidates: const [
          JevisCandidate('add', 'Add todo'),
          JevisCandidate('other', 'Other action')
        ])),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            contains('Choice is not a highest-probability option'))));
  });
  test('HTTP errors do not expose response bodies or keys', () async {
    final client = JevisClient(
        apiKey: 'secret',
        client: MockClient((_) async => http.Response('secret', 401)));
    await expectLater(
        client.evaluate(request()),
        throwsA(predicate((e) =>
            e.toString().contains('401') && !e.toString().contains('secret'))));
  });
  test('missing key fails clearly and never falls back to fake decisions', () {
    expect(() => JevisClient(apiKey: ''), throwsArgumentError);
  });
}
