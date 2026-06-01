/// State machine for match lifecycle management.
/// Defines valid state transitions and enforces match flow rules.

enum MatchPhase {
  notStarted,
  toss,
  firstInnings,
  inningsBreak,
  secondInnings,
  matchComplete,
  abandoned,
}

class MatchStateMachine {
  MatchPhase _currentPhase = MatchPhase.notStarted;

  MatchPhase get currentPhase => _currentPhase;

  /// Transition to a new phase. Returns false if transition is invalid.
  bool transitionTo(MatchPhase newPhase) {
    final valid = _isValidTransition(_currentPhase, newPhase);
    if (valid) {
      _currentPhase = newPhase;
    }
    return valid;
  }

  bool _isValidTransition(MatchPhase from, MatchPhase to) {
    const transitions = {
      MatchPhase.notStarted: [MatchPhase.toss],
      MatchPhase.toss: [MatchPhase.firstInnings, MatchPhase.abandoned],
      MatchPhase.firstInnings: [MatchPhase.inningsBreak, MatchPhase.abandoned],
      MatchPhase.inningsBreak: [MatchPhase.secondInnings, MatchPhase.abandoned],
      MatchPhase.secondInnings: [MatchPhase.matchComplete, MatchPhase.abandoned],
      MatchPhase.matchComplete: [],
      MatchPhase.abandoned: [],
    };
    return transitions[from]?.contains(to) ?? false;
  }

  void reset() {
    _currentPhase = MatchPhase.notStarted;
  }
}
