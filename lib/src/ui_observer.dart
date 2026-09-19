part of 'flutter_agent.dart';

/// Opt-in abilities. Concrete targets are discovered again on every step.
abstract final class JevisActions {
  static JevisAction tap() => _UiAbility('tap');
  static JevisAction enterText({required List<String> values}) {
    if (values.isEmpty) throw ArgumentError('Provide at least one input value');
    return _UiAbility('input', values: List.unmodifiable(values.toSet()));
  }

  static JevisAction scroll() => _UiAbility('scroll');
  static JevisAction back() => _UiAbility('back');

  /// Discovers visible inputs that are not already focused.
  static JevisAction focus({String? instruction}) => _UiAbility('focus',
      expand: (e, role, data, target) => [
            if (role == 'input' && data['focused'] != true)
              JevisAction.focus(_instruction('Focus', data, instruction),
                  finder: target),
          ]);

  static JevisAction clearText({String? instruction}) => _UiAbility('clearText',
      expand: (e, role, data, target) => [
            if (role == 'input' && data['empty'] == false)
              JevisAction.clearText(_instruction('Clear', data, instruction),
                  finder: target),
          ]);

  /// When omitted, uses each input's declared IME action.
  static JevisAction keyboardAction(
          {TextInputAction? action, String? instruction}) =>
      _UiAbility('keyboardAction', expand: (e, role, data, target) {
        if (role != 'input') return [];
        final field = e.widget;
        final keyboard = action ??
            (field is TextField
                ? field.textInputAction
                : (field as EditableText).textInputAction);
        if (keyboard == null ||
            keyboard == TextInputAction.none ||
            keyboard == TextInputAction.unspecified) {
          return [];
        }
        return [
          JevisAction.keyboardAction(
              _instruction('Send keyboard ${keyboard.name}', data, instruction),
              finder: target,
              action: keyboard)
        ];
      });

  static JevisAction longPress({
    String? instruction,
    Duration duration = const Duration(milliseconds: 650),
  }) {
    JevisAction._positive(duration);
    return _UiAbility('longPress',
        expand: (e, role, data, target) => [
              if (_supportsLongPress(e.widget))
                JevisAction.longPress(
                    _instruction('Long press', data, instruction),
                    finder: target,
                    duration: duration),
            ]);
  }

  static JevisAction doubleTap({String? instruction}) => _UiAbility('doubleTap',
      expand: (e, role, data, target) => [
            if ((e.widget is GestureDetector &&
                    (e.widget as GestureDetector).onDoubleTap != null) ||
                (e.widget is InkWell &&
                    (e.widget as InkWell).onDoubleTap != null))
              JevisAction.doubleTap(_instruction('Double tap', data, instruction),
                  finder: target),
          ]);

  static JevisAction drag({
    required Offset offset,
    Duration duration = const Duration(milliseconds: 500),
    String? instruction,
  }) {
    JevisAction._displacement(offset);
    JevisAction._positive(duration);
    return _UiAbility('drag',
        expand: (e, role, data, target) => [
              if (role == 'draggable' ||
                  role == 'slider' ||
                  (e.widget is Dismissible &&
                      (e.widget as Dismissible).direction !=
                          DismissDirection.none) ||
                  (e.widget is GestureDetector &&
                      _supportsDrag(e.widget as GestureDetector)))
                JevisAction.drag(
                    _instruction('Drag by (${offset.dx}, ${offset.dy})', data,
                        instruction),
                    finder: target,
                    offset: offset,
                    duration: duration),
            ]);
  }

  /// Discovers Draggable sources. The destination is explicitly supplied because
  /// arbitrary drop acceptance predicates cannot be inferred from the screen.
  static JevisAction dragTo({
    required Finder destination,
    Duration duration = const Duration(milliseconds: 500),
    Duration holdDuration = Duration.zero,
    String? instruction,
  }) {
    JevisAction._positive(duration);
    JevisAction._nonNegative(holdDuration);
    return _UiAbility('dragTo',
        expand: (e, role, data, target) => [
              if (role == 'draggable')
                JevisAction.dragTo(
                    _instruction('Drag to $destination', data, instruction),
                    finder: target,
                    destination: destination,
                    duration: duration,
                    holdDuration: holdDuration),
            ]);
  }

  /// Opens a dropdown, then offers visible menu items on the next observation.
  /// Optional values restrict selection to matching text labels.
  static JevisAction selectOption({List<String>? values, String? instruction}) {
    if (values != null && values.isEmpty) {
      throw ArgumentError('Provide at least one option label or omit values');
    }
    final labels = values == null ? null : Set<String>.unmodifiable(values);
    return _UiAbility('selectOption',
        expand: (e, role, data, target) => [
              if (role == 'dropdown')
                JevisAction.tap(_instruction('Open dropdown', data, instruction),
                    finder: target),
              if (role == 'menuOption' &&
                  (labels == null ||
                      (data['labels'] as List? ?? []).any(labels.contains)))
                JevisAction.tap(_instruction('Select option', data, instruction),
                    finder: target),
            ]);
  }

  /// Offers both directions unless a single direction is requested.
  static JevisAction adjustSlider(
      {JevisSliderDirection? direction, int steps = 1, String? instruction}) {
    JevisAction._positiveSteps(steps);
    return _UiAbility('adjustSlider',
        expand: (e, role, data, target) => [
              if (role == 'slider')
                for (final d in direction == null
                    ? JevisSliderDirection.values
                    : [direction])
                  JevisAction.adjustSlider(
                      _instruction('${d.name} slider by $steps steps', data,
                          instruction),
                      finder: target,
                      direction: d,
                      steps: steps),
            ]);
  }

  static JevisAction wait(
          {Duration duration = const Duration(milliseconds: 300)}) =>
      JevisAction.wait(duration: duration);

  static JevisAction waitUntil(
          {required JevisWait condition,
          String description = 'Wait for the UI condition'}) =>
      JevisAction.waitUntil(description, condition: condition);

  static String _instruction(
          String verb, Map<String, Object?> data, String? instruction) =>
      '$verb ${jsonEncode(compactUiTarget(data))}${instruction == null ? '' : '. $instruction'}';

  static bool _supportsLongPress(Widget w) =>
      (w is ListTile && w.enabled && w.onLongPress != null) ||
      (w is ButtonStyleButton && w.onLongPress != null) ||
      (w is GestureDetector && w.onLongPress != null) ||
      (w is InkWell && w.onLongPress != null);

  static bool _supportsDrag(GestureDetector w) =>
      w.onPanStart != null ||
      w.onPanUpdate != null ||
      w.onPanEnd != null ||
      w.onHorizontalDragStart != null ||
      w.onHorizontalDragUpdate != null ||
      w.onHorizontalDragEnd != null ||
      w.onVerticalDragStart != null ||
      w.onVerticalDragUpdate != null ||
      w.onVerticalDragEnd != null;
}

class _UiAbility extends JevisAction {
  _UiAbility(this.ability, {this.values = const [], this.expand})
      : super.custom('Discover $ability targets', run: (_) async {});
  final String ability;
  final List<String> values;
  final List<JevisAction> Function(Element, String, Map<String, Object?>, Finder)?
      expand;
}

class _UiExplorer {
  _UiExplorer(this.driver);
  final JevisFlutterDriver driver;
  final Map<String, Map<String, Object?>> _memory = {};
  final Map<String, void Function()> _validators = {};
  final Map<String, int> _candidateIds = {};
  Expando<int> _identities = Expando<int>();
  int _nextIdentity = 0;
  bool _truncated = false;
  void reset() {
    _memory.clear();
    _validators.clear();
    _candidateIds.clear();
    _identities = Expando<int>();
    _nextIdentity = 0;
    _truncated = false;
  }

  String reference(Element element) =>
      'w${_identities[element] ??= _nextIdentity++}';

  Finder _finder(Element element) =>
      find.byElementPredicate((e) => identical(e, element));
  bool _visible(Element e) =>
      e.mounted && _finder(e).hitTestable().evaluate().isNotEmpty;

  String? _role(Element element) {
    final w = element.widget;
    if (w is CheckboxListTile || w is SwitchListTile) return 'toggle';
    if (w is Checkbox || w is Switch) {
      var nested = false;
      element.visitAncestorElements((e) {
        if (e.widget is CheckboxListTile || e.widget is SwitchListTile) {
          nested = true;
        }
        return !nested;
      });
      return nested ? null : 'toggle';
    }
    if (w is TextField) return 'input';
    if (w is EditableText) {
      var nested = false;
      element.visitAncestorElements((e) {
        if (e.widget is TextField) nested = true;
        return !nested;
      });
      return nested ? null : 'input';
    }
    if (w is Slider) return 'slider';
    if (w is DropdownButton) return 'dropdown';
    if (w is DropdownMenuItem) {
      var nested = false;
      element.visitAncestorElements((e) {
        if (e.widget is DropdownButton || e.widget is InkWell) nested = true;
        return !nested;
      });
      return nested ? null : 'menuOption';
    }
    if (w is Draggable) return 'draggable';
    if (w is Dismissible) return 'dismissible';
    if (w is InkWell || w is GestureDetector) {
      var nested = false;
      element.visitAncestorElements((e) {
        final ancestor = e.widget;
        if (ancestor is TextField ||
            ancestor is EditableText ||
            ancestor is ButtonStyleButton ||
            ancestor is IconButton ||
            ancestor is FloatingActionButton ||
            ancestor is ListTile ||
            ancestor is CheckboxListTile ||
            ancestor is SwitchListTile ||
            ancestor is Checkbox ||
            ancestor is Switch ||
            ancestor is Slider ||
            ancestor is DropdownButton ||
            ancestor is Draggable ||
            ancestor is Dismissible ||
            ancestor is InkWell) {
          nested = true;
        }
        return !nested;
      });
      if (nested) return null;
      if (w is InkWell) {
        final items = find
            .descendant(
                of: _finder(element),
                matching: find.byWidgetPredicate((w) => w is DropdownMenuItem))
            .evaluate();
        // Flutter handles menu selection on the item's enclosing InkWell.
        // The item's own center may not participate in hit testing.
        if (items.length == 1) {
          return (items.single.widget as DropdownMenuItem).enabled
              ? 'menuOption'
              : null;
        }
      }
      if (w is InkWell &&
          (w.onTap != null || w.onDoubleTap != null || w.onLongPress != null)) {
        return 'gesture';
      }
      if (w is GestureDetector &&
          (w.onTap != null ||
              w.onDoubleTap != null ||
              w.onLongPress != null ||
              JevisActions._supportsDrag(w))) {
        return 'gesture';
      }
      return null;
    }
    if (w is ButtonStyleButton ||
        w is IconButton ||
        w is FloatingActionButton) {
      return 'button';
    }
    if (w is ListTile && (w.onTap != null || w.onLongPress != null)) {
      var nested = false;
      element.visitAncestorElements((e) {
        if (e.widget is CheckboxListTile || e.widget is SwitchListTile) {
          nested = true;
        }
        return !nested;
      });
      return nested ? null : 'button';
    }
    if (w is Scrollable) return 'scrollable';
    return null;
  }

  Map<String, Object?> _describe(Element e, String role) {
    final finder = _finder(e);
    final widget = e.widget;
    final JevisAction action;
    if (role == 'input') {
      action = JevisAction.focus('Input', finder: finder);
    } else if (JevisActions._supportsLongPress(widget)) {
      action = JevisAction.longPress('Target', finder: finder);
    } else if ((widget is GestureDetector && widget.onDoubleTap != null) ||
        (widget is InkWell && widget.onDoubleTap != null)) {
      action = JevisAction.doubleTap('Target', finder: finder);
    } else if (widget is GestureDetector && JevisActions._supportsDrag(widget)) {
      action =
          JevisAction.drag('Target', finder: finder, offset: const Offset(1, 0));
    } else {
      action = JevisAction.tap('Target', finder: finder);
    }
    final data =
        driver._control(0, driver._available(action), concrete: action);
    data.remove('id');
    data.remove('description');
    data.remove('kind');
    data['role'] = role;
    final w = e.widget;
    if (w is GestureDetector) {
      data['gestures'] = [
        if (w.onTap != null) 'tap',
        if (w.onDoubleTap != null) 'doubleTap',
        if (w.onLongPress != null) 'longPress',
        if (JevisActions._supportsDrag(w)) 'drag',
      ];
    }
    if (w is TextField) data['keyboardAction'] = w.textInputAction?.name;
    if (w is EditableText) data['keyboardAction'] = w.textInputAction?.name;
    if (w is Draggable) data['dragEnabled'] = w.maxSimultaneousDrags != 0;
    if (w is Dismissible) data['dismissDirection'] = w.direction.name;
    if (w is IconButton && w.tooltip != null) data['tooltip'] = w.tooltip;
    if (w is FloatingActionButton && w.tooltip != null) {
      data['tooltip'] = w.tooltip;
    }
    if (w is TextField && w.decoration?.labelText != null) {
      data['label'] = w.decoration!.labelText;
    }
    if (e is StatefulElement && e.state is ScrollableState) {
      final state = e.state as ScrollableState;
      final p = state.position;
      data.addAll({
        'pixels': p.pixels.roundToDouble(),
        'minScrollExtent':
            p.minScrollExtent.isFinite ? p.minScrollExtent : null,
        'maxScrollExtent':
            p.maxScrollExtent.isFinite ? p.maxScrollExtent : null,
        'viewportDimension': p.viewportDimension,
        'axisDirection': state.axisDirection.name,
        'canScrollForward': p.physics.shouldAcceptUserOffset(p) &&
            p.pixels < p.maxScrollExtent - 1,
        'canScrollBackward': p.physics.shouldAcceptUserOffset(p) &&
            p.pixels > p.minScrollExtent + 1,
      });
      // Content is described by visible controls, not every cached list child.
      data.remove('labels');
    }
    return data;
  }

  ({String id, bool stable}) _identity(Element e, String role) {
    final path = <String>[];
    var ownKey = false;
    void add(Element node) {
      final key = node.widget.key;
      if (key is ValueKey &&
          (key.value is String || key.value is int) &&
          !key.runtimeType.toString().startsWith('_')) {
        path.add('${node.widget.runtimeType}:$key');
        if (identical(e, node)) ownKey = true;
      }
    }

    add(e);
    var insideUnkeyedList = false;
    e.visitAncestorElements((node) {
      if (node.widget is Scrollable && path.isEmpty && role != 'scrollable') {
        insideUnkeyedList = true;
      }
      if (!insideUnkeyedList) add(node);
      return true;
    });
    // A keyed row may contain an unkeyed control; distinguish its structural path.
    if (!ownKey && path.isNotEmpty) {
      final offsets = <int>[];
      Element child = e;
      e.visitAncestorElements((parent) {
        final children = <Element>[];
        parent.visitChildren(children.add);
        offsets.add(children.indexOf(child));
        child = parent;
        return parent.widget.key is! ValueKey;
      });
      path.insert(0, '$role:${offsets.join('.')}');
    }
    final stable = path.isNotEmpty;
    final raw = stable
        ? path.reversed.join('/')
        : 'ephemeral:${_identities[e] ??= _nextIdentity++}';
    return (id: '$role:$raw', stable: stable);
  }

  Map<String, Object?> observe() {
    driver._dynamicActions.clear();
    _validators.clear();
    final abilities = driver.actions.whereType<_UiAbility>().toList();
    if (abilities.isEmpty) return {};
    bool has(String ability) => abilities.any((a) => a.ability == ability);
    final elements = <Map<String, Object?>>[];
    final used = <String>{};
    final visibleIds = <String>{};
    final discovered = <String>[];
    final updated = <String>[];
    for (final e
        in find.byElementPredicate((e) => _role(e) != null).evaluate()) {
      if (!_visible(e)) continue;
      final role = _role(e)!;
      final identity = _identity(e, role);
      if (!used.add(identity.id)) {
        throw StateError(
            'Ambiguous UI identity: ${identity.id}. Use unique scoped ValueKeys.');
      }
      final data = <String, Object?>{
        'id': identity.id,
        'identity': identity.stable ? 'stableKey' : 'ephemeral',
        ..._describe(e, role),
      };
      elements.add(data);
      visibleIds.add(identity.id);
      if (identity.stable) {
        if (_memory.length < 500 || _memory.containsKey(identity.id)) {
          if (!_memory.containsKey(identity.id)) {
            discovered.add(identity.id);
          } else if (jsonEncode(_memory[identity.id]) != jsonEncode(data)) {
            updated.add(identity.id);
          }
          _memory[identity.id] = Map.of(data);
        } else {
          _truncated = true;
        }
      }
      final target = _finder(e);
      final label = jsonEncode(compactUiTarget(data));
      void offer(String verb, JevisAction action) {
        if (!driver._available(action)) return;
        final number = _candidateIds.putIfAbsent(
            '${identity.id}/$verb', () => _candidateIds.length);
        final id = 'ui_${verb}_$number';
        driver._dynamicActions[id] = action;
        final snapshot = jsonEncode(_describe(e, role));
        _validators[id] = () {
          if (!e.mounted ||
              !_visible(e) ||
              _identity(e, role).id != identity.id ||
              jsonEncode(_describe(e, role)) != snapshot ||
              !driver._available(action)) {
            throw StateError(
                'UI target changed after observation: ${identity.id}');
          }
        };
      }

      for (var abilityIndex = 0;
          abilityIndex < abilities.length;
          abilityIndex++) {
        final expanded =
            abilities[abilityIndex].expand?.call(e, role, data, target) ??
                <JevisAction>[];
        for (var i = 0; i < expanded.length; i++) {
          offer('${abilities[abilityIndex].ability}_${abilityIndex}_$i',
              expanded[i]);
        }
      }
      final w = e.widget;
      final gestureTap = (w is GestureDetector && w.onTap != null) ||
          (w is InkWell && w.onTap != null);
      final tapTarget = role == 'menuOption'
          ? !has('selectOption')
          : role == 'button' || role == 'toggle' || gestureTap;
      if (has('tap') && tapTarget) {
        offer('tap', JevisAction.tap('Tap $label', finder: target));
      }
      if (role == 'input') {
        final values = abilities
            .where((a) => a.ability == 'input')
            .expand((a) => a.values)
            .toSet()
            .toList();
        for (var i = 0; i < values.length; i++) {
          if (data['obscured'] != true && data['value'] == values[i]) continue;
          offer(
              'input_$i',
              JevisAction.enterText(
                  'Enter ${data['obscured'] == true ? '[provided secret]' : jsonEncode(values[i])} into $label',
                  finder: target,
                  value: values[i]));
        }
      }
      if (has('scroll') && role == 'scrollable') {
        final state = (e as StatefulElement).state as ScrollableState;
        final distance = state.position.viewportDimension * .7;
        final forward = switch (state.axisDirection) {
          AxisDirection.down => Offset(0, -distance),
          AxisDirection.up => Offset(0, distance),
          AxisDirection.right => Offset(-distance, 0),
          AxisDirection.left => Offset(distance, 0),
        };
        if (data['canScrollForward'] == true) {
          offer(
              'forward',
              JevisAction.scroll(
                  'Scroll forward to reveal more content in $label',
                  finder: target,
                  offset: forward));
        }
        if (data['canScrollBackward'] == true) {
          offer(
              'backward',
              JevisAction.scroll('Scroll backward to revisit content in $label',
                  finder: target, offset: -forward));
        }
      }
    }
    if (has('back')) {
      final navigators = find
          .byType(Navigator)
          .evaluate()
          .whereType<StatefulElement>()
          .toList();
      for (final element in navigators.reversed) {
        final navigator = element.state as NavigatorState;
        if (!navigator.canPop()) continue;
        driver._dynamicActions['ui_back'] =
            JevisAction.custom('Go back to the previous screen', run: (_) async {
          await navigator.maybePop();
        });
        _validators['ui_back'] = () {
          if (!navigator.mounted || !navigator.canPop()) {
            throw StateError('Back is no longer available');
          }
        };
        break;
      }
    }
    if (driver._dynamicActions.length +
            driver.actions.where((a) => a is! _UiAbility).length >
        254) {
      throw StateError(
          'Too many UI candidates (limit 254). Narrow the supplied abilities or input values.');
    }
    return {
      'elements': elements,
      'changes': {'newlyObserved': discovered, 'updated': updated},
      'memory': {
        'elements': [
          for (final item in _memory.entries)
            {...item.value, 'visible': visibleIds.contains(item.key)}
        ],
        'truncated': _truncated,
        'meaning':
            'Distinct keyed controls last observed during this run. Offscreen values are historical, not proof of current existence or state. Ephemeral controls are not accumulated. Scroll extent is not an item count.',
      },
    };
  }

  void validate(String id) {
    final check = _validators[id];
    if (check == null) throw StateError('Unknown or expired UI candidate: $id');
    check();
  }
}
