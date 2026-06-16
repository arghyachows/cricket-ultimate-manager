import 'dart:math';
import '../models/models.dart';

/// Possible outcomes of a single ball.
enum BallOutcome {
  dot,
  single,
  double,
  triple,
  four,
  six,
  wicket,
  wide,
  noBall,
}

/// Calculates the outcome of a single ball based on batting/bowling ratings,
/// player traits, chemistry, pitch conditions, and match context.
BallOutcome calculateOutcome({
  required int battingRating,
  required int bowlingRating,
  required int chemistry,
  required LineupPlayer batsman,
  required LineupPlayer bowler,
  required bool isFirstInnings,
  required int currentScore,
  required int currentWickets,
  required int overNumber,
  required int ballNumber,
  required int maxOvers,
  required int target,
  required String pitchCondition,
  required Random rng,
}) {
  // Base T20 probabilities
  var probs = {
    'dot': 0.30,
    'single': 0.30,
    'double': 0.10,
    'triple': 0.02,
    'four': 0.15,
    'six': 0.08,
    'wicket': 0.05,
    'wide': 0.015,
    'no_ball': 0.015,
  };

  // ─── Step 1: Calculate matchup score ───────────────────────────────
  final matchupScore = battingRating - bowlingRating;
  final normalized = matchupScore / 100.0;

  // ─── Step 2: Adjust based on matchup ───────────────────────────────
  probs['four'] = probs['four']! + 0.1 * normalized;
  probs['six'] = probs['six']! + 0.08 * normalized;
  probs['dot'] = probs['dot']! - 0.1 * normalized;
  probs['wicket'] = probs['wicket']! - 0.05 * normalized;
  probs['single'] = probs['single']! + 0.03 * normalized;

  // ─── Step 3: Add player trait impacts ──────────────────────────────
  final batsmanCard = batsman.userCard?.playerCard;
  final bowlerCard = bowler.userCard?.playerCard;

  final aggression = (batsmanCard?.aggression ?? 50).toDouble();
  final technique = (batsmanCard?.technique ?? 50).toDouble();
  final power = (batsmanCard?.power ?? 50).toDouble();
  final consistency = (batsmanCard?.consistency ?? 50).toDouble();

  final pace = (bowlerCard?.pace ?? 50).toDouble();
  final accuracy = (bowlerCard?.accuracy ?? 50).toDouble();
  final variations = (bowlerCard?.variations ?? 50).toDouble();

  // Aggressive batsman
  probs['six'] = probs['six']! + aggression * 0.001;
  probs['wicket'] = probs['wicket']! + aggression * 0.0005;
  probs['dot'] = probs['dot']! - aggression * 0.0008;

  // Powerful batsman
  probs['six'] = probs['six']! + power * 0.0008;
  probs['four'] = probs['four']! + power * 0.0006;

  // Technical batsman
  probs['single'] = probs['single']! + technique * 0.0005;
  probs['double'] = probs['double']! + technique * 0.0003;
  probs['wicket'] = probs['wicket']! - technique * 0.0004;

  // Consistent batsman
  probs['dot'] = probs['dot']! + consistency * 0.0003;
  probs['wicket'] = probs['wicket']! - consistency * 0.0005;

  // Accurate bowler
  probs['dot'] = probs['dot']! + accuracy * 0.001;
  probs['wicket'] = probs['wicket']! + accuracy * 0.0007;
  probs['wide'] = probs['wide']! - accuracy * 0.0003;
  probs['no_ball'] = probs['no_ball']! - accuracy * 0.0002;

  // Pace bowler
  probs['wicket'] = probs['wicket']! + pace * 0.0005;
  probs['dot'] = probs['dot']! + pace * 0.0003;

  // Variations
  probs['wicket'] = probs['wicket']! + variations * 0.0003;
  probs['dot'] = probs['dot']! + variations * 0.0002;

  // ─── Step 4: Context awareness ─────────────────────────────────────
  final ballsRemaining = (maxOvers * 6) - (overNumber * 6 + ballNumber);

  // Dynamic phase boundaries based on match format
  final powerplayEnd = (maxOvers * 0.3).floor().clamp(0, 10);
  final middleOversEnd = (maxOvers * 0.8).floor();

  // Death overs (final 20% of match)
  if (overNumber >= middleOversEnd) {
    probs['six'] = probs['six']! + 0.05;
    probs['four'] = probs['four']! + 0.03;
    probs['wicket'] = probs['wicket']! + 0.03;
    probs['dot'] = probs['dot']! - 0.05;
    probs['single'] = probs['single']! - 0.02;
  }
  // Powerplay (first 30% of match)
  else if (overNumber < powerplayEnd) {
    probs['four'] = probs['four']! + 0.03;
    probs['six'] = probs['six']! + 0.02;
    probs['dot'] = probs['dot']! - 0.02;
  }
  // Middle overs (30%-80% of match)
  else {
    probs['single'] = probs['single']! + 0.05;
    probs['double'] = probs['double']! + 0.02;
    probs['dot'] = probs['dot']! + 0.02;
    probs['six'] = probs['six']! - 0.02;
  }

  // Chasing scenario
  if (!isFirstInnings && target > 0) {
    final runsNeeded = target + 1 - currentScore;
    final requiredRunRate =
        ballsRemaining > 0 ? (runsNeeded / ballsRemaining) * 6 : 0.0;

    // High required run rate
    if (requiredRunRate > 10) {
      probs['six'] = probs['six']! + 0.07;
      probs['four'] = probs['four']! + 0.04;
      probs['wicket'] = probs['wicket']! + 0.04;
      probs['dot'] = probs['dot']! - 0.08;
    } else if (requiredRunRate > 8) {
      probs['six'] = probs['six']! + 0.04;
      probs['four'] = probs['four']! + 0.03;
      probs['wicket'] = probs['wicket']! + 0.02;
      probs['dot'] = probs['dot']! - 0.04;
    }

    // Easy chase
    if (requiredRunRate < 6) {
      probs['single'] = probs['single']! + 0.05;
      probs['dot'] = probs['dot']! + 0.03;
      probs['six'] = probs['six']! - 0.03;
      probs['wicket'] = probs['wicket']! - 0.02;
    }
  }

  // Wickets in hand
  if (currentWickets >= 7) {
    // Tail-enders
    probs['wicket'] = probs['wicket']! + 0.05;
    probs['dot'] = probs['dot']! + 0.05;
    probs['six'] = probs['six']! - 0.03;
    probs['four'] = probs['four']! - 0.03;
  } else if (currentWickets <= 2) {
    // Set batsmen
    probs['wicket'] = probs['wicket']! - 0.02;
    probs['single'] = probs['single']! + 0.02;
  }

  // ─── Step 5: Pitch effects ─────────────────────────────────────────
  switch (pitchCondition) {
    case 'batting_friendly':
    case 'flat':
      probs['four'] = probs['four']! + 0.05;
      probs['six'] = probs['six']! + 0.05;
      probs['wicket'] = probs['wicket']! - 0.03;
      probs['dot'] = probs['dot']! - 0.03;
    case 'bowling_friendly':
    case 'green':
      probs['wicket'] = probs['wicket']! + 0.05;
      probs['dot'] = probs['dot']! + 0.05;
      probs['four'] = probs['four']! - 0.03;
      probs['six'] = probs['six']! - 0.03;
    case 'spin_friendly':
    case 'dusty':
      probs['wicket'] = probs['wicket']! + 0.03;
      probs['dot'] = probs['dot']! + 0.04;
      probs['six'] = probs['six']! - 0.02;
    case 'seam_friendly':
      probs['wicket'] = probs['wicket']! + 0.03;
      probs['four'] = probs['four']! - 0.02;
      probs['dot'] = probs['dot']! + 0.02;
  }

  // Chemistry bonus
  final chemMod = chemistry / 500.0;
  probs['four'] = probs['four']! + chemMod * 0.02;
  probs['six'] = probs['six']! + chemMod * 0.01;
  probs['wicket'] = probs['wicket']! - chemMod * 0.02;

  // ─── Step 6: Clamp and normalize ───────────────────────────────────
  probs['dot'] = probs['dot']!.clamp(0.05, 0.6);
  probs['single'] = probs['single']!.clamp(0.1, 0.45);
  probs['double'] = probs['double']!.clamp(0.02, 0.2);
  probs['triple'] = probs['triple']!.clamp(0.005, 0.05);
  probs['four'] = probs['four']!.clamp(0.02, 0.3);
  probs['six'] = probs['six']!.clamp(0.01, 0.2);
  probs['wicket'] = probs['wicket']!.clamp(0.01, 0.2);
  probs['wide'] = probs['wide']!.clamp(0.005, 0.05);
  probs['no_ball'] = probs['no_ball']!.clamp(0.005, 0.03);

  final total = probs.values.reduce((a, b) => a + b);
  probs.forEach((key, value) {
    probs[key] = value / total;
  });

  // ─── Step 7: Sample outcome ────────────────────────────────────────
  final roll = rng.nextDouble();
  double cumulative = 0;

  for (final entry in probs.entries) {
    cumulative += entry.value;
    if (roll < cumulative) {
      switch (entry.key) {
        case 'dot':
          return BallOutcome.dot;
        case 'single':
          return BallOutcome.single;
        case 'double':
          return BallOutcome.double;
        case 'triple':
          return BallOutcome.triple;
        case 'four':
          return BallOutcome.four;
        case 'six':
          return BallOutcome.six;
        case 'wicket':
          return BallOutcome.wicket;
        case 'wide':
          return BallOutcome.wide;
        case 'no_ball':
          return BallOutcome.noBall;
      }
    }
  }
  return BallOutcome.dot;
}
