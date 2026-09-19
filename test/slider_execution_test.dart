import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis_flutter/jevis_flutter.dart';

void main() {
  for (final direction in JevisSliderDirection.values) {
    testWidgets('slider ${direction.name} adjusts only the selected slider',
        (tester) async {
      var value = 50.0;
      var neighbor = 50.0;
      final started = <double>[];
      final ended = <double>[];
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(builder: (_, setState) {
          return Scaffold(
            body: Column(children: [
              Slider(
                value: neighbor,
                min: 10,
                max: 90,
                divisions: 4,
                onChanged: (next) => setState(() => neighbor = next),
              ),
              Slider(
                key: const ValueKey('target'),
                value: value,
                min: 10,
                max: 90,
                divisions: 4,
                onChangeStart: started.add,
                onChangeEnd: ended.add,
                onChanged: (next) => setState(() => value = next),
              ),
            ]),
          );
        }),
      ));
      final driver = JevisFlutterDriver(tester: tester, actions: [
        JevisAction.adjustSlider('Adjust the target slider.',
            key: 'target', direction: direction, steps: 3),
      ]);
      await driver.execute((await driver.observe()).actions.single.id);
      final increasing = direction == JevisSliderDirection.increase;
      expect(value, increasing ? 90 : 10);
      expect(neighbor, 50);
      expect(started, increasing ? [50, 70] : [50, 30]);
      expect(ended, increasing ? [70, 90] : [30, 10]);
      expect((await driver.observe()).actions, isEmpty);
    });
  }

  testWidgets('continuous slider uses Flutter accessibility increments',
      (tester) async {
    var value = .5;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: StatefulBuilder(builder: (_, setState) {
        return Scaffold(
          body: Slider(
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        );
      }),
    ));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.adjustSlider(direction: JevisSliderDirection.decrease, steps: 2),
    ]);
    await driver.execute((await driver.observe()).actions.single.id);
    expect(value, closeTo(.4, .000001));
  });

  testWidgets('slider that ignores changes reports a failed adjustment',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Slider(value: .5, onChanged: (_) {})),
    ));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.adjustSlider(direction: JevisSliderDirection.increase),
    ]);
    final actionId = (await driver.observe()).actions.single.id;
    await expectLater(
      () => driver.execute(actionId),
      throwsA(isA<StateError>().having((e) => e.message, 'message',
          'Slider did not move in the requested direction')),
    );
  });
}
