import 'dart:math';
import '../models/models.dart';

/// Generates random AI opponent teams for matches.
class AIOpponent {
  static final _rng = Random();

  static const _teamNames = [
    'Mumbai Mavericks',
    'Delhi Dynamos',
    'Kolkata Knights',
    'Chennai Chargers',
    'Bangalore Blasters',
    'Hyderabad Hawks',
    'Rajasthan Royals XI',
    'Punjab Panthers',
    'Lucknow Legends',
    'Gujarat Gladiators',
    'Sydney Strikers',
    'Melbourne Stars XI',
    'London Lions',
    'Cape Town Cobras',
    'Auckland Aces',
    'Karachi Kings XI',
    'Dhaka Dragons',
    'Colombo Cavaliers',
    'Barbados Blazers',
    'Kabul Warriors',
  ];

  static const _countries = [
    'India', 'Australia', 'England', 'Pakistan', 'South Africa',
    'New Zealand', 'Sri Lanka', 'West Indies', 'Bangladesh', 'Afghanistan',
  ];

  static const _batsmanNames = [
    'Arjun Sharma', 'Liam Cooper', 'Rashid Malik', 'David Warner Jr',
    'Kane Mitchell', 'Rohit Verma', 'Steve Clarke', 'Babar Hussain',
    'Quinton de Villiers', 'Ross Williamson', 'Tom Burns', 'Faf du Toit',
    'Jason Holder Jr', 'Shubham Patel', 'Marcus Labuschagne',
  ];

  static const _bowlerNames = [
    'Jasprit Chahal', 'Pat Johnson', 'Shaheen Khan', 'Kagiso Morkel',
    'Trent Boult Jr', 'Mitchell Starc Jr', 'Adil Ahmed', 'Josh Hazlewood Jr',
    'Tim Southee Jr', 'Anrich Steyn',
  ];

  static const _allRounderNames = [
    'Ben Stokes Jr', 'Ravindra Jadeja Jr', 'Shakib Rahman',
    'Cameron Green Jr', 'Jason Holder III', 'Marco Jansen Jr',
  ];

  /// Generate a random AI team name.
  static String randomTeamName() {
    return _teamNames[_rng.nextInt(_teamNames.length)];
  }

  /// Generate a random AI chemistry value (30-80).
  static int randomChemistry() => 30 + _rng.nextInt(51);

  /// Generate 11 fake SquadPlayers for an AI opponent.
  /// [difficulty] 1-5 controls average ratings (1=easy, 5=hard).
  static List<SquadPlayer> generateXI({int difficulty = 3}) {
    final players = <SquadPlayer>[];
    final baseRating = 35 + (difficulty * 10); // 45-85 range

    // 1 WK, 4 batsmen, 3 all-rounders, 3 bowlers
    final roles = [
      ('wicket_keeper', 1),
      ('batsman', 4),
      ('all_rounder', 3),
      ('bowler', 3),
    ];

    int position = 1;
    for (final (role, count) in roles) {
      for (int i = 0; i < count; i++) {
        final name = _pickName(role);
        final country = _countries[_rng.nextInt(_countries.length)];
        final ratingVariation = _rng.nextInt(21) - 10; // -10 to +10
        final rating = (baseRating + ratingVariation).clamp(30, 95);

        int batting, bowling;
        switch (role) {
          case 'batsman':
          case 'wicket_keeper':
            batting = (rating + _rng.nextInt(11) - 5).clamp(30, 95);
            bowling = (rating - 20 + _rng.nextInt(11)).clamp(10, 60);
            break;
          case 'bowler':
            bowling = (rating + _rng.nextInt(11) - 5).clamp(30, 95);
            batting = (rating - 20 + _rng.nextInt(11)).clamp(10, 60);
            break;
          default: // all_rounder
            batting = (rating + _rng.nextInt(11) - 5).clamp(30, 95);
            bowling = (rating + _rng.nextInt(11) - 5).clamp(30, 95);
        }

        final rarity = _rarityForRating(rating);
        final fakeId = 'ai_${position}_${_rng.nextInt(99999)}';

        final playerCard = PlayerCard(
          id: fakeId,
          playerName: name,
          country: country,
          role: role,
          rating: rating,
          batting: batting,
          bowling: bowling,
          fielding: (40 + _rng.nextInt(40)).clamp(30, 90),
          stamina: (50 + _rng.nextInt(30)).clamp(40, 90),
          pace: role == 'bowler' ? 40 + _rng.nextInt(50) : 30 + _rng.nextInt(30),
          spin: role == 'bowler' ? 30 + _rng.nextInt(50) : 20 + _rng.nextInt(30),
          rarity: rarity,
        );

        final userCard = UserCard(
          id: fakeId,
          userId: 'ai',
          cardId: fakeId,
          level: 1 + _rng.nextInt(3),
          form: 40 + _rng.nextInt(30),
          fatigue: _rng.nextInt(15),
          acquiredAt: DateTime.now(),
          playerCard: playerCard,
        );

        players.add(SquadPlayer(
          id: fakeId,
          squadId: 'ai_squad',
          userCardId: fakeId,
          position: position,
          isPlayingXI: true,
          battingOrder: position,
          userCard: userCard,
        ));

        position++;
      }
    }

    return players;
  }

  static String _pickName(String role) {
    switch (role) {
      case 'bowler':
        return _bowlerNames[_rng.nextInt(_bowlerNames.length)];
      case 'all_rounder':
        return _allRounderNames[_rng.nextInt(_allRounderNames.length)];
      default:
        return _batsmanNames[_rng.nextInt(_batsmanNames.length)];
    }
  }

  static String _rarityForRating(int rating) {
    if (rating >= 85) return 'legend';
    if (rating >= 75) return 'elite';
    if (rating >= 65) return 'gold';
    if (rating >= 50) return 'silver';
    return 'bronze';
  }
}
