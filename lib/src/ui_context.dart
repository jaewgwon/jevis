/// Projects observations into visible text, widget names and current UI state.
/// Internal identities, geometry, history and expected effects stay local.
Map<String, Object?> compactUiTarget(Map data) {
  final text = <String>{};
  void add(Object? value) {
    if (value is String && value.trim().isNotEmpty) text.add(value);
  }

  if (data['labels'] is List) {
    for (final label in data['labels'] as List) {
      add(label);
    }
  }
  add(data['label']);
  add(data['tooltip']);
  add(data['semanticsLabel']);
  final state = <String, Object?>{};
  for (final key in [
    'available',
    'checked',
    'focused',
    'empty',
    'obscured',
    'value',
    'selectedValue',
    'min',
    'max',
    'divisions',
    'keyboardAction',
    'canScrollForward',
    'canScrollBackward',
    'axisDirection',
    'gestures',
    'dragEnabled',
    'dismissDirection',
  ]) {
    if (data.containsKey(key) &&
        data[key] != null &&
        !(key == 'value' && data['obscured'] == true)) {
      state[key] = data[key];
    }
  }
  return {
    if (data['target'] != null) 'target': data['target'],
    if (data['widgetType'] != null) 'widget': data['widgetType'],
    if (text.isNotEmpty) 'text': text.toList(),
    if (state.isNotEmpty) 'state': state,
  };
}

Map<String, Object?> compactUiScreen(Map<String, Object?> observation) {
  final widgets = <Map<String, Object?>>[];
  final seenTargets = <Object>{};
  for (final source in ['elements', 'controls']) {
    final entries = observation[source];
    if (entries is! List) continue;
    for (final entry in entries) {
      if (entry is! Map || entry['widgetType'] == null) continue;
      // Non-scrollable internal text viewports add no navigational evidence.
      if (entry['widgetType'] == 'Scrollable' &&
          entry['canScrollForward'] == false &&
          entry['canScrollBackward'] == false) {
        continue;
      }
      final target = entry['target'];
      if (target != null && !seenTargets.add(target)) continue;
      widgets.add(compactUiTarget(entry));
    }
  }
  return {
    if (observation['visibleText'] is List)
      'visibleText': observation['visibleText'],
    if (widgets.isNotEmpty) 'widgets': widgets,
  };
}
