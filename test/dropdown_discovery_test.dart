import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis/jevis.dart';

void main() {
  for (final filtered in [false, true]) {
    testWidgets('dropdown discovers unique enabled options, filtered=$filtered',
        (tester) async {
      var selected = 'Low';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (_, setState) {
          return DropdownButton<String>(
            value: selected,
            items: [
              for (final label in ['Low', 'High', 'Disabled'])
                DropdownMenuItem(
                  value: label,
                  enabled: label != 'Disabled',
                  child: ColoredBox(
                    color: Colors.blue,
                    child: SizedBox(
                        width: 160, height: 48, child: Text(label)),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => selected = value!),
          );
        })),
      ));
      final driver = JevisFlutterDriver(tester: tester, actions: [
        JevisActions.tap(),
        JevisActions.selectOption(values: filtered ? ['High', 'Disabled'] : null),
      ]);
      await driver.execute((await driver.observe()).actions.single.id);
      final options = (await driver.observe()).actions;
      expect(options, hasLength(filtered ? 1 : 2));
      expect(options.where((a) => a.description.contains('Disabled')), isEmpty);
      final high = options.singleWhere((a) => a.description.contains('High'));
      await driver.execute(high.id);
      expect(selected, 'High');
    });
  }
}
