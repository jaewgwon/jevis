import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis/jevis.dart';

void main() {
  testWidgets('discovered choices use compact targets and remain executable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: TextField(
        key: ValueKey('internal_field_key'),
        decoration: InputDecoration(labelText: 'Name'),
      )),
    ));
    final driver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.focus()]);
    final observation = await driver.observe();
    final candidate = observation.actions.single;
    final payload =
        jsonDecode(candidate.description.substring('Focus '.length));
    expect(payload['widget'], 'TextField');
    expect(payload['text'], ['Name']);
    expect(payload['target'], startsWith('w'));
    expect(payload['state']['focused'], isFalse);
    expect(candidate.description, isNot(contains('internal_field_key')));
    expect(candidate.description, isNot(contains('identity')));
    final history = candidate.historyDescription!;
    expect(history, startsWith('focus('));
    expect(history, contains('Name'));
    expect(history, isNot(contains('focused')));
    expect(history, isNot(contains('internal_field_key')));
    await driver.execute(candidate.id);
    expect((await driver.observe()).actions, isEmpty);
  });
}
