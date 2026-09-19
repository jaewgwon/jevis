import 'dart:convert';

/// A concrete action offered to the model in the current observation.
class JevisCandidate {
  const JevisCandidate(this.id, this.description, {this.historyDescription});

  /// Reserved Choice option for a completed action instruction.
  static const stopId = '__stop__';
  final String id;
  final String description;

  /// Concise executed-action summary; avoids resending old screen snapshots.
  final String? historyDescription;
  Map<String, Object?> toJson() => {'id': id, 'description': description};
}

/// JSON-compatible UI evidence collected before making a decision.
class JevisObservation {
  JevisObservation(
      {required Map<String, Object?> state,
      required List<JevisCandidate> actions})
      : state = Map.unmodifiable(
            jsonDecode(jsonEncode(state)) as Map<String, dynamic>),
        actions = List.unmodifiable(actions);
  final Map<String, Object?> state;
  final List<JevisCandidate> actions;
  Map<String, Object?> toJson() =>
      {'state': state, 'actions': actions.map((a) => a.toJson()).toList()};
}

/// Independent goal assessment and next-action selection for one observation.
class JevisEvaluation {
  JevisEvaluation(
      {required this.goalProbability,
      this.actionId,
      this.actionConfidence = 0,
      Map<String, double> probabilities = const {},
      this.model})
      : probabilities = Map.unmodifiable(probabilities);
  final double goalProbability;
  final String? actionId;
  final double actionConfidence;
  final Map<String, double> probabilities;
  final String? model;
  Map<String, Object?> toJson() => {
        'goalProbability': goalProbability,
        'actionId': actionId,
        'actionConfidence': actionConfidence,
        'probabilities': probabilities,
        if (model != null) 'model': model,
      };
}

/// A recorded observation, assessment, and optional execution result.
class JevisTrace {
  const JevisTrace(
      {required this.observation,
      this.evaluation,
      this.executedAction,
      this.error});
  final JevisObservation observation;
  final JevisEvaluation? evaluation;
  final String? executedAction;
  final String? error;
  Map<String, Object?> toJson() => {
        'observation': observation.toJson(),
        if (evaluation != null) 'evaluation': evaluation!.toJson(),
        if (executedAction != null) 'executedAction': executedAction,
        if (error != null) 'error': error,
      };
}

class JevisRequest {
  JevisRequest(
      {required this.goal,
      required this.actionInstruction,
      required this.initialState,
      required this.observation,
      required List<JevisTrace> history,
      List<String> previousActions = const [],
      JevisTrace? previousStep,
      this.goalThreshold = .6,
      required this.remainingAttempts})
      : previousActions = List.unmodifiable(previousActions),
        history = List.unmodifiable(history),
        previousStep = previousStep ?? (history.isEmpty ? null : history.last);
  final String goal;
  final String actionInstruction;
  final Map<String, Object?> initialState;
  final JevisObservation observation;
  final List<JevisTrace> history;

  /// Every successfully executed action in this goal, in order, with duplicates.
  /// Independent of historyLimit and never used as Noul evidence.
  final List<String> previousActions;

  /// Kept independently of the bounded history, including historyLimit == 0.
  final JevisTrace? previousStep;
  JevisObservation? get previousObservation =>
      previousStep?.executedAction == null ? null : previousStep!.observation;
  JevisCandidate? get executedAction {
    final step = previousStep;
    if (step?.executedAction == null) return null;
    return step!.observation.actions
        .firstWhere((a) => a.id == step.executedAction);
  }

  final int remainingAttempts;
  final double goalThreshold;
  bool get needsAction =>
      remainingAttempts > 0 && observation.actions.isNotEmpty;
  Map<String, Object?> toJson() => {
        'goal': goal,
        'actionInstruction': actionInstruction,
        'previousActions': previousActions,
        'initialState': initialState,
        'previousObservation': previousObservation?.toJson(),
        'executedAction': executedAction?.toJson(),
        'currentObservation': observation.toJson(),
        'history': [
          for (final h in history)
            if (identical(h, previousStep) && previousObservation != null)
              h.toJson()..remove('observation')
            else
              h.toJson(),
        ],
        'remainingAttempts': remainingAttempts,
      };
}

/// Injectable for package testing; normal users use the default Jevis client.
abstract interface class JevisBrain {
  Future<JevisEvaluation> evaluate(JevisRequest request);
}

abstract interface class JevisDriver {
  Future<JevisObservation> observe();
  Future<void> execute(String actionId);
}

/// Optional driver lifecycle; exploration belongs to one goal execution.
abstract interface class JevisRunLifecycle {
  void reset();
}

/// Advanced tuning. Defaults are starting points, not accuracy guarantees.
class JevisOptions {
  const JevisOptions(
      {this.goalThreshold = .6,
      this.actionThreshold = .2,
      this.maxRepeatedAction = 2,
      this.historyLimit = 8,
      this.decisionTimeout = const Duration(seconds: 30),
      this.settleTimeout = const Duration(seconds: 5),
      this.stepDelay = Duration.zero});
  final double goalThreshold, actionThreshold;
  final int maxRepeatedAction, historyLimit;
  final Duration decisionTimeout, settleTimeout, stepDelay;
  void validate() {
    if (!_probability(goalThreshold) ||
        goalThreshold <= .5 ||
        !_probability(actionThreshold) ||
        maxRepeatedAction < 1 ||
        historyLimit < 0 ||
        decisionTimeout <= Duration.zero ||
        settleTimeout <= Duration.zero ||
        stepDelay < Duration.zero) {
      throw ArgumentError('Invalid JevisOptions');
    }
  }
}

bool _probability(double value) => value.isFinite && value >= 0 && value <= 1;

enum JevisStatus {
  succeeded,

  /// Choice finished the instruction but final goal verification failed.
  stopped,
  noActions,
  lowConfidence,
  invalidDecision,
  repeatedAction,
  attemptsExhausted,
  verificationFailed,
  error
}

class JevisReport {
  JevisReport(
      {required this.goal,
      required this.status,
      required List<JevisTrace> trace,
      this.message,
      this.completionBasis = 'model'})
      : trace = List.unmodifiable(trace);
  final String goal;
  final JevisStatus status;
  final List<JevisTrace> trace;
  final String? message;

  /// `model` denotes a probabilistic judgment, not a deterministic assertion.
  final String completionBasis;
  bool get succeeded => status == JevisStatus.succeeded;
  int get actionsExecuted =>
      trace.where((e) => e.executedAction != null).length;
  Map<String, Object?> toJson() => {
        'goal': goal,
        'status': status.name,
        'completionBasis': completionBasis,
        'actionsExecuted': actionsExecuted,
        'trace': trace.map((e) => e.toJson()).toList(),
        if (message != null) 'message': message,
      };
}

/// Every run has fresh memory; completion is checked after the final action too.
class JevisRunner {
  JevisRunner(
      {required this.driver,
      required this.brain,
      this.options = const JevisOptions()}) {
    options.validate();
  }
  final JevisDriver driver;
  final JevisBrain brain;
  final JevisOptions options;

  Future<JevisReport> run(
      String goal, String actionInstruction, int attempts) async {
    if (goal.trim().isEmpty ||
        actionInstruction.trim().isEmpty ||
        attempts < 1) {
      throw ArgumentError(
          'Provide non-empty goal and actionInstruction, and attempts >= 1');
    }
    final trace = <JevisTrace>[];
    final previousActions = <String>[];
    final visits = <String, int>{};
    var verifyingStop = false;
    Map<String, Object?>? initial;
    JevisReport finish(JevisStatus status, [String? message]) =>
        JevisReport(goal: goal, status: status, trace: trace, message: message);
    try {
      if (driver is JevisRunLifecycle) (driver as JevisRunLifecycle).reset();
      for (var executed = 0; executed <= attempts;) {
        final observation = await driver.observe();
        initial ??= observation.state;
        final ids = observation.actions.map((a) => a.id).toSet();
        if (ids.length != observation.actions.length ||
            ids.contains('') ||
            ids.contains(JevisCandidate.stopId) ||
            ids.length > 254) {
          return finish(JevisStatus.error,
              'Expected at most 254 unique, non-reserved action IDs');
        }
        JevisEvaluation evaluation;
        try {
          evaluation = await brain
              .evaluate(JevisRequest(
                  goal: goal,
                  actionInstruction: actionInstruction,
                  previousActions: previousActions,
                  goalThreshold: options.goalThreshold,
                  initialState: initial,
                  observation: observation,
                  previousStep: trace.isEmpty ? null : trace.last,
                  history: trace
                      .skip(trace.length > options.historyLimit
                          ? trace.length - options.historyLimit
                          : 0)
                      .toList(),
                  remainingAttempts: verifyingStop ? 0 : attempts - executed))
              .timeout(options.decisionTimeout);
        } catch (e) {
          trace.add(JevisTrace(observation: observation, error: e.toString()));
          return finish(JevisStatus.error, e.toString());
        }
        trace.add(JevisTrace(observation: observation, evaluation: evaluation));
        if (!_probability(evaluation.goalProbability)) {
          return finish(JevisStatus.invalidDecision);
        }
        if (evaluation.goalProbability >= options.goalThreshold) {
          return finish(JevisStatus.succeeded);
        }
        if (verifyingStop) {
          return finish(JevisStatus.stopped,
              'Choice considers the action instruction complete, but final Noul verification has not confirmed the goal.');
        }
        if (executed == attempts) return finish(JevisStatus.attemptsExhausted);
        if (ids.isEmpty) return finish(JevisStatus.noActions);
        final selected = evaluation.actionId;
        if (!_probability(evaluation.actionConfidence) ||
            (selected != JevisCandidate.stopId && !ids.contains(selected))) {
          return finish(JevisStatus.invalidDecision);
        }
        if (evaluation.actionConfidence < options.actionThreshold) {
          return finish(JevisStatus.lowConfidence);
        }
        if (selected == JevisCandidate.stopId) {
          verifyingStop = true;
          continue;
        }
        final fingerprint = jsonEncode([
          {...observation.state}..remove('changes'),
          observation.actions.map((a) => a.toJson()).toList(),
          selected
        ]);
        final count = visits[fingerprint] ?? 0;
        if (count >= options.maxRepeatedAction) {
          return finish(JevisStatus.repeatedAction);
        }
        visits[fingerprint] = count + 1;
        try {
          final candidate =
              observation.actions.firstWhere((a) => a.id == selected);
          await driver.execute(selected!);
          executed++;
          previousActions
              .add(candidate.historyDescription ?? candidate.description);
          trace[trace.length - 1] = JevisTrace(
              observation: observation,
              evaluation: evaluation,
              executedAction: selected);
        } catch (e) {
          trace[trace.length - 1] = JevisTrace(
              observation: observation,
              evaluation: evaluation,
              error: e.toString());
          return finish(JevisStatus.error, e.toString());
        }
      }
    } catch (e) {
      return finish(JevisStatus.error, e.toString());
    }
    return finish(JevisStatus.attemptsExhausted);
  }
}
