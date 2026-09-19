part of 'flutter_agent.dart';

extension _ActionExecutor on JevisFlutterDriver {
  Future<void> _executeAction(JevisAction action) async {
    switch (action._kind) {
      case _Kind.tap:
        await tester.tap(action.finder!);
      case _Kind.longPress:
        final gesture =
            await tester.startGesture(tester.getCenter(action.finder!));
        try {
          await tester.pump(action.duration);
        } finally {
          await gesture.up();
        }
      case _Kind.doubleTap:
        await tester.tap(action.finder!);
        await tester.pump(const Duration(milliseconds: 100));
        if (!_uniqueVisible(action.finder!)) {
          throw StateError('Double-tap target disappeared after the first tap');
        }
        await tester.tap(action.finder!);
      case _Kind.enterText:
        await tester.enterText(action.finder!, action.value!);
      case _Kind.clearText:
        await tester.enterText(action.finder!, '');
      case _Kind.focus:
        await tester.showKeyboard(action.finder!);
      case _Kind.keyboardAction:
        await tester.showKeyboard(action.finder!);
        await tester.testTextInput.receiveAction(action.keyboard!);
      case _Kind.scroll:
        await tester.drag(action.finder!, action.offset!);
      case _Kind.drag:
        await tester.timedDrag(action.finder!, action.offset!, action.duration);
      case _Kind.dragTo:
        await _dragTo(action);
      case _Kind.selectOption:
        await _selectOption(action);
      case _Kind.adjustSlider:
        await _adjustSlider(action);
      case _Kind.wait:
        await tester.pump(action.duration);
      case _Kind.waitUntil:
        // The common completion path below executes the declared condition.
        break;
      case _Kind.custom:
        await action.callback!(tester);
    }
  }

  Future<void> _settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      options.settleTimeout);

  Future<void> _waitFor(JevisWait condition) async {
    var elapsed = Duration.zero;
    await tester.pump();
    while (true) {
      _checkException();
      final satisfied = condition.visible
          ? condition.finder.hitTestable().evaluate().isNotEmpty
          : condition.finder.evaluate().isEmpty;
      if (satisfied) return;
      if (elapsed >= condition.timeout) {
        throw TimeoutException(
            'UI condition not reached: ${condition.visible ? "visible" : "absent"} ${condition.finder}',
            condition.timeout);
      }
      final remaining = condition.timeout - elapsed;
      final interval = remaining < condition.pollInterval
          ? remaining
          : condition.pollInterval;
      await tester.pump(interval);
      elapsed += interval;
    }
  }

  Future<void> _dragTo(JevisAction action) async {
    final start = tester.getCenter(action.finder!);
    final end = tester.getCenter(action.destination!);
    if (start == end) {
      throw StateError('Drag source and destination have the same center');
    }
    final gesture = await tester.startGesture(start);
    try {
      if (action.holdDuration > Duration.zero) {
        await tester.pump(action.holdDuration);
      }
      final frames =
          (action.duration.inMicroseconds / 16000).ceil().clamp(1, 120);
      var elapsedMicros = 0;
      for (var frame = 1; frame <= frames; frame++) {
        final nextMicros =
            (action.duration.inMicroseconds * frame / frames).round();
        await gesture.moveTo(Offset.lerp(start, end, frame / frames)!);
        await tester.pump(Duration(microseconds: nextMicros - elapsedMicros));
        elapsedMicros = nextMicros;
      }
    } finally {
      await gesture.up();
    }
  }

  Future<void> _selectOption(JevisAction action) async {
    await tester.tap(action.finder!);
    await _settle();
    var option = action.option!.hitTestable();
    if (option.evaluate().isEmpty && action.option!.evaluate().length == 1) {
      await tester.ensureVisible(action.option!);
      await _settle();
      option = action.option!.hitTestable();
    }
    if (option.evaluate().length != 1) {
      throw StateError(
          'Expected one visible menu option after opening the menu: ${action.option}');
    }
    final widget = option.evaluate().single.widget;
    if (widget is DropdownMenuItem && !widget.enabled) {
      throw StateError('The selected menu option is disabled');
    }
    // A text finder can match inside a disabled DropdownMenuItem.
    var disabled = false;
    option.evaluate().single.visitAncestorElements((element) {
      if (element.widget is DropdownMenuItem &&
          !(element.widget as DropdownMenuItem).enabled) {
        disabled = true;
      }
      return !disabled;
    });
    if (disabled) throw StateError('The selected menu option is disabled');
    await tester.tap(option);
  }

  Future<void> _adjustSlider(JevisAction action) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      for (var step = 0; step < action.steps; step++) {
        if (!_uniqueVisible(action.finder!)) {
          throw StateError('Slider is no longer visible');
        }
        final widget = action.finder!.evaluate().single.widget;
        if (widget is! Slider || widget.onChanged == null) {
          throw StateError('Expected an enabled Slider');
        }
        final increasing =
            action.sliderDirection == JevisSliderDirection.increase;
        if ((increasing && widget.value >= widget.max) ||
            (!increasing && widget.value <= widget.min)) {
          return;
        }
        final operation =
            increasing ? SemanticsAction.increase : SemanticsAction.decrease;
        final nodes = <SemanticsNode>{};
        void collect(Element element) {
          if (element is RenderObjectElement) {
            final node = element.renderObject.debugSemantics;
            if (node != null &&
                node.getSemanticsData().hasAction(operation)) {
              nodes.add(node);
            }
          }
          element.visitChildElements(collect);
        }

        // Slider's outer render object may resolve to an ancestor's semantics.
        // Only inspect descendants of this slider to avoid adjusting a sibling.
        collect(action.finder!.evaluate().single);
        if (nodes.length != 1) {
          throw StateError(
              'Slider must expose exactly one requested semantics action');
        }
        final node = nodes.single;
        node.owner!.performAction(node.id, operation);
        await tester.pump();
        _checkException();
        if (!_uniqueVisible(action.finder!)) {
          throw StateError('Slider disappeared during adjustment');
        }
        final updated = action.finder!.evaluate().single.widget;
        if (updated is! Slider ||
            (increasing
                ? updated.value <= widget.value
                : updated.value >= widget.value)) {
          throw StateError('Slider did not move in the requested direction');
        }
      }
    } finally {
      semantics.dispose();
    }
  }
}
