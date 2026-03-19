import 'dart:math';
import '../models/models.dart';

/// Ball-by-ball cricket match simulation engine.
/// Takes into account batting/bowling ratings, chemistry,
/// pitch conditions, form, fatigue, and randomness.
class MatchEngine {
  final List<SquadPlayer> homeXI;
  final List<SquadPlayer> awayXI;
  final int homeChemistry;
  final int awayChemistry;
  final int overs;
  final String pitchCondition;
  final String homeTeamName;
  final String awayTeamName;
  final bool homeBatsFirst;
  final Random _rng = Random();

  // Match state
  int _innings = 1;
  int _overNumber = 0;
  int _ballNumber = 0;
  int _score1 = 0;
  int _wickets1 = 0;
  int _score2 = 0;
  int _wickets2 = 0;

  /// Public accessors for final scores
  int get score1 => _score1;
  int get score2 => _score2;
  int get wickets1 => _wickets1;
  int get wickets2 => _wickets2;
  int get currentInnings => _innings;
  int get overNumber => _overNumber;
  int get ballNumber => _ballNumber;
  bool get matchComplete => _matchComplete;
  int get target => _target;
  int _currentBatsmanIndex = 0;
  int _currentBowlerIndex = 0;
  int _nonStrikerIndex = 1;
  int _nextBatsmanIndex = 2; // Next batsman to come in (after opener 0 and 1)
  bool _matchComplete = false;
  int _target = 0;

  // Batting/Bowling order
  late List<SquadPlayer> _battingOrder1;
  late List<SquadPlayer> _bowlingOrder1;
  late List<SquadPlayer> _battingOrder2;
  late List<SquadPlayer> _bowlingOrder2;

  // Current innings references
  late List<SquadPlayer> _currentBatting;
  late List<SquadPlayer> _currentBowling;

  MatchEngine({
    required this.homeXI,
    required this.awayXI,
    required this.homeChemistry,
    required this.awayChemistry,
    required this.overs,
    required this.pitchCondition,
    this.homeTeamName = 'Home',
    this.awayTeamName = 'Away',
    this.homeBatsFirst = true,
  }) {
    // Use the lineup order as provided (already sorted by position)
    _battingOrder1 = List.from(homeBatsFirst ? homeXI : awayXI);
    _bowlingOrder1 = (homeBatsFirst ? homeXI : awayXI)
        .where((p) =>
            p.userCard?.playerCard?.role == 'bowler' ||
            p.userCard?.playerCard?.role == 'all_rounder')
        .toList();
    if (_bowlingOrder1.isEmpty) _bowlingOrder1 = List.from(homeBatsFirst ? homeXI : awayXI);

    _battingOrder2 = List.from(homeBatsFirst ? awayXI : homeXI);
    _bowlingOrder2 = (homeBatsFirst ? awayXI : homeXI)
        .where((p) =>
            p.userCard?.playerCard?.role == 'bowler' ||
            p.userCard?.playerCard?.role == 'all_rounder')
        .toList();
    if (_bowlingOrder2.isEmpty) _bowlingOrder2 = List.from(homeBatsFirst ? awayXI : homeXI);

    // First innings: batting order 1 bats, bowling order 2 bowls
    _currentBatting = _battingOrder1;
    _currentBowling = _bowlingOrder2;
    _currentBatsmanIndex = 0;
    _nonStrikerIndex = 1;
    _currentBowlerIndex = 0;
  }

  int get maxOvers => overs;

  /// Card ID of the batsman currently on strike (will face the next ball).
  String? get currentStrikerCardId =>
      _currentBatsmanIndex < _currentBatting.length
          ? _currentBatting[_currentBatsmanIndex].userCardId
          : null;

  /// Card ID of the non-striker.
  String? get currentNonStrikerCardId =>
      _nonStrikerIndex < _currentBatting.length
          ? _currentBatting[_nonStrikerIndex].userCardId
          : null;

  bool get isFirstInnings => _innings == 1;

  int get _currentWickets => isFirstInnings ? _wickets1 : _wickets2;

  SquadPlayer get _currentBatsman => _currentBatting[_currentBatsmanIndex];
  SquadPlayer get _currentBowler =>
      _currentBowling[_currentBowlerIndex % _currentBowling.length];

  String getBatsmanName(String cardId) {
    for (final p in [...homeXI, ...awayXI]) {
      if (p.userCardId == cardId) {
        return p.userCard?.playerCard?.playerName ?? 'Unknown';
      }
    }
    return 'Unknown';
  }

  String getBowlerName(String cardId) => getBatsmanName(cardId);

  /// Simulate one ball. Returns null when match is complete.
  MatchEvent? simulateNextBall() {
    if (_matchComplete) return null;

    _ballNumber++;
    if (_ballNumber > 6) {
      _ballNumber = 1;
      _overNumber++;
      // Rotate bowler each over
      _currentBowlerIndex++;
      // Rotate strike
      _swapStrike();
    }

    // Check if innings/match is over
    if (_overNumber >= maxOvers || _currentWickets >= 10) {
      if (isFirstInnings) {
        return _endInnings();
      } else {
        return _endMatch();
      }
    }

    // Second innings: check if target chased
    if (!isFirstInnings && _score2 > _target) {
      return _endMatch();
    }

    final batsman = _currentBatsman;
    final bowler = _currentBowler;

    final battingRating = batsman.userCard?.effectiveBatting ?? 50;
    final bowlingRating = bowler.userCard?.effectiveBowling ?? 50;
    final chemistry = isFirstInnings
        ? (homeBatsFirst ? homeChemistry : awayChemistry)
        : (homeBatsFirst ? awayChemistry : homeChemistry);

    // Calculate outcome
    final outcome = _calculateOutcome(
      battingRating: battingRating,
      bowlingRating: bowlingRating,
      chemistry: chemistry,
    );

    // Build event
    final batsmanName = batsman.userCard?.playerCard?.playerName ?? 'Batsman';
    final bowlerName = bowler.userCard?.playerCard?.playerName ?? 'Bowler';

    int runs = 0;
    bool isWicket = false;
    bool isBoundary = false;
    String eventType;
    String commentary;
    String? wicketTypeResult;
    String? fielderCardIdResult;

    switch (outcome) {
      case BallOutcome.dot:
        runs = 0;
        eventType = 'dot_ball';
        commentary = _dotCommentary(batsmanName, bowlerName);
        break;
      case BallOutcome.single:
        runs = 1;
        eventType = 'single';
        final singleOptions = [
          '$batsmanName pushes for a quick single.',
          'Good running! They scamper through for one.',
          '$batsmanName taps it into the gap, easy single.',
          'Quick single taken by $batsmanName.',
          '$batsmanName nudges it away for a single.',
          'They steal a single, good running between the wickets.',
          '$batsmanName works it into space for one run.',
        ];
        commentary = singleOptions[_rng.nextInt(singleOptions.length)];
        _swapStrike();
        break;
      case BallOutcome.double:
        runs = 2;
        eventType = 'double';
        final doubleOptions = [
          '$batsmanName drives through the gap for two.',
          'Well placed! They come back for the second.',
          '$batsmanName finds the gap, comfortable two runs.',
          'Good running between the wickets, two runs added.',
          '$batsmanName works it into space for a couple.',
          'Pushed into the deep, they run hard for two.',
        ];
        commentary = doubleOptions[_rng.nextInt(doubleOptions.length)];
        break;
      case BallOutcome.triple:
        runs = 3;
        eventType = 'triple';
        final tripleOptions = [
          '$batsmanName finds the gap, they run three!',
          'Excellent running! Three runs taken!',
          '$batsmanName pushes it into the deep, they hustle for three!',
          'Great placement, they run hard for three runs!',
          'Into the gap! They sprint back for the third!',
        ];
        commentary = tripleOptions[_rng.nextInt(tripleOptions.length)];
        _swapStrike();
        break;
      case BallOutcome.four:
        runs = 4;
        isBoundary = true;
        eventType = 'four';
        commentary = _fourCommentary(batsmanName, bowlerName);
        break;
      case BallOutcome.six:
        runs = 6;
        isBoundary = true;
        eventType = 'six';
        commentary = _sixCommentary(batsmanName);
        break;
      case BallOutcome.wicket:
        runs = 0;
        isWicket = true;
        eventType = 'wicket';
        wicketTypeResult = _randomWicketType();
        final fielder = _pickFielder(wicketTypeResult, bowler);
        fielderCardIdResult = fielder?.userCardId;
        final fielderName = fielder?.userCard?.playerCard?.playerName;
        commentary = _wicketCommentary(batsmanName, bowlerName, wicketTypeResult, fielderName);
        break;
      case BallOutcome.wide:
        runs = 1;
        eventType = 'wide';
        final wideOptions = [
          'Wide ball from $bowlerName. Extra run.',
          'WIDE! $bowlerName loses his line.',
          'That\'s wide! $bowlerName strays down the leg side.',
          'Wide called! Poor delivery from $bowlerName.',
          'WIDE! $bowlerName misses his mark.',
          '$bowlerName sprays it wide, extra run conceded.',
        ];
        commentary = wideOptions[_rng.nextInt(wideOptions.length)];
        _ballNumber--; // Doesn't count as a legal ball
        break;
      case BallOutcome.noBall:
        runs = 1;
        eventType = 'no_ball';
        final noBallOptions = [
          'No ball! Free hit coming up.',
          'NO BALL! $bowlerName oversteps!',
          'That\'s a no ball! Extra delivery.',
          'NO BALL called! $bowlerName has overstepped.',
          'Free hit next ball! $bowlerName oversteps the crease.',
          '$bowlerName oversteps, that\'s a no ball!',
        ];
        commentary = noBallOptions[_rng.nextInt(noBallOptions.length)];
        _ballNumber--;
        break;
    }

    // Update score
    if (isFirstInnings) {
      _score1 += runs;
      if (isWicket) {
        _wickets1++;
        _advanceBatsman();
      }
    } else {
      _score2 += runs;
      if (isWicket) {
        _wickets2++;
        _advanceBatsman();
      }
    }

    // Check second innings chase
    if (!isFirstInnings && _score2 > _target) {
      _matchComplete = true;
    }

    return MatchEvent(
      id: '${_innings}_${_overNumber}_$_ballNumber',
      matchId: '',
      innings: _innings,
      overNumber: _overNumber,
      ballNumber: _ballNumber,
      battingTeamId: '',
      bowlingTeamId: '',
      batsmanCardId: batsman.userCardId,
      bowlerCardId: bowler.userCardId,
      eventType: eventType,
      runs: runs,
      isBoundary: isBoundary,
      isWicket: isWicket,
      wicketType: wicketTypeResult,
      fielderCardId: fielderCardIdResult,
      commentary: commentary,
      scoreAfter: isFirstInnings ? _score1 : _score2,
      wicketsAfter: isFirstInnings ? _wickets1 : _wickets2,
    );
  }

  MatchEvent? _endInnings() {
    if (isFirstInnings) {
      _target = _score1;

      // Correct end-of-innings over/ball:
      // _ballNumber was already incremented for the next (non-existent) ball.
      int endOver, endBall;
      if (_ballNumber == 1 && _overNumber > 0) {
        // Rolled over from ball 6 → complete over boundary
        endOver = _overNumber;
        endBall = 0;
      } else {
        endOver = _overNumber;
        endBall = _ballNumber > 0 ? _ballNumber - 1 : 0;
      }

      // Save innings 1 player IDs before swapping to innings 2
      final lastBatsmanId = _currentBatting[_currentBatsmanIndex].userCardId;
      final lastBowlerId = _currentBowling[_currentBowlerIndex % _currentBowling.length].userCardId;

      _innings = 2;
      _overNumber = 0;
      _ballNumber = 0;
      _currentBatting = _battingOrder2;
      _currentBowling = _bowlingOrder1;
      _currentBatsmanIndex = 0;
      _nonStrikerIndex = 1;
      _nextBatsmanIndex = 2;
      _currentBowlerIndex = 0;

      return MatchEvent(
        id: 'innings_break',
        matchId: '',
        innings: 1,
        overNumber: endOver,
        ballNumber: endBall,
        battingTeamId: '',
        bowlingTeamId: '',
        batsmanCardId: lastBatsmanId,
        bowlerCardId: lastBowlerId,
        eventType: 'innings_break',
        runs: 0,
        commentary:
            'End of first innings. Score: $_score1/$_wickets1. Target: ${_target + 1}',
        scoreAfter: _score1,
        wicketsAfter: _wickets1,
      );
    } else {
      return _endMatch();
    }
  }

  MatchEvent? _endMatch() {
    _matchComplete = true;
    return null;
  }

  String getMatchResult() {
    final battingFirstName = homeBatsFirst ? homeTeamName : awayTeamName;
    final battingSecondName = homeBatsFirst ? awayTeamName : homeTeamName;
    if (_score2 > _score1) {
      final wicketsRemaining = 10 - _wickets2;
      return '$battingSecondName wins by $wicketsRemaining wickets!';
    } else if (_score1 > _score2) {
      final runDiff = _score1 - _score2;
      return '$battingFirstName wins by $runDiff runs!';
    } else {
      return 'Match tied!';
    }
  }

  BallOutcome _calculateOutcome({
    required int battingRating,
    required int bowlingRating,
    required int chemistry,
  }) {
    // Base probabilities
    double dotProb = 0.35;
    double singleProb = 0.30;
    double doubleProb = 0.10;
    double tripleProb = 0.02;
    double fourProb = 0.10;
    double sixProb = 0.04;
    double wicketProb = 0.05;
    double wideProb = 0.02;
    double noBallProb = 0.02;

    // Batting skill modifier
    final batMod = (battingRating - 50) / 200.0;
    fourProb += batMod * 0.08;
    sixProb += batMod * 0.04;
    singleProb += batMod * 0.05;
    dotProb -= batMod * 0.10;
    wicketProb -= batMod * 0.04;

    // Bowling skill modifier
    final bowlMod = (bowlingRating - 50) / 200.0;
    dotProb += bowlMod * 0.10;
    wicketProb += bowlMod * 0.06;
    fourProb -= bowlMod * 0.06;
    sixProb -= bowlMod * 0.03;
    singleProb -= bowlMod * 0.04;

    // Chemistry modifier
    final chemMod = chemistry / 500.0;
    fourProb += chemMod * 0.02;
    sixProb += chemMod * 0.01;
    wicketProb -= chemMod * 0.02;

    // Pitch modifier
    switch (pitchCondition) {
      case 'batting_friendly':
        fourProb += 0.04;
        sixProb += 0.02;
        wicketProb -= 0.02;
        break;
      case 'bowling_friendly':
        wicketProb += 0.03;
        dotProb += 0.05;
        fourProb -= 0.03;
        sixProb -= 0.02;
        break;
      case 'spin_friendly':
        wicketProb += 0.02;
        dotProb += 0.03;
        break;
      case 'seam_friendly':
        wicketProb += 0.02;
        fourProb -= 0.02;
        break;
    }

    // Clamp all probabilities
    dotProb = dotProb.clamp(0.05, 0.60);
    singleProb = singleProb.clamp(0.10, 0.45);
    doubleProb = doubleProb.clamp(0.02, 0.20);
    tripleProb = tripleProb.clamp(0.005, 0.05);
    fourProb = fourProb.clamp(0.02, 0.25);
    sixProb = sixProb.clamp(0.01, 0.15);
    wicketProb = wicketProb.clamp(0.01, 0.15);
    wideProb = wideProb.clamp(0.01, 0.05);
    noBallProb = noBallProb.clamp(0.005, 0.03);

    // Normalize
    final total = dotProb +
        singleProb +
        doubleProb +
        tripleProb +
        fourProb +
        sixProb +
        wicketProb +
        wideProb +
        noBallProb;

    dotProb /= total;
    singleProb /= total;
    doubleProb /= total;
    tripleProb /= total;
    fourProb /= total;
    sixProb /= total;
    wicketProb /= total;
    wideProb /= total;
    noBallProb /= total;

    // Roll
    final roll = _rng.nextDouble();
    double cumulative = 0;

    cumulative += dotProb;
    if (roll < cumulative) return BallOutcome.dot;

    cumulative += singleProb;
    if (roll < cumulative) return BallOutcome.single;

    cumulative += doubleProb;
    if (roll < cumulative) return BallOutcome.double;

    cumulative += tripleProb;
    if (roll < cumulative) return BallOutcome.triple;

    cumulative += fourProb;
    if (roll < cumulative) return BallOutcome.four;

    cumulative += sixProb;
    if (roll < cumulative) return BallOutcome.six;

    cumulative += wicketProb;
    if (roll < cumulative) return BallOutcome.wicket;

    cumulative += wideProb;
    if (roll < cumulative) return BallOutcome.wide;

    return BallOutcome.noBall;
  }

  void _swapStrike() {
    final temp = _currentBatsmanIndex;
    _currentBatsmanIndex = _nonStrikerIndex;
    _nonStrikerIndex = temp;
  }

  void _advanceBatsman() {
    // New batsman replaces the dismissed one (current batsman)
    if (_nextBatsmanIndex < _currentBatting.length) {
      _currentBatsmanIndex = _nextBatsmanIndex;
      _nextBatsmanIndex++;
    }
  }

  String _randomWicketType() {
    final types = ['bowled', 'caught', 'lbw', 'run_out', 'stumped', 'caught_behind'];
    return types[_rng.nextInt(types.length)];
  }

  // Commentary generators
  String _dotCommentary(String batsman, String bowler) {
    final options = [
      '$bowler keeps it tight, dot ball.',
      'Good length from $bowler, $batsman defends solidly.',
      'Beaten! $bowler just misses the edge.',
      '$batsman leaves it alone, good judgement.',
      'Tight line from $bowler, no run.',
      '$batsman blocks it back to $bowler.',
      'Dot ball. $bowler builds the pressure.',
      '$batsman shoulders arms, good leave.',
      'Defended watchfully by $batsman.',
      '$bowler beats $batsman with a beauty!',
      'Past the outside edge! Close call!',
      '$batsman plays and misses, lucky to survive!',
      'Solid defense from $batsman, no run.',
      '$bowler on target, $batsman can\'t get it away.',
      'Excellent line from $bowler, dot ball.',
    ];
    return options[_rng.nextInt(options.length)];
  }

  String _fourCommentary(String batsman, String bowler) {
    final options = [
      '$batsman punches it through cover for FOUR!',
      'FOUR! $batsman drives beautifully past mid-off!',
      'Pulled away for FOUR! $batsman is in command.',
      'Cut shot for FOUR! $batsman finds the gap.',
      'FOUR through the legs! $bowler won\'t like that.',
      'Swept fine for FOUR! Excellent placement by $batsman.',
      'FOUR! $batsman finds the boundary with a cracking shot!',
      'Glorious cover drive! That races to the fence!',
      'FOUR! $batsman threads the gap perfectly!',
      'Exquisite timing from $batsman, four runs!',
      'Cut away beautifully for FOUR!',
      '$batsman leans into the drive, FOUR runs!',
      'Pulled away with authority! That\'s a boundary!',
      'FOUR! $batsman finds the rope with ease!',
      'Classy stroke from $batsman, four runs!',
      'Driven through the covers, FOUR!',
      '$batsman flicks it off his pads for FOUR!',
      'Square cut for four! Brilliant shot!',
      'FOUR! $batsman punishes the loose delivery!',
      'That\'s raced away to the boundary! FOUR!',
    ];
    return options[_rng.nextInt(options.length)];
  }

  String _sixCommentary(String batsman) {
    final options = [
      'SIX! $batsman launches it into the stands!',
      'MASSIVE SIX! $batsman clears the boundary with ease!',
      'That\'s gone all the way! SIX by $batsman!',
      'SIX! $batsman deposits it into the crowd!',
      'What a hit! $batsman muscles it for SIX!',
      'HIGH AND HANDSOME! SIX runs!',
      '$batsman absolutely smashes it for SIX!',
      'Out of the ground! What a strike from $batsman!',
      'SIX! $batsman clears the ropes with ease!',
      'Monstrous hit! That\'s disappeared into the crowd!',
      '$batsman gets under it and sends it sailing for SIX!',
      'BANG! $batsman deposits it over the boundary!',
      'Clean strike! SIX runs to $batsman!',
      '$batsman goes downtown! Maximum!',
      'Incredible power! That\'s a huge SIX!',
      'SIX! $batsman in full flow now!',
      'Into the stands! $batsman with a mighty blow!',
      'That\'s out of here! SIX runs!',
      '$batsman sends it soaring over the ropes!',
      'MAXIMUM! $batsman with a colossal hit!',
    ];
    return options[_rng.nextInt(options.length)];
  }

  /// Pick a fielder for caught/stumped dismissals from the bowling team
  SquadPlayer? _pickFielder(String wicketType, SquadPlayer bowler) {
    if (wicketType == 'bowled' || wicketType == 'lbw') return null;
    // All players in the fielding side
    final allFielders = isFirstInnings
        ? (homeBatsFirst ? awayXI : homeXI)
        : (homeBatsFirst ? homeXI : awayXI);
    if (wicketType == 'caught_behind' || wicketType == 'stumped') {
      // Pick the wicket keeper
      final keepers = allFielders.where((p) => p.userCard?.playerCard?.role == 'wicket_keeper').toList();
      if (keepers.isNotEmpty) return keepers[_rng.nextInt(keepers.length)];
    }
    // Pick any fielder (exclude batsman, exclude bowler for caught)
    final candidates = allFielders.where((p) => p.userCardId != bowler.userCardId).toList();
    if (candidates.isEmpty) return allFielders[_rng.nextInt(allFielders.length)];
    return candidates[_rng.nextInt(candidates.length)];
  }

  String _wicketCommentary(String batsman, String bowler, String wicketType, String? fielderName) {
    switch (wicketType) {
      case 'bowled':
        final options = [
          'BOWLED! $bowler knocks over the stumps! $batsman is gone!',
          'Timber! $bowler cleans up $batsman! What a delivery!',
          'BOWLED HIM! $batsman\'s stumps are shattered by $bowler!',
          'BOWLED! $bowler crashes through the defense!',
          'Through the gate! $bowler gets his man!',
          'CLEANED UP! $bowler shatters the stumps!',
          'BOWLED! The stumps are in disarray! $batsman departs!',
          'What a ball! $bowler knocks back the off stump!',
        ];
        return options[_rng.nextInt(options.length)];
      case 'caught':
        final catcher = fielderName ?? 'fielder';
        final options = [
          'CAUGHT! $batsman edges it and $catcher takes a sharp catch! $bowler strikes!',
          'OUT! Caught by $catcher! $bowler gets the wicket of $batsman!',
          'Gone! $batsman skies it to $catcher, c $catcher b $bowler!',
          'IN THE AIR... and taken! $catcher holds on! $bowler celebrates!',
          'CAUGHT! $catcher takes a brilliant catch! $batsman is gone!',
          'GONE! $catcher pouches it safely! $batsman walks back!',
          'CAUGHT! What a grab by $catcher! $bowler gets the breakthrough!',
          'Edged and taken! $catcher makes no mistake!',
          'OUT! $catcher with a stunning catch! $bowler strikes!',
        ];
        return options[_rng.nextInt(options.length)];
      case 'caught_behind':
        final keeper = fielderName ?? 'keeper';
        final options = [
          'CAUGHT BEHIND! $batsman nicks it and $keeper takes a clean catch! c $keeper b $bowler!',
          'Edge and taken! $keeper snaps it up, $batsman has to go! c $keeper b $bowler!',
          'CAUGHT BEHIND! $keeper with the gloves does the rest!',
          'Feather edge! $keeper takes a sharp catch behind the stumps!',
          'GONE! $keeper pouches it cleanly! c $keeper b $bowler!',
        ];
        return options[_rng.nextInt(options.length)];
      case 'lbw':
        final options = [
          'LBW! $bowler traps $batsman plumb in front! Given out!',
          'OUT! LBW! That was crashing into the stumps. $batsman walks back!',
          'PLUMB! That\'s hitting middle stump! $batsman has to go!',
          'OUT LBW! $bowler gets his man! Dead in front!',
          'TRAPPED! $batsman is gone LBW! $bowler strikes!',
          'LBW! No doubt about that one! $batsman departs!',
          'STONE DEAD! $bowler gets the LBW decision!',
          'OUT! That\'s as plumb as they come! LBW!',
        ];
        return options[_rng.nextInt(options.length)];
      case 'run_out':
        final thrower = fielderName ?? 'fielder';
        final options = [
          'RUN OUT! Direct hit by $thrower! $batsman is short of the crease!',
          'Gone! Brilliant throw from $thrower catches $batsman short!',
          'RUN OUT! Brilliant work by $thrower! $batsman is gone!',
          'DIRECT HIT! $thrower finds the stumps! $batsman is short!',
          'RUN OUT! $thrower with a rocket throw! $batsman can\'t make it!',
          'OUT! Superb fielding from $thrower! $batsman is run out!',
          'RUN OUT! $thrower hits the target! $batsman is well short!',
        ];
        return options[_rng.nextInt(options.length)];
      case 'stumped':
        final keeper = fielderName ?? 'keeper';
        final options = [
          'STUMPED! $batsman dances down the pitch and $keeper whips the bails off! st $keeper b $bowler!',
          'OUT! Quick work by $keeper! $batsman stumped off $bowler!',
          'STUMPED! Lightning work by $keeper! $batsman is out!',
          'STUMPED! $keeper whips off the bails! $batsman is gone!',
          'OUT STUMPED! Quick hands from $keeper! $batsman departs!',
          'STUMPED! $batsman is caught out of his crease! Brilliant keeping!',
        ];
        return options[_rng.nextInt(options.length)];
      default:
        return 'OUT! $bowler strikes! $batsman has to walk back.';
    }
  }
}

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
