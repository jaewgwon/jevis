import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis/jevis.dart';

void main() {
  checkDropdown<String>('String', 'low', 'high');
  checkDropdown<int>('int', 1, 2);
}

void checkDropdown<T>(String type, T low, T high) {
  for (final formField in [false, true]) {
    for (final enabled in [false, true]) {
      testWidgets(
          '${formField ? 'DropdownButtonFormField' : 'DropdownButton'}<$type> '
          'safely observes ${enabled ? 'enabled' : 'disabled'} callbacks',
          (tester) async {
        T? selected;
        var changes = 0;
        await tester.pumpWidget(MaterialApp(
          home: StatefulBuilder(builder: (_, setState) {
            final items = [
              DropdownMenuItem<T>(value: low, child: const Text('Low')),
              DropdownMenuItem<T>(value: high, child: const Text('High')),
            ];
            final ValueChanged<T?>? onChanged = enabled
                ? (next) => setState(() {
                      changes++;
                      selected = next;
                    })
                : null;
            return Scaffold(
              body: formField
                  ? DropdownButtonFormField<T>(
                      key: const ValueKey('dropdown'),
                      items: items,
                      onChanged: onChanged,
                    )
                  : DropdownButton<T>(
                      key: const ValueKey('dropdown'),
                      value: selected,
                      items: items,
                      onChanged: onChanged,
                    ),
            );
          }),
        ));
        final driver = JevisFlutterDriver(tester: tester, actions: [
          JevisAction.selectOption('Choose High.',
              key: 'dropdown', option: find.text('High')),
        ]);
        final observation = await driver.observe();
        expect(changes, 0);
        expect(observation.actions, hasLength(enabled ? 1 : 0));
        if (enabled) {
          await driver.execute(observation.actions.single.id);
          expect(selected, high);
          expect(changes, 1);
        }
      });
    }
  }
}
