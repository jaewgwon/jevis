import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis/jevis.dart';

void main() {
  testWidgets('registered icon controls expose their actual UI label',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: IconButton(
                key: const ValueKey('delete'),
                tooltip: 'Delete todo',
                onPressed: () {},
                icon: const Icon(Icons.delete)))));
    final driver = JevisFlutterDriver(
        tester: tester,
        actions: [JevisAction.tap('Delete the selected item.', key: 'delete')]);
    expect(
        ((await driver.observe()).state['controls'] as List).single['tooltip'],
        'Delete todo');
  });

  testWidgets('read-only editing and disabled slider are not offered',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      TextField(key: ValueKey('read_only'), readOnly: true),
      Slider(key: ValueKey('disabled_slider'), value: .5, onChanged: null),
    ]))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.clearText('Clear.', key: 'read_only'),
      JevisAction.keyboardAction('Submit.',
          key: 'read_only', action: TextInputAction.done),
      JevisAction.adjustSlider('Increase.',
          key: 'disabled_slider', direction: JevisSliderDirection.increase),
    ]);
    expect((await driver.observe()).actions, isEmpty);
  });

  testWidgets('waitUntil absent observes a widget removal', (tester) async {
    var shown = true;
    late StateSetter update;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      update = setState;
      return Scaffold(
          body: shown
              ? const Text('Loading', key: ValueKey('loading'))
              : const Text('Ready'));
    })));
    final timer = Timer(
        const Duration(milliseconds: 100), () => update(() => shown = false));
    addTearDown(timer.cancel);
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.waitUntil('Wait for loading to disappear.',
          condition: JevisWait.absent(key: 'loading'))
    ]);
    await driver.execute((await driver.observe()).actions.single.id);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets(
      'long press on a long-press-only ListTile reveals a delete action',
      (tester) async {
    var revealed = false;
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
            builder: (_, setState) => Scaffold(
                    body: Column(children: [
                  ListTile(
                      key: const ValueKey('todo'),
                      title: const Text('Buy milk'),
                      onLongPress: () => setState(() => revealed = true)),
                  if (revealed)
                    const Icon(Icons.delete, key: ValueKey('delete'))
                ])))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.longPress('Long-press Buy milk to reveal its delete icon.',
          key: 'todo')
    ]);
    final before = await driver.observe();
    expect(before.actions.single.description,
        'Long-press Buy milk to reveal its delete icon.');
    expect(find.byKey(const ValueKey('delete')), findsNothing);
    await driver.execute(before.actions.single.id);
    expect(find.byKey(const ValueKey('delete')), findsOneWidget);
  });

  testWidgets('double tap invokes the double-tap gesture', (tester) async {
    var count = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GestureDetector(
                key: const ValueKey('target'),
                onDoubleTap: () => count++,
                child: const SizedBox(
                    width: 100, height: 100, child: Text('Target'))))));
    final driver = JevisFlutterDriver(
        tester: tester,
        actions: [JevisAction.doubleTap('Double-tap target.', key: 'target')]);
    await driver.execute((await driver.observe()).actions.single.id);
    expect(count, 1);
  });

  testWidgets('timed drag uses the supplied displacement', (tester) async {
    var moved = 0.0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GestureDetector(
                key: const ValueKey('surface'),
                onPanUpdate: (event) => moved += event.delta.dx,
                child: const SizedBox(
                    width: 400, height: 300, child: Text('Drag'))))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.drag('Drag right.',
          key: 'surface',
          offset: const Offset(150, 0),
          duration: const Duration(milliseconds: 400))
    ]);
    await driver.execute((await driver.observe()).actions.single.id);
    expect(moved, greaterThan(100));
  });

  testWidgets('dragTo supports a held drag and rejects a missing destination',
      (tester) async {
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Row(children: [
      LongPressDraggable<String>(
          key: const ValueKey('source'),
          data: 'item',
          feedback: const Text('Moving'),
          child:
              const SizedBox(width: 100, height: 100, child: Text('Source'))),
      const SizedBox(width: 150),
      DragTarget<String>(
          key: const ValueKey('destination'),
          onAcceptWithDetails: (_) => accepted = true,
          builder: (_, __, ___) => const SizedBox(
              width: 100, height: 100, child: Text('Destination'))),
    ]))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.dragTo('Move the item to destination.',
          key: 'source',
          destinationKey: 'destination',
          holdDuration: const Duration(milliseconds: 650)),
      JevisAction.dragTo('Missing destination.',
          key: 'source', destinationKey: 'missing'),
    ]);
    final observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    await driver.execute(observation.actions.single.id);
    expect(accepted, true);
  });

  testWidgets('clear, replace, focus and keyboard action operate on an input',
      (tester) async {
    final controller = TextEditingController(text: 'Old');
    addTearDown(controller.dispose);
    String? submitted;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TextField(
                key: const ValueKey('input'),
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => submitted = value))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.clearText('Clear input.', key: 'input'),
      JevisAction.enterText('Enter query.', key: 'input', value: 'Milk'),
      JevisAction.focus('Focus input.', key: 'input'),
      JevisAction.keyboardAction('Search.',
          key: 'input', action: TextInputAction.search),
    ]);
    await driver.execute('action_0');
    expect(controller.text, '');
    await driver.execute('action_1');
    await driver.execute('action_2');
    final controls = (await driver.observe()).state['controls'] as List;
    expect(controls[2]['focused'], true);
    expect(controls[2]['value'], 'Milk');
    await driver.execute('action_3');
    expect(submitted, 'Milk');
  });

  testWidgets('selectOption opens a dropdown then chooses a concrete option',
      (tester) async {
    var selected = 'Low';
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
            builder: (_, setState) => Scaffold(
                body: DropdownButton<String>(
                    key: const ValueKey('priority'),
                    value: selected,
                    items: ['Low', 'High']
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selected = value!))))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.selectOption('Choose High priority.',
          key: 'priority', option: find.text('High'))
    ]);
    await driver.execute((await driver.observe()).actions.single.id);
    expect(selected, 'High');
  });

  testWidgets('slider adjustment changes the actual widget through semantics',
      (tester) async {
    var value = 0.0;
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
            builder: (_, setState) => Scaffold(
                body: Slider(
                    key: const ValueKey('volume'),
                    value: value,
                    divisions: 4,
                    onChanged: (next) => setState(() => value = next))))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.adjustSlider('Increase volume two steps.',
          key: 'volume', direction: JevisSliderDirection.increase, steps: 2)
    ]);
    await driver.execute((await driver.observe()).actions.single.id);
    expect(value, .5);
    expect(((await driver.observe()).state['controls'] as List).single['value'],
        .5);
  });

  testWidgets(
      'explicit wait condition works while an unrelated spinner animates',
      (tester) async {
    var ready = false;
    late StateSetter update;
    await tester
        .pumpWidget(MaterialApp(home: StatefulBuilder(builder: (_, setState) {
      update = setState;
      return Scaffold(
          body: Column(children: [
        const CircularProgressIndicator(),
        FilledButton(
            key: const ValueKey('load'),
            onPressed: () {
              Timer(const Duration(milliseconds: 100),
                  () => update(() => ready = true));
            },
            child: const Text('Load')),
        if (ready) const Text('Ready', key: ValueKey('ready')),
      ]));
    })));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.tap('Load results.',
          key: 'load', waitFor: JevisWait.visible(key: 'ready'))
    ]);
    await driver.execute((await driver.observe()).actions.single.id);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('waitUntil times out rather than silently claiming success',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisAction.waitUntil('Wait for result.',
          condition: JevisWait.visible(
              key: 'missing',
              timeout: const Duration(milliseconds: 50),
              pollInterval: const Duration(milliseconds: 10)))
    ]);
    await expectLater(
        driver.execute((await driver.observe()).actions.single.id),
        throwsA(isA<TimeoutException>()));
  });

  test('invalid gesture and wait parameters are rejected', () {
    expect(() => JevisAction.drag('Move.', key: 'a', offset: Offset.zero),
        throwsArgumentError);
    expect(() => JevisAction.dragTo('Move.', key: 'a'), throwsArgumentError);
    expect(
        () => JevisAction.adjustSlider('Adjust.',
            key: 'a', direction: JevisSliderDirection.increase, steps: 0),
        throwsArgumentError);
    expect(() => JevisWait.visible(key: 'a', timeout: Duration.zero),
        throwsArgumentError);
  });
}
