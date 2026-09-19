# Action reference

[English README](../README.md) | [한국어 README](../README.ko.md) | [日本語 README](../README.ja.md)

This reference expands the action examples in the README. For installation and API key setup, see [How to start](../README.md#how-to-start).

Examples use these imports inside a Flutter test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jevis_flutter/jevis_flutter.dart';
```

Register only the actions needed by a test. Jev selects one declared action; the driver performs it, waits for the screen, and observes the actual result. Descriptions explain when an action is useful and may describe its expected effect. They are sent unchanged as Choice criteria, not treated as evidence that the effect has happened.

## Discovered abilities (`JevisActions`)

`JevisActions.focus()` discovers visible input targets without a key or finder. The plural API also exposes `clearText`, `keyboardAction`, `longPress`, `doubleTap`, `drag`, `dragTo`, `selectOption`, `adjustSlider`, `wait`, and `waitUntil`, alongside `tap`, `enterText`, `scroll`, and `back`.

```dart
JevisActions.focus();
JevisActions.clearText();
JevisActions.keyboardAction(action: TextInputAction.search);
JevisActions.longPress(instruction: 'Hold the note to reveal its delete button.');
JevisActions.doubleTap();
JevisActions.drag(offset: const Offset(-250, 0));
JevisActions.dragTo(
  destination: find.byKey(const ValueKey('catalog_drop_target')),
  holdDuration: const Duration(milliseconds: 650),
);
JevisActions.selectOption();
JevisActions.adjustSlider(steps: 1);
```

Only supplied abilities generate candidates. Disabled or offscreen targets are excluded, and each candidate is revalidated before execution. Focus excludes already focused inputs; clear excludes empty or read-only inputs. Omitting `keyboardAction.action` uses an explicitly declared input action; inputs with no declared action are skipped. Gesture discovery recognizes callbacks on ListTile, ButtonStyleButton, GestureDetector and InkWell, avoiding their nested implementation widgets. It cannot infer arbitrary canvas interactions or a gesture's business effect; use `instruction` for that context.

`drag` uses developer-supplied offset and duration on discovered Dismissible, Draggable, Slider or drag-enabled GestureDetector targets. For LongPressDraggable, use `dragTo` with an adequate `holdDuration`. `dragTo` discovers sources but requires a destination Finder: the driver does not infer arbitrary drop-acceptance logic. Both endpoints must be uniquely visible.

`selectOption` supports DropdownButton (including the one inside DropdownButtonFormField). It opens the dropdown as one action; a later observation offers enabled, visible DropdownMenuItem targets. An optional `values` list restricts menu choices to exact text labels. Register `scroll()` to reveal offscreen options. Custom menus and Material DropdownMenu are not included in this helper. Unlike singular `JevisAction.selectOption`, this is deliberately two separate actions and observations.

`adjustSlider` offers both valid directions, or a configured `direction`, using actual Material Slider semantics. `wait(duration: ...)` and `waitUntil(condition: ..., description: ...)` are target-independent wrappers of their singular counterparts. They remain selectable abilities, not automatically inserted steps. These helpers retain the normal settling behavior; singular registrations support a per-action `waitFor` when necessary.

## Explicit targets (`JevisAction`)

The APIs below register specific targets. Both styles may be mixed in the same `actions` list.

```dart
final agent = JevisTester(
  tester: tester,
  actions: [
    JevisAction.longPress(
      'Long-press the Buy milk todo to reveal its delete icon.',
      key: 'milk_todo',
      waitFor: JevisWait.visible(key: 'delete_todo'),
    ),
    JevisAction.tap('Delete the selected todo.', key: 'delete_todo'),
    JevisAction.doubleTap('Double-tap the preview to expand it.', key: 'preview'),
    JevisAction.drag(
      'Swipe the todo left to reveal its actions.',
      key: 'milk_todo',
      offset: const Offset(-250, 0),
      duration: const Duration(milliseconds: 500),
    ),
    JevisAction.dragTo(
      'Move the item into the completed column.',
      key: 'draggable_item',
      destinationKey: 'completed_column',
      holdDuration: const Duration(milliseconds: 650),
      duration: const Duration(milliseconds: 500),
    ),
  ],
);
await agent.test(goal: 'The Buy milk todo is deleted.',
  instruction: 'Reveal the delete button for Buy milk and delete it.', attempts: 20);
```

The snippets assume your app implements the described callbacks and exposes the shown keys. Registering an action does not add a delete menu or other behavior to the app. Use exactly one of `key` or `finder` for the source. `dragTo` similarly accepts exactly one of `destinationKey` or `destination`. Both drag endpoints must be uniquely identifiable and hit-testable before execution. The drag path is fixed between their initial centers; it does not track a moving target or auto-scroll to an offscreen destination. `holdDuration` supports long-press draggable controls. `drag` duration controls the speed of a swipe as well as its distance.

## Forms

```dart
JevisAction.clearText('Clear the query.', key: 'query');
JevisAction.enterText('Replace the query with milk.', key: 'query', value: 'milk');
JevisAction.focus('Focus the query field.', key: 'query');
JevisAction.keyboardAction(
  'Submit the query using the keyboard search action.',
  key: 'query',
  action: TextInputAction.search,
);
JevisAction.keyboardAction(
  'Move to the next input field.',
  key: 'email',
  action: TextInputAction.next,
);
JevisAction.selectOption(
  'Choose High priority.',
  key: 'priority_dropdown',
  option: find.text('High'),
);
```

Input targets must be an `EditableText` or contain exactly one, as with `TextField` and `TextFormField`. `enterText` replaces the current value; `clearText` replaces it with an empty string. `keyboardAction` focuses the specified field, then delivers Flutter's IME action. This does not automate a native keyboard button; the app controls submission and next-focus behavior.

`selectOption` is one registered composite action: it opens the menu and then taps the explicitly supplied option. It waits for menu animations internally. It can reveal a uniquely mounted offscreen option with `ensureVisible`; it does not search an unbuilt lazy list. A missing, ambiguous or disabled option fails the action. For custom menus, use a sufficiently specific finder and `availableWhen`, or register opening and selecting as separate tap actions.

## Sliders

```dart
JevisAction.adjustSlider(
  'Increase the volume by two steps.',
  key: 'volume',
  direction: JevisSliderDirection.increase,
  steps: 2,
);
```

The target must be an enabled Flutter Material `Slider`. Each step performs its actual accessibility increase/decrease action, then reads the updated widget value. Discrete sliders advance one division; continuous sliders use Flutter's default accessibility increment. Adjustment stops at a boundary. If the app rejects the change or moves in the opposite direction, execution fails rather than assuming success.

This API does not promise an arbitrary exact value or simulate a touch on the slider track. Use a parameterized `drag` when testing pointer behavior. Custom sliders and `RangeSlider` can use `JevisAction.custom`; they are not covered by `adjustSlider`.

## Waiting for results

Explicit `JevisAction` registrations support a final wait condition. Most constructors accept `waitFor`; `waitUntil` takes its condition through `condition`. Without it, the driver retains its existing `pumpAndSettle` behavior. With it, the final wait pumps frames until the declared condition is met or times out, even when an unrelated animation continues.

```dart
JevisAction.tap(
  'Save the form.',
  key: 'save',
  waitFor: JevisWait.visible(
    key: 'saved_message',
    timeout: const Duration(seconds: 10),
  ),
);
JevisAction.waitUntil(
  'Wait until loading disappears.',
  condition: JevisWait.absent(key: 'loading_indicator'),
);
JevisAction.wait(
  description: 'Wait briefly for the next update.',
  duration: const Duration(milliseconds: 300),
);
```

`visible` requires at least one hit-testable match. `absent` requires no matches from the supplied finder (including its normal offstage filtering). These are UI conditions, not proof of backend persistence. The default poll interval is 50 ms and timeout is 5 seconds. Internal waits inside a composite action, such as opening a dropdown, are separate from its final `waitFor` condition.

Descriptions should name the target and expected effect. No action description is automatically translated or decomposed into additional model calls. Pinch/multitouch, OS dialogs, arbitrary custom-widget interpretation, and native platform automation are not supported by the built-in actions.
