import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis_flutter/jevis_flutter.dart';

void main() {
  testWidgets('focus discovers fields without a key and excludes disabled ones',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      TextField(decoration: InputDecoration(labelText: 'Name')),
      TextField(enabled: false),
    ]))));
    final driver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.focus()]);
    final before = await driver.observe();
    expect(before.actions, hasLength(1));
    await driver.execute(before.actions.single.id);
    expect((await driver.observe()).actions, isEmpty);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('clear and keyboard abilities execute discovered inputs',
      (tester) async {
    final controller = TextEditingController(text: 'Old');
    addTearDown(controller.dispose);
    String? submitted;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) => submitted = value,
    ))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.clearText(),
      JevisActions.keyboardAction(action: TextInputAction.search),
    ]);
    var observation = await driver.observe();
    await driver.execute(observation.actions
        .singleWhere((a) => a.description.startsWith('Clear'))
        .id);
    expect(controller.text, isEmpty);
    observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    await driver.execute(observation.actions.single.id);
    expect(submitted, '');
  });

  testWidgets('long press and double tap discover callbacks without duplicates',
      (tester) async {
    var held = false;
    var doubled = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      ListTile(title: const Text('Hold'), onLongPress: () => held = true),
      GestureDetector(
          onDoubleTap: () => doubled = true,
          child: const SizedBox(width: 100, height: 100, child: Text('Twice'))),
    ]))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.longPress(),
      JevisActions.doubleTap(),
    ]);
    var observation = await driver.observe();
    expect(observation.actions, hasLength(2));
    await driver.execute(observation.actions
        .singleWhere((a) => a.description.startsWith('Long press'))
        .id);
    expect(held, isTrue);
    observation = await driver.observe();
    await driver.execute(observation.actions
        .singleWhere((a) => a.description.startsWith('Double tap'))
        .id);
    expect(doubled, isTrue);
  });

  testWidgets('slider offers only valid directions at boundaries',
      (tester) async {
    var value = 0.0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (_, setState) => Slider(
          value: value,
          divisions: 2,
          onChanged: (v) => setState(() => value = v)),
    ))));
    final driver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.adjustSlider()]);
    final observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    await driver.execute(observation.actions.single.id);
    expect(value, .5);
    expect((await driver.observe()).actions, hasLength(2));
  });

  testWidgets('dropdown opens then offers enabled visible options',
      (tester) async {
    var value = 'Low';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (_, setState) => DropdownButton<String>(
        value: value,
        items: const [
          DropdownMenuItem(value: 'Low', child: Text('Low')),
          DropdownMenuItem(value: 'High', child: Text('High')),
          DropdownMenuItem(
              value: 'Disabled', enabled: false, child: Text('Disabled')),
        ],
        onChanged: (next) => setState(() => value = next!),
      ),
    ))));
    final driver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.selectOption()]);
    var observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    await driver.execute(observation.actions.single.id);
    observation = await driver.observe();
    expect(observation.actions, hasLength(2));
    await driver.execute(observation.actions
        .singleWhere((a) => a.description.contains('High'))
        .id);
    expect(value, 'High');
  });

  testWidgets('drag discovers swipe targets with configured offset',
      (tester) async {
    var archived = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (_, setState) => archived
          ? const Text('Archived')
          : Dismissible(
              key: const ValueKey('message'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => setState(() => archived = true),
              child: const SizedBox(
                  width: 200, height: 80, child: Text('Message')),
            ),
    ))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.drag(offset: const Offset(-300, 0)),
    ]);
    final observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    await driver.execute(observation.actions.single.id);
    expect(archived, isTrue);
  });

  testWidgets('dragTo discovers a source and requires a visible destination',
      (tester) async {
    var delivered = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Row(children: [
      const LongPressDraggable<String>(
          data: 'parcel',
          feedback: Text('Parcel'),
          child: SizedBox(width: 100, height: 100, child: Text('Parcel'))),
      DragTarget<String>(
          key: const ValueKey('drop'),
          onAcceptWithDetails: (_) => delivered = true,
          builder: (_, candidates, rejected) =>
              const SizedBox(width: 100, height: 100, child: Text('Drop'))),
    ]))));
    final driver = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.dragTo(
          destination: find.byKey(const ValueKey('drop')),
          holdDuration: const Duration(milliseconds: 650)),
    ]);
    final observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    await driver.execute(observation.actions.single.id);
    expect(delivered, isTrue);
    final missing = JevisFlutterDriver(tester: tester, actions: [
      JevisActions.dragTo(destination: find.text('Missing')),
    ]);
    expect((await missing.observe()).actions, isEmpty);
  });

  testWidgets('discovered gesture execution rejects removed callbacks',
      (tester) async {
    Widget screen(VoidCallback? callback) => MaterialApp(
        home: Scaffold(
            body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: callback,
                child: const SizedBox(width: 100, height: 100))));
    var presses = 0;
    await tester.pumpWidget(screen(() => presses++));
    final driver =
        JevisFlutterDriver(tester: tester, actions: [JevisActions.longPress()]);
    final observation = await driver.observe();
    expect(observation.actions, hasLength(1));
    final actionId = observation.actions.single.id;
    await driver.execute(actionId);
    expect(presses, 1);
    await tester.pumpWidget(screen(null));
    await expectLater(
        () => driver.execute(actionId),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('UI target changed after observation'))));
    expect(presses, 1);
  });

  test('drag parameters are validated when registering abilities', () {
    expect(() => JevisActions.drag(offset: Offset.zero), throwsArgumentError);
    expect(() => JevisActions.longPress(duration: Duration.zero),
        throwsArgumentError);
    expect(() => JevisActions.adjustSlider(steps: 0), throwsArgumentError);
  });
}
