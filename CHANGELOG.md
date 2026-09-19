## 0.1.1

- Add detailed console diagnostics for failed tests, including per-step goal probabilities, action confidence, selected actions, and errors.
- Display candidate actions in a probability-sorted table with action descriptions and a selected-action indicator.
- Colorize console probabilities by default, with `useColors` and `JEVIS_LOG_COLORS` options to control color output.
- Lower the default `goalThreshold` from `0.95` to `0.6` and `actionThreshold` from `0.5` to `0.2`.

## 0.1.0

Initial registered-action proof of concept with developer-supplied assertions.
