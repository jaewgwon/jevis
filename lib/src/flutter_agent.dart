import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'core.dart';
import 'failure_diagnostics.dart';
import 'ui_context.dart';
import 'jevis_policy.dart';

part 'ui_observer.dart';
part 'actions.dart';
part 'action_executor.dart';

/// Registered controls are observed automatically, including checked/input state.
class JevisFlutterDriver implements JevisDriver, JevisRunLifecycle {
  JevisFlutterDriver(
      {required this.tester,
      required List<JevisAction> actions,
      this.observeState,
      this.options = const JevisOptions()})
      : actions = List.unmodifiable(actions) {
    options.validate();
    if (actions.length > 254 ||
        actions.any((a) => a.description.trim().isEmpty)) {
      throw ArgumentError(
          'Provide at most 254 actions with non-empty descriptions');
    }
  }
  final WidgetTester tester;
  final List<JevisAction> actions;
  final Map<String, Object?> Function()? observeState;
  final JevisOptions options;
  String _id(int index) => 'action_$index';
  late final _UiExplorer _explorer = _UiExplorer(this);
  final Map<String, JevisAction> _dynamicActions = {};
  @override
  void reset() {
    _dynamicActions.clear();
    _explorer.reset();
  }

  EditableText? _field(JevisAction action) {
    final fields = find
        .descendant(
            of: action.finder!,
            matching: find.byType(EditableText),
            matchRoot: true)
        .evaluate()
        .toList();
    return fields.length == 1 ? fields.single.widget as EditableText : null;
  }

  bool _available(JevisAction action) {
    if (!(action.availableWhen?.call() ?? true)) return false;
    final finder = action.finder;
    if (finder == null) return true;
    if (finder.evaluate().length != 1 ||
        finder.hitTestable().evaluate().length != 1) {
      return false;
    }
    final widget = finder.evaluate().single.widget;
    final isTap = action._kind == _Kind.tap ||
        action._kind == _Kind.doubleTap ||
        action._kind == _Kind.selectOption;
    final isLongPress = action._kind == _Kind.longPress;
    if (widget is ButtonStyleButton) {
      if (isTap && widget.onPressed == null) return false;
      if (isLongPress && widget.onLongPress == null) return false;
    }
    if (isTap && widget is IconButton && widget.onPressed == null) return false;
    if (isTap && widget is FloatingActionButton && widget.onPressed == null) {
      return false;
    }
    if (widget is ListTile &&
        (!widget.enabled ||
            (isTap && widget.onTap == null) ||
            (isLongPress && widget.onLongPress == null))) {
      return false;
    }
    if (widget is GestureDetector) {
      if (action._kind == _Kind.tap && widget.onTap == null) return false;
      if (action._kind == _Kind.doubleTap && widget.onDoubleTap == null) {
        return false;
      }
      if (isLongPress && widget.onLongPress == null) return false;
      if (action._kind == _Kind.drag && !JevisActions._supportsDrag(widget)) {
        return false;
      }
    }
    if (widget is InkWell) {
      if (action._kind == _Kind.tap && widget.onTap == null) return false;
      if (action._kind == _Kind.doubleTap && widget.onDoubleTap == null) {
        return false;
      }
      if (isLongPress && widget.onLongPress == null) return false;
    }
    if (widget is DropdownMenuItem && !widget.enabled) return false;
    if (widget is Slider && widget.onChanged == null) return false;
    if (widget is Draggable && widget.maxSimultaneousDrags == 0) return false;
    if (widget is Dismissible && widget.direction == DismissDirection.none) {
      return false;
    }
    if (widget is CheckboxListTile && widget.onChanged == null) return false;
    if (widget is Checkbox && widget.onChanged == null) return false;
    if (widget is SwitchListTile && widget.onChanged == null) return false;
    if (widget is Switch && widget.onChanged == null) return false;
    // Read only callback presence: a raw generic getter would cast a typed
    // ValueChanged<T?> to ValueChanged<dynamic>, which is not type-safe.
    if (widget is DropdownButton &&
        ((widget as dynamic).onChanged == null ||
            widget.items?.isNotEmpty != true)) {
      return false;
    }
    if (widget is DropdownButtonFormField &&
        (widget as dynamic).onChanged == null) {
      return false;
    }
    if ({_Kind.enterText, _Kind.clearText, _Kind.focus, _Kind.keyboardAction}
        .contains(action._kind)) {
      final field = _field(action);
      if (field == null ||
          !field.focusNode.canRequestFocus ||
          (field.readOnly && action._kind != _Kind.focus) ||
          (widget is TextField && widget.enabled == false)) {
        return false;
      }
    }
    if (action._kind == _Kind.dragTo && !_uniqueVisible(action.destination!)) {
      return false;
    }
    if (action._kind == _Kind.adjustSlider) {
      if (widget is! Slider ||
          widget.onChanged == null ||
          widget.min == widget.max) {
        return false;
      }
      if (action.sliderDirection == JevisSliderDirection.increase &&
          widget.value >= widget.max) {
        return false;
      }
      if (action.sliderDirection == JevisSliderDirection.decrease &&
          widget.value <= widget.min) {
        return false;
      }
    }
    return true;
  }

  Map<String, Object?> _control(int index, bool available,
      {JevisAction? concrete, String? id}) {
    final action = concrete ?? actions[index];
    final data = <String, Object?>{
      'id': id ?? _id(index),
      'description': action.description,
      'kind': action._kind.name,
      'available': available
    };
    final finder = action.finder;
    if (finder == null ||
        finder.evaluate().length != 1 ||
        finder.hitTestable().evaluate().length != 1) {
      return data;
    }
    final element = finder.evaluate().single;
    data['target'] = _explorer.reference(element);
    final widget = element.widget;
    data['widgetType'] = widget.runtimeType.toString();
    if (widget is IconButton && widget.tooltip != null) {
      data['tooltip'] = widget.tooltip;
    }
    if (widget is FloatingActionButton && widget.tooltip != null) {
      data['tooltip'] = widget.tooltip;
    }
    if (widget is Icon && widget.semanticLabel != null) {
      data['semanticsLabel'] = widget.semanticLabel;
    }
    if (widget is Semantics && widget.properties.label != null) {
      data['semanticsLabel'] = widget.properties.label;
    }
    final labels = find
        .descendant(of: finder, matching: find.byType(Text), matchRoot: true)
        .evaluate()
        .map((e) =>
            (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText() ??
            '')
        .toList();
    if (labels.isNotEmpty) data['labels'] = labels;
    if (widget is CheckboxListTile) data['checked'] = widget.value;
    if (widget is Checkbox) data['checked'] = widget.value;
    if (widget is SwitchListTile) data['checked'] = widget.value;
    if (widget is Switch) data['checked'] = widget.value;
    final field = _field(action);
    if (field != null) {
      data['focused'] = field.focusNode.hasFocus;
      data['empty'] = field.controller.text.isEmpty;
      data['obscured'] = field.obscureText;
      if (!field.obscureText) data['value'] = field.controller.text;
    }
    if (widget is Slider) {
      data.addAll({
        'value': widget.value,
        'min': widget.min,
        'max': widget.max,
        'divisions': widget.divisions
      });
    }
    if (widget is DropdownButton) {
      data['selectedValue'] = widget.value?.toString();
    }
    return data;
  }

  bool _uniqueVisible(Finder finder) =>
      finder.evaluate().length == 1 &&
      finder.hitTestable().evaluate().length == 1;

  void _checkException() {
    final error = tester.takeException();
    if (error != null) throw StateError('Flutter exception: $error');
  }

  JevisCandidate _candidate(String id, JevisAction action) {
    final details = <String, Object?>{};
    if (action.finder != null) {
      final target =
          compactUiTarget(_control(0, true, concrete: action, id: id))
            ..remove('state');
      if (target.isNotEmpty) details['target'] = target;
    }
    if (action.value != null) {
      details['value'] = _field(action)?.obscureText == true
          ? '[provided secret]'
          : action.value;
    }
    if (action.offset != null) {
      details['offset'] = [action.offset!.dx, action.offset!.dy];
    }
    if (action.keyboard != null) {
      details['keyboardAction'] = action.keyboard!.name;
    }
    if (action.sliderDirection != null) {
      details['direction'] = action.sliderDirection!.name;
      details['steps'] = action.steps;
    }
    if (action.destination != null) {
      final destination =
          JevisAction.tap('Destination', finder: action.destination);
      details['destination'] =
          compactUiTarget(_control(0, true, concrete: destination))
            ..remove('state');
    }
    if (action._kind == _Kind.wait ||
        action._kind == _Kind.longPress ||
        action._kind == _Kind.drag ||
        action._kind == _Kind.dragTo) {
      details['durationMs'] = action.duration.inMilliseconds;
    }
    if (action.holdDuration > Duration.zero) {
      details['holdMs'] = action.holdDuration.inMilliseconds;
    }
    if (action._kind == _Kind.custom ||
        action._kind == _Kind.waitUntil ||
        action._kind == _Kind.selectOption) {
      details['description'] = action.description;
    }
    return JevisCandidate(id, action.description,
        historyDescription:
            '${action._kind.name}(${details.isEmpty ? '' : jsonEncode(details)})');
  }

  @override
  Future<JevisObservation> observe() async {
    _checkException();
    final available = [
      for (final action in actions) action is! _UiAbility && _available(action)
    ];
    final ui = _explorer.observe();
    final visible = find
        .byType(Text)
        .evaluate()
        .where(
            (e) => find.byWidget(e.widget).hitTestable().evaluate().isNotEmpty)
        .map((e) =>
            (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText() ??
            '')
        .take(100)
        .toList();
    return JevisObservation(state: {
      'visibleText': visible,
      ...ui,
      'controls': [
        for (var i = 0; i < actions.length; i++)
          if (actions[i] is! _UiAbility) _control(i, available[i])
      ],
      if (observeState != null) 'app': observeState!()
    }, actions: [
      for (var i = 0; i < actions.length; i++)
        if (available[i]) _candidate(_id(i), actions[i]),
      for (final entry in _dynamicActions.entries)
        _candidate(entry.key, entry.value),
    ]);
  }

  @override
  Future<void> execute(String actionId) async {
    JevisAction action;
    if (_dynamicActions.containsKey(actionId)) {
      _explorer.validate(actionId);
      action = _dynamicActions[actionId]!;
    } else {
      final index = int.tryParse(actionId.replaceFirst('action_', '')) ?? -1;
      if (index < 0 ||
          index >= actions.length ||
          actionId != _id(index) ||
          actions[index] is _UiAbility ||
          !_available(actions[index])) {
        throw StateError('Action is no longer available: $actionId');
      }
      action = actions[index];
    }
    await _executeAction(action);
    if (action.waitFor != null) {
      await _waitFor(action.waitFor!);
    } else {
      await _settle();
    }
    if (options.stepDelay > Duration.zero) await tester.pump(options.stepDelay);
    _checkException();
  }
}

/// A failed autonomous run automatically fails its enclosing Flutter test.
class JevisTestFailure extends TestFailure {
  /// Colors are enabled by default unless explicitly disabled.
  JevisTestFailure(this.report, {bool? useColors})
      : super(formatFailureDiagnostics(report, useColors: useColors));
  final JevisReport report;
}

/// Initialize abilities once, then await test(goal: ..., attempts: ...).
/// By default the real Jevis API key is read from --dart-define-from-file.
class JevisTester {
  JevisTester(
      {required WidgetTester tester,
      required List<JevisAction> actions,
      String apiKey = const String.fromEnvironment('TYPESAFE_API_KEY'),
      String model = 'jev-latest',
      JevisBrain? brain,
      void Function(String body)? onRequest,
      void Function(int statusCode, String body)? onResponse,
      JevisOptions options = const JevisOptions(),
      Map<String, Object?> Function()? observe,
      this.useColors,
      this.onReport}) {
    options.validate();
    final driver = JevisFlutterDriver(
        tester: tester,
        actions: actions,
        observeState: observe,
        options: options);
    final selected = brain ??
        JevisClient(
            apiKey: apiKey,
            model: model,
            timeout: options.decisionTimeout,
            onRequest: onRequest,
            onResponse: onResponse);
    if (brain == null) addTearDown((selected as JevisClient).close);
    _runner = JevisRunner(
        driver: driver,
        brain: _RealAsyncBrain(tester, selected, options.decisionTimeout),
        options: options);
  }
  late final JevisRunner _runner;
  final void Function(JevisReport)? onReport;

  /// Overrides JEVIS_LOG_COLORS for forwarded device logs.
  /// Colors are enabled by default.
  final bool? useColors;
  bool _running = false;
  JevisReport? lastReport;

  /// [goal] is sent to Noul; [instruction] is sent to Choice.
  /// When [instruction] is omitted, [goal] is also used as the action instruction.
  /// [attempts] limits UI action executions, not retries of an entire scenario.
  /// Goal assessment is also performed after the final allowed action.
  /// [verify] optionally adds a deterministic check after model completion.
  Future<JevisReport> test({
    required String goal,
    String? instruction,
    required int attempts,
    FutureOr<bool> Function()? verify,
  }) async {
    if (_running) {
      throw StateError('Do not run concurrent goals on the same UI');
    }
    _running = true;
    lastReport = null;
    try {
      var report = await _runner.run(goal, instruction ?? goal, attempts);
      if (report.succeeded && verify != null) {
        bool passed;
        try {
          passed = await verify();
        } catch (e) {
          report = JevisReport(
              goal: goal,
              status: JevisStatus.verificationFailed,
              trace: report.trace,
              message: e.toString(),
              completionBasis: 'model+assertion');
          passed = false;
        }
        report = JevisReport(
            goal: goal,
            status:
                passed ? JevisStatus.succeeded : JevisStatus.verificationFailed,
            trace: report.trace,
            message: report.message,
            completionBasis: 'model+assertion');
      }
      lastReport = report;
      onReport?.call(report);
      if (!report.succeeded) {
        throw JevisTestFailure(report, useColors: useColors);
      }
      return report;
    } finally {
      _running = false;
    }
  }
}

class _RealAsyncBrain implements JevisBrain {
  _RealAsyncBrain(this.tester, this.delegate, this.timeout);
  final WidgetTester tester;
  final JevisBrain delegate;
  final Duration timeout;
  @override
  Future<JevisEvaluation> evaluate(JevisRequest request) async {
    final result = await tester
        .runAsync(() => delegate.evaluate(request).timeout(timeout));
    if (result == null) {
      final error = tester.takeException();
      throw StateError('Jevis evaluation failed: ${error ?? "no result"}');
    }
    return result;
  }
}
