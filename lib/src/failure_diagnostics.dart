import 'dart:convert';

import 'core.dart';

String formatFailureDiagnostics(JevisReport report, {bool? useColors}) {
  final colors = useColors ??
      const bool.fromEnvironment('JEVIS_LOG_COLORS', defaultValue: true);
  String percent(double value) {
    final text = '${(value * 100).toStringAsFixed(2)}%';
    if (!colors || !value.isFinite) return text;
    final color = value <= .2 ? 31 : (value < .6 ? 33 : 32);
    return '\x1B[${color}m$text\x1B[0m';
  }

  final lines = ['Jevis goal not reached: ${report.status.name}'];
  if (report.message != null) lines.add(report.message!);
  for (var i = 0; i < report.trace.length; i++) {
    final step = report.trace[i];
    final evaluation = step.evaluation;
    lines.add('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    lines.add('🧭 Step ${i + 1}:');
    if (evaluation != null) {
      lines.add('  Goal probability: ${percent(evaluation.goalProbability)}');
      if (evaluation.actionId != null || evaluation.probabilities.isNotEmpty) {
        lines.add('  Confidence: ${percent(evaluation.actionConfidence)}');
        lines.add('  Selected action: ${evaluation.actionId ?? 'unavailable'}');
        final descriptions = {
          for (final action in step.observation.actions)
            action.id: _summarize(action.description),
          JevisCandidate.stopId: 'Stop taking actions',
        };
        final choices = evaluation.probabilities.entries.toList()
          ..sort((a, b) {
            final probability = b.value.compareTo(a.value);
            return probability != 0 ? probability : a.key.compareTo(b.key);
          });
        if (choices.isNotEmpty) {
          final idWidth = choices.fold<int>(
              'Action ID'.length,
              (width, entry) =>
                  entry.key.length > width ? entry.key.length : width);
          lines.add('');
          lines.add(
              '  Pick | Probability | ${'Action ID'.padRight(idWidth)} | Action');
          lines.add(
              '  -----+-------------+-${'-' * idWidth}-+--------------------');
          for (final entry in choices) {
            final selected = entry.key == evaluation.actionId ? '▶' : '';
            final plain = '${(entry.value * 100).toStringAsFixed(2)}%';
            final padding = plain.length < 11 ? ' ' * (11 - plain.length) : '';
            lines.add(
                '  ${selected.padRight(4)} | $padding${percent(entry.value)} | '
                '${entry.key.padRight(idWidth)} | ${descriptions[entry.key] ?? 'Unknown action'}');
          }
        }
      }
    }
    if (step.error != null) lines.add('  Error: ${step.error}');
  }
  return lines.join('\n');
}

String _summarize(String description) {
  final start = description.indexOf('{');
  final end = description.lastIndexOf('}');
  var result = description;
  if (start >= 0 && end > start) {
    try {
      final data = jsonDecode(description.substring(start, end + 1));
      if (data is Map) {
        final labels = data['text'];
        final text =
            labels is List ? labels.whereType<String>().join(' / ') : '';
        final widget = data['widget']?.toString() ?? 'Control';
        final target = data['target'];
        final label = text.isNotEmpty
            ? '$text [$widget]'
            : '$widget${target == null ? '' : ' ($target)'}';
        result =
            '${description.substring(0, start)}$label${description.substring(end + 1)}';
      }
    } on FormatException {
      // Custom descriptions need not contain valid JSON.
    }
  }
  return result.replaceAll(RegExp(r'[\s\x00-\x1f\x7f]+'), ' ').trim();
}
