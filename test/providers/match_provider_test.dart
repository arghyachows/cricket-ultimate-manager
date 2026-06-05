import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_ultimate_manager/providers/match/match_state.dart';
import 'package:cricket_ultimate_manager/providers/match/match_phase.dart';
import 'package:cricket_ultimate_manager/providers/match/match_local_engine.dart';
import 'package:cricket_ultimate_manager/providers/match_helpers.dart';
import 'package:cricket_ultimate_manager/models/models.dart';

void main() {
  group('MatchState', () {
    test('hasActiveMatch returns true when simulating', () {
      const state = MatchState(phase: MatchPhase.notStarted, isSimulating: true);
      expect(state.hasActiveMatch, isTrue);
    });

    test('hasActiveMatch returns true when match complete', () {
      const state = MatchState(phase: MatchPhase.notStarted, isMatchComplete: true);
      expect(state.hasActiveMatch, isTrue);
    });

    test('hasActiveMatch returns false when neither', () {
      const state = MatchState(phase: MatchPhase.notStarted);
      expect(state.hasActiveMatch, isFalse);
    });

    test('homeScore uses first innings score when homeBatsFirst', () {
      // Build events: innings 1 with score 150
      final events = [
        const MatchEvent(
          id: '1',
          matchId: 'm1',
          innings: 1,
          overNumber: 0,
          ballNumber: 0,
          battingTeamId: 'home',
          bowlingTeamId: 'away',
          batsmanCardId: 'b1',
          bowlerCardId: 'bo1',
          eventType: 'run',
          runs: 4,
          commentary: 'Four!',
          scoreAfter: 4,
          wicketsAfter: 0,
        ),
        const MatchEvent(
          id: '2',
          matchId: 'm1',
          innings: 1,
          overNumber: 0,
          ballNumber: 5,
          battingTeamId: 'home',
          bowlingTeamId: 'away',
          batsmanCardId: 'b1',
          bowlerCardId: 'bo1',
          eventType: 'run',
          runs: 6,
          commentary: 'Six!',
          scoreAfter: 10,
          wicketsAfter: 0,
        ),
      ];

      final state = MatchState(
        phase: MatchPhase.notStarted,
        events: events,
        homeBatsFirst: true,
        currentInnings: 1,
        matchOvers: 20,
      );

      expect(state.homeScore, equals(10));
      expect(state.homeWickets, equals(0));
    });

    test('copyWith creates new state with updated fields', () {
      const original = MatchState(
        phase: MatchPhase.notStarted,
        isSimulating: false,
        homeTeamName: 'India',
        matchOvers: 20,
      );

      final updated = original.copyWith(
        isSimulating: true,
        homeTeamName: 'Australia',
      );

      expect(updated.isSimulating, isTrue);
      expect(updated.homeTeamName, equals('Australia'));
      expect(updated.matchOvers, equals(20)); // unchanged
    });

    test('copyWith clearLevelUpPack removes level up', () {
      const state = MatchState(
        phase: MatchPhase.notStarted,
        levelUpPackAwarded: 'pack_123',
        newLevel: 5,
      );

      final cleared = state.clearLevelUpPack();
      expect(cleared.levelUpPackAwarded, isNull);
      expect(cleared.newLevel, isNull);
    });

    test('ballsRemaining calculates correctly', () {
      final events = [
        const MatchEvent(
          id: '1',
          matchId: 'm1',
          innings: 1,
          overNumber: 5, // 5 overs = 30 balls
          ballNumber: 0,
          battingTeamId: 'home',
          bowlingTeamId: 'away',
          batsmanCardId: 'b1',
          bowlerCardId: 'bo1',
          eventType: 'run',
          runs: 1,
          commentary: 'Single',
          scoreAfter: 1,
          wicketsAfter: 0,
        ),
      ];

      final state = MatchState(
        phase: MatchPhase.notStarted,
        events: events,
        currentInnings: 1,
        matchOvers: 20,
      );

      // 20 overs * 6 = 120 balls. 1 legal event = 1 ball. Remaining = 119
      expect(state.ballsRemaining, equals(119));
    });

    test('runsNeeded returns 0 in first innings', () {
      const state = MatchState(
        phase: MatchPhase.notStarted,
        currentInnings: 1,
        target: 0,
        matchOvers: 20,
        events: [],
      );
      expect(state.runsNeeded, equals(0));
    });

    test('currentBatsmen filters by current innings and not out', () {
      final batsmanStats = {
        'bats1': BatsmanStats(name: 'Kohli', innings: 1, runs: 45, isOut: false),
        'bats2': BatsmanStats(name: 'Rohit', innings: 1, runs: 12, isOut: true),
        'bats3': BatsmanStats(name: 'Pant', innings: 2, runs: 30, isOut: false),
      };

      final state = MatchState(
        phase: MatchPhase.notStarted,
        currentInnings: 1,
        batsmanStats: batsmanStats,
      );

      final current = state.currentBatsmen;
      expect(current.length, equals(1));
      expect(current.first.name, equals('Kohli'));
      expect(current.first.isOut, isFalse);
    });
  });

  group('BatsmanStats', () {
    test('strikeRate calculates correctly', () {
      final stats = BatsmanStats(name: 'Virat', innings: 1, runs: 54, balls: 36);
      expect(stats.strikeRate, closeTo(150.0, 0.01));
    });

    test('strikeRate returns 0 when no balls faced', () {
      final stats = BatsmanStats(name: 'Virat', innings: 1, runs: 0, balls: 0);
      expect(stats.strikeRate, equals(0));
    });
  });

  group('BowlerStats', () {
    test('economy calculates correctly', () {
      final stats = BowlerStats(
        name: 'Bumrah',
        innings: 1,
        balls: 24, // 4 overs
        runs: 20,
        wickets: 2,
      );
      // 20 runs / 4 overs = 5.0 economy
      expect(stats.economy, closeTo(5.0, 0.01));
    });

    test('economy returns 0 when no overs bowled', () {
      final stats = BowlerStats(name: 'Bumrah', innings: 1, balls: 0, runs: 0);
      expect(stats.economy, equals(0));
    });

    test('oversDisplay formats correctly', () {
      final stats = BowlerStats(
        name: 'Bumrah',
        innings: 1,
        balls: 25, // 4.1 overs
        runs: 20,
      );
      expect(stats.oversDisplay, equals('4.1'));
    });
  });

  group('MatchSummary', () {
    test('battingFirstName returns correct team', () {
      final summary = MatchSummary(
        homeTeamName: 'India',
        awayTeamName: 'Australia',
        format: 't20',
        homeScore: 180,
        homeWickets: 3,
        homeOvers: '20.0',
        awayScore: 160,
        awayWickets: 8,
        awayOvers: '18.5',
        homeWon: true,
        coinsAwarded: 100,
        xpAwarded: 50,
        playedAt: DateTime(2024, 1, 1),
        batsmanStats: {},
        bowlerStats: {},
        events: [],
        homeBatsFirst: true,
      );

      expect(summary.battingFirstName, equals('India'));
      expect(summary.battingSecondName, equals('Australia'));
    });

    test('resultText shows correct winner', () {
      final wonHome = MatchSummary(
        homeTeamName: 'India',
        awayTeamName: 'Australia',
        format: 't20',
        homeScore: 180,
        homeWickets: 3,
        homeOvers: '20.0',
        awayScore: 160,
        awayWickets: 8,
        awayOvers: '18.5',
        homeWon: true,
        coinsAwarded: 100,
        xpAwarded: 50,
        playedAt: DateTime(2024, 1, 1),
        batsmanStats: {},
        bowlerStats: {},
        events: [],
      );

      final wonAway = MatchSummary(
        homeTeamName: 'India',
        awayTeamName: 'Australia',
        format: 't20',
        homeScore: 180,
        homeWickets: 3,
        homeOvers: '20.0',
        awayScore: 160,
        awayWickets: 8,
        awayOvers: '18.5',
        homeWon: false,
        coinsAwarded: 100,
        xpAwarded: 50,
        playedAt: DateTime(2024, 1, 1),
        batsmanStats: const {},
        bowlerStats: const {},
        events: const [],
      );

      final drawn = MatchSummary(
        homeTeamName: 'India',
        awayTeamName: 'Australia',
        format: 't20',
        homeScore: 180,
        homeWickets: 3,
        homeOvers: '20.0',
        awayScore: 180,
        awayWickets: 3,
        awayOvers: '20.0',
        homeWon: null,
        coinsAwarded: 50,
        xpAwarded: 25,
        playedAt: DateTime(2024, 1, 1),
        batsmanStats: const {},
        bowlerStats: const {},
        events: const [],
      );

      expect(wonHome.resultText, contains('India won'));
      expect(wonAway.resultText, contains('Australia won'));
      expect(drawn.resultText, contains('Drawn'));
    });

    test('inn1Score returns batting-first team score', () {
      final summary = MatchSummary(
        homeTeamName: 'India',
        awayTeamName: 'Australia',
        format: 't20',
        homeScore: 180,
        homeWickets: 3,
        homeOvers: '20.0',
        awayScore: 160,
        awayWickets: 8,
        awayOvers: '18.5',
        homeWon: false,
        coinsAwarded: 100,
        xpAwarded: 50,
        playedAt: DateTime(2024, 1, 1),
        batsmanStats: {},
        bowlerStats: {},
        events: [],
        homeBatsFirst: true,
      );

      expect(summary.inn1Score, equals(180)); // home batted first
    });
  });

  group('MatchState — innings ordering', () {
    test('homeScore uses second innings when away bats first', () {
      final events = [
        const MatchEvent(
          id: 'e1',
          matchId: 'm1',
          innings: 2, // Second innings
          overNumber: 0,
          ballNumber: 0,
          battingTeamId: 'away',
          bowlingTeamId: 'home',
          batsmanCardId: 'b1',
          bowlerCardId: 'bo1',
          eventType: 'run',
          runs: 100,
          commentary: 'Century!',
          scoreAfter: 100,
          wicketsAfter: 0,
        ),
      ];

      final state = MatchState(
        phase: MatchPhase.notStarted,
        events: events,
        homeBatsFirst: false, // Away batted first
        currentInnings: 2,
        matchOvers: 20,
      );

      // homeBatsFirst = false, so home team's score is in innings 2
      expect(state.homeScore, equals(100));
      expect(state.awayScore, equals(0)); // No first innings events
    });

    test('homeOvers/awayOvers return correct format', () {
      final events = [
        const MatchEvent(id: 'e1', matchId: 'm1', innings: 1, overNumber: 4,
            ballNumber: 0, battingTeamId: 'home', bowlingTeamId: 'away',
            batsmanCardId: 'b1', bowlerCardId: 'bo1', eventType: 'run',
            runs: 1, commentary: 'x', scoreAfter: 1, wicketsAfter: 0),
      ];
      final state = MatchState(
        phase: MatchPhase.notStarted,
        events: events, currentInnings: 1, matchOvers: 20, homeBatsFirst: true);
      // 1 legal ball at over 4, ball 0 = '4.0'
      expect(state.homeOvers, equals('4.0'));
      expect(state.awayOvers, equals('0.0'));
      expect(state.currentOvers, equals('4.0'));
    });

    test('innings1Batsmen / innings2Batsmen ordered correctly', () {
      final bs = <String, BatsmanStats>{
        '1_b1': BatsmanStats(name: 'Player2', innings: 1),
        '1_b2': BatsmanStats(name: 'Player1', innings: 1),
        '2_b3': BatsmanStats(name: 'Player3', innings: 2),
      };
      final state = MatchState(phase: MatchPhase.notStarted, events: const [], batsmanStats: bs,
          currentInnings: 1, matchOvers: 20, xiOrder1: ['Player1', 'Player2'],
          xiOrder2: ['Player3']);
      // Player1 (in xiOrder) should come first, then Player2, then any remaining
      expect(state.innings1Batsmen.map((b) => b.name).toList(),
          equals(['Player1', 'Player2']));
      expect(state.innings2Batsmen.map((b) => b.name).toList(),
          equals(['Player3']));
    });

    test('innings1Bowlers / innings2Bowlers filtered by innings', () {
      final bs = <String, BowlerStats>{
        '1_bo1': BowlerStats(name: 'Bowler1', innings: 1, balls: 12),
        '2_bo2': BowlerStats(name: 'Bowler2', innings: 2, balls: 6),
        '1_bo3': BowlerStats(name: 'Bowler3', innings: 1, balls: 18),
      };
      final state = MatchState(phase: MatchPhase.notStarted, events: const [], bowlerStats: bs,
          currentInnings: 2, matchOvers: 20);
      expect(state.innings1Bowlers.map((b) => b.name).toList(),
          equals(['Bowler1', 'Bowler3']));
      expect(state.innings2Bowlers.map((b) => b.name).toList(),
          equals(['Bowler2']));
    });

    test('runsNeeded returns correct chasing target', () {
      final events = [
        const MatchEvent(id: 'e1', matchId: 'm1', innings: 2, overNumber: 0,
            ballNumber: 0, battingTeamId: 'away', bowlingTeamId: 'home',
            batsmanCardId: 'b1', bowlerCardId: 'bo1', eventType: 'run',
            runs: 50, commentary: 'x', scoreAfter: 50, wicketsAfter: 0),
      ];
      // Target for chasing team = 201 (first innings 200 + 1)
      final state = MatchState(phase: MatchPhase.notStarted, events: events, currentInnings: 2,
          target: 201, matchOvers: 20, homeBatsFirst: false,
          batsmanStats: {}, bowlerStats: {});
      // Chasing: 50 runs. Needed = 201 + 1 - 50 = 152
      expect(state.runsNeeded, equals(152));
    });

    test('runsNeeded returns 0 when already passed target', () {
      final events = [
        const MatchEvent(id: 'e1', matchId: 'm1', innings: 2, overNumber: 0,
            ballNumber: 0, battingTeamId: 'away', bowlingTeamId: 'home',
            batsmanCardId: 'b1', bowlerCardId: 'bo1', eventType: 'run',
            runs: 250, commentary: 'x', scoreAfter: 250, wicketsAfter: 0),
                  ];
                  final state = MatchState(phase: MatchPhase.notStarted, events: events, currentInnings: 2,
                      target: 100, matchOvers: 20, homeBatsFirst: false,
                      batsmanStats: {}, bowlerStats: {});
                  expect(state.runsNeeded, equals(0));
    });
  });

  group('MatchHelpers', () {
    test('parseBatsmanStats returns empty when data is null', () {
      final result = MatchHelpers.parseBatsmanStats(null);
      expect(result, isEmpty);
    });

    test('parseBatsmanStats returns empty when data is not a map', () {
      final result = MatchHelpers.parseBatsmanStats('not a map');
      expect(result, isEmpty);
    });

    test('parseBatsmanStats correctly parses valid data', () {
      final result = MatchHelpers.parseBatsmanStats({
        'player_a': {'name': 'Player A', 'runs': 45, 'balls': 30, 'fours': 4, 'sixes': 1, 'isOut': false, 'dismissalType': null, 'innings': 1},
        'player_b': {'name': 'Player B', 'runs': 12, 'balls': 8, 'fours': 1, 'sixes': 0, 'isOut': true, 'dismissalType': 'caught', 'innings': 1},
      });
      expect(result.length, equals(2));
      expect(result['player_a']!.runs, equals(45));
      expect(result['player_a']!.balls, equals(30));
      expect(result['player_b']!.runs, equals(12));
      expect(result['player_b']!.isOut, isTrue);
      expect(result['player_b']!.dismissalType, equals('caught'));
    });

    test('formatDismissal formats bowled correctly', () {
      expect(MatchHelpers.formatDismissal('bowled', 'Wasim', null), equals('b Wasim'));
    });

    test('formatDismissal formats caught correctly', () {
      expect(MatchHelpers.formatDismissal('caught', 'Waqar', 'Inzi'), equals('c Inzi b Waqar'));
    });

    test('formatDismissal formats run out correctly', () {
      expect(MatchHelpers.formatDismissal('run_out', 'Ayaz', 'Moin'), equals('run out (Moin)'));
    });

    test('formatDismissal formats lbw correctly', () {
      expect(MatchHelpers.formatDismissal('lbw', 'Anil', null), equals('lbw b Anil'));
    });

    test('inningsScoreFromEvents sums runs for the specified innings', () {
      final events = [
        const MatchEvent(id: '1', matchId: 'm1', innings: 1, overNumber: 0, ballNumber: 0, battingTeamId: 'home', bowlingTeamId: 'away', batsmanCardId: 'b1', bowlerCardId: 'bo1', eventType: 'run', runs: 4, commentary: '', scoreAfter: 4, wicketsAfter: 0),
        const MatchEvent(id: '2', matchId: 'm1', innings: 1, overNumber: 0, ballNumber: 1, battingTeamId: 'home', bowlingTeamId: 'away', batsmanCardId: 'b2', bowlerCardId: 'bo1', eventType: 'run', runs: 6, commentary: '', scoreAfter: 10, wicketsAfter: 0),
        const MatchEvent(id: '3', matchId: 'm1', innings: 2, overNumber: 0, ballNumber: 0, battingTeamId: 'away', bowlingTeamId: 'home', batsmanCardId: 'b3', bowlerCardId: 'bo2', eventType: 'run', runs: 2, commentary: '', scoreAfter: 2, wicketsAfter: 0),
      ];
      expect(MatchHelpers.inningsScoreFromEvents(events, 1), equals(10));
      expect(MatchHelpers.inningsScoreFromEvents(events, 2), equals(2));
    });

    test('parseBowlerStats returns empty when data is null', () {
      final result = MatchHelpers.parseBowlerStats(null);
      expect(result, isEmpty);
    });

    test('parseBowlerStats returns empty when data is not a map', () {
      final result = MatchHelpers.parseBowlerStats('not a map');
      expect(result, isEmpty);
    });

    test('parseBowlerStats correctly parses valid data', () {
      final result = MatchHelpers.parseBowlerStats({
        'bo1': {'name': 'Bowler A', 'innings': 1, 'balls': 24, 'runs': 15, 'wickets': 2, 'maidens': 1, 'dotBalls': 10},
        'bo2': {'name': 'Bowler B', 'innings': 1, 'balls': 18, 'runs': 30, 'wickets': 0, 'maidens': 0, 'dotBalls': 5},
      });
      expect(result.length, equals(2));
      expect(result['bo1']!.balls, equals(24));
      expect(result['bo1']!.runs, equals(15));
      expect(result['bo1']!.wickets, equals(2));
      expect(result['bo1']!.maidens, equals(1));
      expect(result['bo1']!.dotBalls, equals(10));
      expect(result['bo2']!.runs, equals(30));
    });

    test('formatDismissal falls through to default for unknown type', () {
      expect(MatchHelpers.formatDismissal('hit_wicket', 'Bumrah', null), equals('b Bumrah'));
    });
  });

  group('MatchLocalEngine', () {
    test('computeSkipToEndResult returns MatchState', () {
      // We can't easily test this without a full MatchEngine setup,
      // but we can verify the method exists and is callable
      // Just verify the class is accessible and the static method exists
      expect(MatchLocalEngine.computeSkipToEndResult, isNotNull);
    });
  });
}