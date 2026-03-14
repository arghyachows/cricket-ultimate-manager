import 'dart:math';
import '../models/models.dart';
import '../core/supabase_service.dart';

/// Generates AI opponent teams from real player_cards in the database.
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

  /// Rarity pools keyed by difficulty name.
  static const _rarityPools = {
    'Village': ['bronze', 'silver'],
    'Domestic': ['silver', 'gold'],
    'International': ['gold', 'elite', 'legend'],
  };

  /// Generate a random AI team name.
  static String randomTeamName() {
    return _teamNames[_rng.nextInt(_teamNames.length)];
  }

  /// Generate a random AI chemistry value (30-80).
  static int randomChemistry() => 30 + _rng.nextInt(51);

  /// Generate 11 SquadPlayers from DB player_cards.
  /// Composition: 4 batsmen, 1 wicket_keeper, 2 all_rounders, 4 bowlers.
  /// Rarity pool depends on [difficulty]: Village/Domestic/International.
  static Future<List<SquadPlayer>> generateXI({
    String difficulty = 'Village',
  }) async {
    final rarities = _rarityPools[difficulty] ?? ['bronze', 'silver'];

    // Fetch players per role from DB, filtered by rarity pool.
    // Order defines batting order: batsmen, WK, all-rounders, bowlers.
    final composition = [
      ('batsman', 4),
      ('wicket_keeper', 1),
      ('all_rounder', 2),
      ('bowler', 4),
    ];

    final picked = <PlayerCard>[];

    for (final (role, count) in composition) {

      try {
        final response = await SupabaseService.client
            .from('player_cards')
            .select()
            .eq('role', role)
            .inFilter('rarity', rarities)
            .limit(50);

        final dbCards = (response as List)
            .map((json) => PlayerCard.fromJson(json))
            .toList();

        if (dbCards.length >= count) {
          dbCards.shuffle(_rng);
          picked.addAll(dbCards.take(count));
        } else {
          // Use what we have from DB, fill rest with generated cards
          picked.addAll(dbCards);
          for (int i = dbCards.length; i < count; i++) {
            picked.add(_generateFakeCard(role, rarities, picked.length + i));
          }
        }
      } catch (_) {
        // DB failed — generate fake cards as fallback
        for (int i = 0; i < count; i++) {
          picked.add(_generateFakeCard(role, rarities, picked.length + i));
        }
      }
    }

    // Convert to SquadPlayers
    final players = <SquadPlayer>[];
    for (int i = 0; i < picked.length; i++) {
      final card = picked[i];
      final fakeId = 'ai_${i + 1}_${_rng.nextInt(99999)}';

      final userCard = UserCard(
        id: fakeId,
        userId: 'ai',
        cardId: card.id,
        level: 1 + _rng.nextInt(3),
        form: 40 + _rng.nextInt(30),
        fatigue: _rng.nextInt(15),
        acquiredAt: DateTime.now(),
        playerCard: card,
      );

      players.add(SquadPlayer(
        id: fakeId,
        squadId: 'ai_squad',
        userCardId: fakeId,
        position: i + 1,
        isPlayingXI: true,
        battingOrder: i + 1,
        userCard: userCard,
      ));
    }

    return players;
  }

  /// Fallback: generate a fake card when DB doesn't have enough for a role.
  static PlayerCard _generateFakeCard(String role, List<String> rarities, int index) {
    final rarity = rarities[_rng.nextInt(rarities.length)];
    final baseRating = _baseRatingForRarity(rarity);
    final variation = _rng.nextInt(11) - 5;
    final rating = (baseRating + variation).clamp(30, 99);

    int batting, bowling;
    switch (role) {
      case 'batsman':
      case 'wicket_keeper':
        batting = (rating + _rng.nextInt(11) - 5).clamp(30, 99);
        bowling = (rating - 20 + _rng.nextInt(11)).clamp(10, 60);
        break;
      case 'bowler':
        bowling = (rating + _rng.nextInt(11) - 5).clamp(30, 99);
        batting = (rating - 20 + _rng.nextInt(11)).clamp(10, 60);
        break;
      default:
        batting = (rating + _rng.nextInt(11) - 5).clamp(30, 99);
        bowling = (rating + _rng.nextInt(11) - 5).clamp(30, 99);
    }

    return PlayerCard(
      id: 'ai_gen_${index}_${_rng.nextInt(99999)}',
      playerName: 'AI Player ${index + 1}',
      country: 'Unknown',
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
  }

  static int _baseRatingForRarity(String rarity) {
    switch (rarity) {
      case 'legend': return 90;
      case 'elite': return 85;
      case 'gold': return 78;
      case 'silver': return 70;
      default: return 60;
    }
  }
}
