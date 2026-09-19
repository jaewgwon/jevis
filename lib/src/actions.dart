part of 'flutter_agent.dart';

enum _Kind {
  tap,
  longPress,
  doubleTap,
  enterText,
  clearText,
  focus,
  keyboardAction,
  scroll,
  drag,
  dragTo,
  selectOption,
  adjustSlider,
  wait,
  waitUntil,
  custom
}

/// Direction of Flutter's accessibility slider adjustment.
enum JevisSliderDirection { increase, decrease }

/// A bounded UI condition used instead of waiting for all animations to stop.
class JevisWait {
  JevisWait.visible(
      {String? key,
      Finder? finder,
      Duration timeout = const Duration(seconds: 5),
      Duration pollInterval = const Duration(milliseconds: 50)})
      : this._(JevisAction._target(key, finder), true, timeout, pollInterval);
  JevisWait.absent(
      {String? key,
      Finder? finder,
      Duration timeout = const Duration(seconds: 5),
      Duration pollInterval = const Duration(milliseconds: 50)})
      : this._(JevisAction._target(key, finder), false, timeout, pollInterval);
  JevisWait._(this.finder, this.visible, this.timeout, this.pollInterval) {
    JevisAction._positive(timeout);
    JevisAction._positive(pollInterval);
  }
  final Finder finder;
  final bool visible;
  final Duration timeout, pollInterval;
}

/// A declared ability, not a prescribed step. Descriptions go to Jevis unchanged.
class JevisAction {
  JevisAction._(this.description, this._kind,
      {this.finder,
      this.value,
      this.offset,
      this.callback,
      this.availableWhen,
      this.waitFor,
      this.destination,
      this.option,
      this.keyboard,
      this.sliderDirection,
      this.steps = 1,
      this.duration = const Duration(milliseconds: 500),
      this.holdDuration = Duration.zero});

  JevisAction.tap(String description,
      {String? key,
      Finder? finder,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.tap,
            finder: _target(key, finder),
            availableWhen: availableWhen,
            waitFor: waitFor);

  JevisAction.longPress(String description,
      {String? key,
      Finder? finder,
      Duration duration = const Duration(milliseconds: 650),
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.longPress,
            finder: _target(key, finder),
            duration: _positive(duration),
            availableWhen: availableWhen,
            waitFor: waitFor);

  JevisAction.doubleTap(String description,
      {String? key,
      Finder? finder,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.doubleTap,
            finder: _target(key, finder),
            availableWhen: availableWhen,
            waitFor: waitFor);

  /// Replaces the entire current input value.
  JevisAction.enterText(String description,
      {String? key,
      Finder? finder,
      required String value,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.enterText,
            finder: _target(key, finder),
            value: value,
            availableWhen: availableWhen,
            waitFor: waitFor);

  JevisAction.clearText(String description,
      {String? key,
      Finder? finder,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.clearText,
            finder: _target(key, finder),
            availableWhen: availableWhen,
            waitFor: waitFor);

  /// Focuses one EditableText or a widget containing exactly one EditableText.
  JevisAction.focus(String description,
      {String? key,
      Finder? finder,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.focus,
            finder: _target(key, finder),
            availableWhen: availableWhen,
            waitFor: waitFor);

  /// Focuses the input, then delivers its IME action (done, search, next, etc.).
  JevisAction.keyboardAction(String description,
      {String? key,
      Finder? finder,
      required TextInputAction action,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.keyboardAction,
            finder: _target(key, finder),
            keyboard: action,
            availableWhen: availableWhen,
            waitFor: waitFor);

  JevisAction.scroll(String description,
      {String? key,
      Finder? finder,
      Offset offset = const Offset(0, -300),
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.scroll,
            finder: _target(key, finder),
            offset: _displacement(offset),
            availableWhen: availableWhen,
            waitFor: waitFor);

  /// A timed pointer drag. Offset determines direction/distance, duration speed.
  JevisAction.drag(String description,
      {String? key,
      Finder? finder,
      required Offset offset,
      Duration duration = const Duration(milliseconds: 500),
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.drag,
            finder: _target(key, finder),
            offset: _displacement(offset),
            duration: _positive(duration),
            availableWhen: availableWhen,
            waitFor: waitFor);

  /// Drags between current target centers; optionally holds before moving.
  JevisAction.dragTo(String description,
      {String? key,
      Finder? finder,
      String? destinationKey,
      Finder? destination,
      Duration duration = const Duration(milliseconds: 500),
      Duration holdDuration = Duration.zero,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.dragTo,
            finder: _target(key, finder),
            destination: _target(destinationKey, destination),
            duration: _positive(duration),
            holdDuration: _nonNegative(holdDuration),
            availableWhen: availableWhen,
            waitFor: waitFor);

  /// Opens a dropdown/menu and selects an explicitly identified mounted option.
  JevisAction.selectOption(String description,
      {String? key,
      Finder? finder,
      required Finder option,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.selectOption,
            finder: _target(key, finder),
            option: option,
            availableWhen: availableWhen,
            waitFor: waitFor);

  /// Uses actual Slider semantics, not direct callbacks or assumed track geometry.
  /// Each step is one division, or Flutter's default continuous-slider increment.
  JevisAction.adjustSlider(String description,
      {String? key,
      Finder? finder,
      required JevisSliderDirection direction,
      int steps = 1,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.adjustSlider,
            finder: _target(key, finder),
            sliderDirection: direction,
            steps: _positiveSteps(steps),
            availableWhen: availableWhen,
            waitFor: waitFor);

  JevisAction.wait(
      {String description = 'Wait for the screen to update',
      Duration duration = const Duration(milliseconds: 300),
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.wait,
            duration: _positive(duration),
            availableWhen: availableWhen,
            waitFor: waitFor);

  JevisAction.waitUntil(String description,
      {required JevisWait condition, bool Function()? availableWhen})
      : this._(description, _Kind.waitUntil,
            waitFor: condition, availableWhen: availableWhen);

  JevisAction.custom(String description,
      {required Future<void> Function(WidgetTester) run,
      bool Function()? availableWhen,
      JevisWait? waitFor})
      : this._(description, _Kind.custom,
            callback: run, availableWhen: availableWhen, waitFor: waitFor);

  final String description;
  final Finder? finder, destination, option;
  final String? value;
  final Offset? offset;
  final bool Function()? availableWhen;
  final Future<void> Function(WidgetTester)? callback;
  final Duration duration, holdDuration;
  final TextInputAction? keyboard;
  final JevisSliderDirection? sliderDirection;
  final int steps;
  final JevisWait? waitFor;
  final _Kind _kind;

  static Finder _target(String? key, Finder? finder) {
    if ((key == null) == (finder == null)) {
      throw ArgumentError('Provide exactly one of key or finder');
    }
    return finder ?? find.byKey(ValueKey(key!));
  }

  static Duration _positive(Duration value) {
    if (value <= Duration.zero) {
      throw ArgumentError('Duration must be positive');
    }
    return value;
  }

  static Duration _nonNegative(Duration value) {
    if (value < Duration.zero) {
      throw ArgumentError('Duration must not be negative');
    }
    return value;
  }

  static Offset _displacement(Offset value) {
    if (!value.dx.isFinite || !value.dy.isFinite || value == Offset.zero) {
      throw ArgumentError('Offset must be finite and non-zero');
    }
    return value;
  }

  static int _positiveSteps(int value) {
    if (value < 1) throw ArgumentError('Steps must be positive');
    return value;
  }
}
