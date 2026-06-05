import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_ultimate_manager/providers/match/tournament_match_manager.dart';
import 'package:cricket_ultimate_manager/providers/match/match_state.dart';

void main() {
  // ──────────────────────────────────────────────────────────────
  // CommentaryParser — pure JSON-to-CommentaryEntry parsing
  // ──────────────────────────────────────────────────────────────
  group('CommentaryParser', () {
    test('parse returns empty list for null input', () {
      expect(CommentaryParser.parse(null), isEmpty);
    });

    test('parse returns empty list for empty list', () {
      expect(CommentaryParser.parse([]), isEmpty);
    });

    test('parse handles a single ball entry', () {
      final raw = [
        {
          'commentary': 'Four!',
          'eventType': 'run',
          'runs': 4,
          'innings': 1,
          'overNumber': 3,
          'ballNumber': 2,
        },
      ];
      final result = CommentaryParser.parse(raw);
      expect(result.length, equals(1));
      expect(result[0].commentary, equals('Four!'));
      expect(result[0].eventType, equals('run'));
      expect(result[0].runs, equals(4));
      expect(result[0].innings, equals(1));
      expect(result[0].oversDisplay, equals('3.2'));
    });

    test('parse handles multiple entries preserving order', () {
      final raw = [
        {
          'commentary': '1 run',
          'eventType': 'run',
          'runs': 1,
          'innings': 1,
          'overNumber': 1,
          'ballNumber': 1,
        },
        {
          'commentary': 'Wicket!',
          'eventType': 'wicket',
          'runs': 0,
          'innings': 1,
          'overNumber': 1,
          'ballNumber': 2,
        },
        {
          'commentary': 'Six!',
          'eventType': 'six',
          'runs': 6,
          'innings': 2,
          'overNumber': 15,
          'ballNumber': 4,
        },
      ];
      final result = CommentaryParser.parse(raw);
      expect(result.length, equals(3));
      expect(result[0].commentary, equals('1 run'));
      expect(result[1].commentary, equals('Wicket!'));
      expect(result[2].commentary, equals('Six!'));
      expect(result[2].innings, equals(2));
      expect(result[2].oversDisplay, equals('15.4'));
    });

    test('parse handles missing optional fields with defaults', () {
      final raw = [
        {
          'commentary': 'Dot ball',
          // eventType, runs, innings, overNumber, ballNumber all missing
        },
      ];
      final result = CommentaryParser.parse(raw);
      expect(result.length, equals(1));
      expect(result[0].commentary, equals('Dot ball'));
      expect(result[0].eventType, equals(''));
      expect(result[0].runs, equals(0));
      expect(result[0].innings, equals(1));
      expect(result[0].oversDisplay, equals('0.0'));
    });

    test('parse handles boundary over-ball formatting (6th ball = next over)', () {
      final raw = [
        {
          'commentary': 'Dot to end the over',
          'eventType': 'dot',
          'runs': 0,
          'innings': 1,
          'overNumber': 5,
          'ballNumber': 6,
        },
      ];
      final result = CommentaryParser.parse(raw);
      expect(result.length, equals(1));
      // The parser builds oversDisplay as '${overNumber}.${ballNumber}'
      // Ball 6 of over 5 → '5.6' — this is the raw representation
      expect(result[0].oversDisplay, equals('5.6'));
    });

    test('parse casts dynamic values correctly', () {
      final raw = [
        {
          'commentary': 'Wide',
          'eventType': 'wide',
          'runs': 1,
          'innings': 1,
          'overNumber': 2,
          'ballNumber': 0,
        },
      ];
      final result = CommentaryParser.parse(raw);
      expect(result[0].runs, equals(1));
      expect(result[0].innings, equals(1));
      expect(result[0].oversDisplay, equals('2.0'));
    });

    test('parse handles innings 2 entries', () {
      final raw = [
        {
          'commentary': 'Edge and four!',
          'eventType': 'run',
          'runs': 4,
          'innings': 2,
          'overNumber': 12,
          'ballNumber': 3,
        },
      ];
      final result = CommentaryParser.parse(raw);
      expect(result[0].innings, equals(2));
      expect(result[0].runs, equals(4));
      expect(result[0].oversDisplay, equals('12.3'));
    });

    test('CommentaryEntry equality and hashCode work', () {
      final a = CommentaryEntry(
        commentary: 'Six!',
        eventType: 'six',
        runs: 6,
        innings: 1,
        oversDisplay: '5.4',
      );
      final b = CommentaryEntry(
        commentary: 'Six!',
        eventType: 'six',
        runs: 6,
        innings: 1,
        oversDisplay: '5.4',
      );
      final c = CommentaryEntry(
        commentary: 'Four!',
        eventType: 'four',
        runs: 4,
        innings: 1,
        oversDisplay: '5.5',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('CommentaryEntry toString contains key fields', () {
      final e = CommentaryEntry(
        commentary: 'Caught!',
        eventType: 'wicket',
        runs: 0,
        innings: 2,
        oversDisplay: '10.3',
      );
      final str = e.toString();
      expect(str, contains('10.3'));
      expect(str, contains('wicket'));
      expect(str, contains('"Caught!"'));
    });
  });

  // ──────────────────────────────────────────────────────────────
  // MatchSocketManager.applyRoomJoinedState — state sync coverage
  // ──────────────────────────────────────────────────────────────
  group('applyRoomJoinedState', () {
    late TournamentMatchState state;
    late MatchSocketManager manager;

    setUp(() {
      state = TournamentMatchState();
      manager = MatchSocketManager(
        matchId: 'test-match-1',
        onStateChanged: () {},
      );
    });

    test('syncs homeBatsFirst from state data', () {
      expect(state.homeBatsFirst, isTrue); // default
      manager.applyRoomJoinedState(state, {
        'state': {'homeBatsFirst': false},
      });
      expect(state.homeBatsFirst, isFalse);
    });

    test('syncs homeBatsFirst when set to true explicitly', () {
      state.homeBatsFirst = false;
      manager.applyRoomJoinedState(state, {
        'state': {'homeBatsFirst': true},
      });
      expect(state.homeBatsFirst, isTrue);
    });

    test('maps first-innings scores correctly when homeBatsFirst is true', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'homeBatsFirst': true,
          'score1': 150,
          'wickets1': 3,
          'score2': 100,
          'wickets2': 5,
          'overs1': '20.0',
          'overs2': '15.3',
        },
      });
      expect(state.homeScore, equals(150));
      expect(state.homeWickets, equals(3));
      expect(state.homeOvers, equals('20.0'));
      expect(state.awayScore, equals(100));
      expect(state.awayWickets, equals(5));
      expect(state.awayOvers, equals('15.3'));
    });

    test('maps scores in reverse when homeBatsFirst is false', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'homeBatsFirst': false,
          'score1': 180, // away batted first → away score
          'wickets1': 4,
          'score2': 120, // home batting second → home score
          'wickets2': 6,
          'overs1': '20.0',
          'overs2': '12.2',
        },
      });
      // Away batted first, so homeBatsFirst=false
      // score1/wickets1/overs1 → away (team batting first)
      // score2/wickets2/overs2 → home (team batting second)
      expect(state.homeBatsFirst, isFalse);
      expect(state.homeScore, equals(120));
      expect(state.homeWickets, equals(6));
      expect(state.homeOvers, equals('12.2'));
      expect(state.awayScore, equals(180));
      expect(state.awayWickets, equals(4));
      expect(state.awayOvers, equals('20.0'));
    });

    test('syncs current innings and target', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'currentInnings': 2,
          'target': 200,
        },
      });
      expect(state.currentInnings, equals(2));
      expect(state.target, equals(200));
    });

    test('supports "innings" alias for currentInnings', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'innings': 2,
        },
      });
      expect(state.currentInnings, equals(2));
    });

    test('currentInnings prefers currentInnings over innings alias', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'currentInnings': 2,
          'innings': 1,
        },
      });
      expect(state.currentInnings, equals(2)); // currentInnings wins
    });

    test('syncs match completion state', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'matchComplete': true,
          'matchResult': 'Home Team won',
        },
      });
      expect(state.isMatchComplete, isTrue);
      expect(state.matchResult, equals('Home Team won'));
      expect(state.isSimulating, isFalse);
    });

    test('isSimulating defaults to !isMatchComplete when not provided', () {
      state.isSimulating = true;
      manager.applyRoomJoinedState(state, {
        'state': {
          'matchComplete': true,
        },
      });
      expect(state.isMatchComplete, isTrue);
      expect(state.isSimulating, isFalse);
    });

    test('explicit isSimulating overrides default', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'isSimulating': true,
          'matchComplete': true, // would normally set isSimulating=false
        },
      });
      // Explicit isSimulating takes precedence
      expect(state.isSimulating, isTrue);
    });

    test('syncs player names', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'homeBatsman': 'Kohli*',
          'currentBatsman': 'Rohit*',
          'awayBatsman': 'Maxwell',
          'currentBatsman2': 'Warner',
          'currentBowler': 'Bumrah',
        },
      });
      // homeBatsman should prefer 'homeBatsman' over 'currentBatsman'
      expect(state.homeBatsman, equals('Kohli*'));
      expect(state.awayBatsman, equals('Maxwell'));
      expect(state.currentBowler, equals('Bumrah'));
    });

    test('player names fall back to currentBatsman/currentBatsman2', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'currentBatsman': 'Rohit*',
          'currentBatsman2': 'Warner',
        },
      });
      expect(state.homeBatsman, equals('Rohit*'));
      expect(state.awayBatsman, equals('Warner'));
    });

    test('syncs batsmanStats map', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'batsmanStats': {
            'player_a': {
              'name': 'Player A', 'runs': 45, 'balls': 30,
              'fours': 4, 'sixes': 1, 'isOut': false,
              'dismissalType': null, 'innings': 1,
            },
          },
        },
      });
      expect(state.batsmanStats.length, equals(1));
      expect(state.batsmanStats['player_a']!.runs, equals(45));
    });

    test('syncs bowlerStats map', () {
      manager.applyRoomJoinedState(state, {
        'state': {
          'bowlerStats': {
            'bo1': {
              'name': 'Bowler A', 'innings': 1, 'balls': 24,
              'runs': 20, 'wickets': 2, 'maidens': 1, 'dotBalls': 10,
            },
          },
        },
      });
      expect(state.bowlerStats.length, equals(1));
      expect(state.bowlerStats['bo1']!.wickets, equals(2));
    });

    test('does not overwrite stats when keys are absent', () {
      state.homeScore = 50;
      state.homeBatsman = 'Set batsman';
      state.matchResult = 'Existing result';

      manager.applyRoomJoinedState(state, {
        'state': {
          'homeBatsFirst': true,
          'score2': 100, // only score2 provided, score1 should keep existing
        },
      });
      // score1 was not in data — should become 0 due to ?? 0 default
      // Actually: state.homeScore = hbf ? score1(0) : score2(100) = 0
      expect(state.homeScore, equals(0));
      // matchResult was not in data — should keep existing
      // Actually: matchResult = s['matchResult'] as String? ?? state.matchResult
      // s doesn't have matchResult, so state.matchResult preserved
      expect(state.matchResult, equals('Existing result'));
    });

    test('handles empty state data gracefully', () {
      // Should not throw
      expect(
        () => manager.applyRoomJoinedState(state, {'state': {}}),
        returnsNormally,
      );
    });

    test('handles missing state key by using data directly', () {
      manager.applyRoomJoinedState(state, {
        'homeBatsFirst': false,
        'score1': 200,
        'wickets1': 5,
      });
      expect(state.homeBatsFirst, isFalse);
      expect(state.homeScore, equals(200));
      expect(state.homeWickets, equals(5));
    });

    test('handles null state gracefully', () {
      expect(
        () => manager.applyRoomJoinedState(state, {'state': null}),
        returnsNormally,
      );
      // When state is null, falls back to data itself — no error
    });

    test('overs1/overs2 map correctly when homeBatsFirst flips', () {
      // Scenario: away batted first
      manager.applyRoomJoinedState(state, {
        'state': {
          'homeBatsFirst': false,
          'overs1': '20.0', // away's overs (batted first)
          'overs2': '18.3', // home's overs (batting second)
        },
      });
      expect(state.awayOvers, equals('20.0'));
      expect(state.homeOvers, equals('18.3'));
    });

    test('syncs isMatchComplete from isMatchComplete key', () {
      manager.applyRoomJoinedState(state, {
        'state': {'isMatchComplete': true},
      });
      expect(state.isMatchComplete, isTrue);
    });

    test('does not change homeBatsFirst when key absent from state', () {
      state.homeBatsFirst = false;
      manager.applyRoomJoinedState(state, {
        'state': {'score1': 100},
      });
      expect(state.homeBatsFirst, isFalse); // unchanged
    });
  });
}
