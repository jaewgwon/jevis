import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis/jevis.dart';

void main() {
  testWidgets(
      'scroll discovers keyed rows and revisits do not duplicate memory',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 180,
                child: ListView.builder(
                    key: const ValueKey('products'),
                    itemExtent: 60,
                    itemCount: 10,
                    itemBuilder: (_, i) => CheckboxListTile(
                        key: ValueKey('product_$i'),
                        title: const Text('Same label'),
                        value: false,
                        onChanged: (_) {}))))));
    final driver = JevisFlutterDriver(
        tester: tester, actions: [JevisActions.tap(), JevisActions.scroll()]);
    var observation = await driver.observe();
    expect(observation.actions.every((a) => a.id.length < 50), isTrue);
    final first = (observation.state['memory'] as Map)['elements'] as List;
    expect(first.where((e) => e['role'] == 'toggle').length, lessThan(10));
    for (var i = 0; i < 12; i++) {
      final next = observation.actions
          .where((a) => a.description.startsWith('Scroll forward'));
      if (next.isEmpty) break;
      await driver.execute(next.first.id);
      observation = await driver.observe();
    }
    final discovered = (observation.state['memory'] as Map)['elements'] as List;
    expect(discovered.where((e) => e['role'] == 'toggle').length, 10);
    for (var i = 0; i < 12; i++) {
      final previous = observation.actions
          .where((a) => a.description.startsWith('Scroll backward'));
      if (previous.isEmpty) break;
      await driver.execute(previous.first.id);
      observation = await driver.observe();
    }
    expect(
        ((observation.state['memory'] as Map)['elements'] as List)
            .where((e) => e['role'] == 'toggle')
            .length,
        10);
    expect(
        observation.actions
            .any((a) => a.description.startsWith('Scroll backward')),
        isFalse);
  });

  testWidgets(
      'capabilities restrict candidates and disabled controls are excluded',
      (tester) async {
    var searches = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      const TextField(key: ValueKey('query')),
      const FilledButton(onPressed: null, child: Text('Disabled')),
      FilledButton(onPressed: () => searches++, child: const Text('Search')),
    ]))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.enterText(values: ['coffee'])
    ]);
    final observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    await driver.execute(observation.actions.single.id);
    expect(find.text('coffee'), findsOneWidget);
    final tapDriver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.tap()]);
    final tapActions = (await tapDriver.observe()).actions;
    // Text selection overlays can expose additional valid tap targets.
    expect(tapActions.every((a) => a.description.startsWith('Tap ')), isTrue);
    expect(tapActions.where((a) => a.description.contains('Disabled')), isEmpty);
    final searchActions =
        tapActions.where((a) => a.description.contains('Search'));
    expect(searchActions, hasLength(1));
    await tapDriver.execute(searchActions.single.id);
    expect(searches, 1);
  });

  testWidgets('execution rejects a stale target and reset forgets exploration',
      (tester) async {
    Widget screen(String label, {String key = 'button'}) => MaterialApp(
        home: Scaffold(
            body: FilledButton(
                key: ValueKey(key), onPressed: () {}, child: Text(label))));
    await tester.pumpWidget(screen('Before'));
    final driver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.tap()]);
    final observation = await driver.observe();
    await tester.pumpWidget(screen('After'));
    await expectLater(
        driver.execute(observation.actions.single.id), throwsStateError);
    await tester.pumpWidget(screen('Another', key: 'another'));
    final beforeReset = await driver.observe();
    expect(((beforeReset.state['memory'] as Map)['elements'] as List),
        hasLength(2));
    driver.reset();
    final next = await driver.observe();
    expect(((next.state['memory'] as Map)['elements'] as List), hasLength(1));
  });
  testWidgets('unkeyed lazy rows are not treated as persistent identities',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 180,
                child: ListView.builder(
                    key: const ValueKey('list'),
                    itemExtent: 60,
                    itemCount: 20,
                    itemBuilder: (_, i) => CheckboxListTile(
                        title: Text('Row $i'),
                        value: false,
                        onChanged: (_) {}))))));
    final driver = JevisFlutterDriver(
        tester: tester, actions: [JevisActions.tap(), JevisActions.scroll()]);
    final observation = await driver.observe();
    final memory = (observation.state['memory'] as Map)['elements'] as List;
    expect(memory.where((e) => e['role'] == 'toggle'), isEmpty);
    expect(
        (observation.state['elements'] as List)
            .where((e) => e['role'] == 'toggle')
            .every((e) => e['identity'] == 'ephemeral'),
        isTrue);
  });
  testWidgets('disabled ListTile is not a candidate', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListTile(
                enabled: false, onTap: () {}, title: const Text('Disabled')))));
    final driver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.tap()]);
    expect((await driver.observe()).actions, isEmpty);
  });

  testWidgets('reverse horizontal scrolling advances and back pops a route',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                                body: SizedBox(
                                    width: 180,
                                    child: ListView.builder(
                                        key: const ValueKey('gallery'),
                                        reverse: true,
                                        scrollDirection: Axis.horizontal,
                                        itemExtent: 60,
                                        itemCount: 10,
                                        itemBuilder: (_, i) =>
                                            Text('Photo $i')))))),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final driver = JevisFlutterDriver(
        tester: tester, actions: [JevisActions.scroll(), JevisActions.back()]);
    var observation = await driver.observe();
    await driver.execute(observation.actions
        .firstWhere((a) => a.description.startsWith('Scroll forward'))
        .id);
    observation = await driver.observe();
    final scroll = (observation.state['elements'] as List)
        .firstWhere((e) => e['role'] == 'scrollable');
    expect(scroll['pixels'], greaterThan(0));
    await driver.execute('ui_back');
    expect(find.text('Open'), findsOneWidget);
  });
}
