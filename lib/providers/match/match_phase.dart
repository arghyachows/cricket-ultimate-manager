/// Phase of a cricket match — defines valid state transitions.
enum MatchPhase {
  notStarted,
  toss,
  firstInnings,
  inningsBreak,
  secondInnings,
  matchComplete,
  abandoned,
}
