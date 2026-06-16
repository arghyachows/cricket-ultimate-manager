import 'enums.dart';

class PlayerCard {
  final String id;
  final String playerName;
  final String country;
  final String? league;
  final String? team;
  final PlayerRole role;
  final int rating;
  final int batting;
  final int bowling;
  final int fielding;
  final int stamina;
  final int pace;
  final int spin;
  // Extended batting attributes
  final int aggression;
  final int technique;
  final int power;
  final int consistency;
  final int temperament;
  final int shotMaking;
  final int running;
  // Extended bowling attributes
  final int accuracy;
  final int variations;
  final int yorkers;
  final int bouncer;
  final CardRarity rarity;
  final CardType cardType;
  final String? imageUrl;
  final String? countryFlagUrl;

  const PlayerCard({
    required this.id,
    required this.playerName,
    required this.country,
    this.league,
    this.team,
    required this.role,
    required this.rating,
    required this.batting,
    required this.bowling,
    required this.fielding,
    required this.stamina,
    this.pace = 50,
    this.spin = 50,
    // Extended batting attributes (default to base rating)
    this.aggression = 50,
    this.technique = 50,
    this.power = 50,
    this.consistency = 50,
    this.temperament = 50,
    this.shotMaking = 50,
    this.running = 50,
    // Extended bowling attributes (default to base rating)
    this.accuracy = 50,
    this.variations = 50,
    this.yorkers = 50,
    this.bouncer = 50,
    required this.rarity,
    this.cardType = CardType.standard,
    this.imageUrl,
    this.countryFlagUrl,
  }) : assert(rating >= 1 && rating <= 99, 'rating must be 1-99'),
       assert(batting >= 1 && batting <= 99, 'batting must be 1-99'),
       assert(bowling >= 1 && bowling <= 99, 'bowling must be 1-99'),
       assert(stamina >= 1 && stamina <= 99, 'stamina must be 1-99');

  factory PlayerCard.fromJson(Map<String, dynamic> json) {
    return PlayerCard(
      id: json['id'],
      playerName: json['player_name'],
      country: json['country'],
      league: json['league'],
      team: json['team'],
      role: PlayerRole.fromValue(json['role'] as String? ?? 'batsman'),
      rating: json['rating'],
      batting: json['batting'],
      bowling: json['bowling'],
      fielding: json['fielding'],
      stamina: json['stamina'],
      pace: json['pace'] ?? 50,
      spin: json['spin'] ?? 50,
      // Extended batting attributes
      aggression: json['aggression'] ?? 50,
      technique: json['technique'] ?? 50,
      power: json['power'] ?? 50,
      consistency: json['consistency'] ?? 50,
      temperament: json['temperament'] ?? 50,
      shotMaking: json['shot_making'] ?? 50,
      running: json['running'] ?? 50,
      // Extended bowling attributes
      accuracy: json['accuracy'] ?? 50,
      variations: json['variations'] ?? 50,
      yorkers: json['yorkers'] ?? 50,
      bouncer: json['bouncer'] ?? 50,
      rarity: CardRarity.fromValue(json['rarity'] as String? ?? 'bronze'),
      cardType: CardType.fromValue(json['card_type'] as String? ?? 'standard'),
      imageUrl: json['image_url'],
      countryFlagUrl: json['country_flag_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'player_name': playerName,
        'country': country,
        'league': league,
        'team': team,
        'role': role.value,
        'rating': rating,
        'batting': batting,
        'bowling': bowling,
        'fielding': fielding,
        'stamina': stamina,
        'pace': pace,
        'spin': spin,
        'aggression': aggression,
        'technique': technique,
        'power': power,
        'consistency': consistency,
        'temperament': temperament,
        'shot_making': shotMaking,
        'running': running,
        'accuracy': accuracy,
        'variations': variations,
        'yorkers': yorkers,
        'bouncer': bouncer,
        'rarity': rarity.value,
        'card_type': cardType.value,
        'image_url': imageUrl,
        'country_flag_url': countryFlagUrl,
      };

  String get roleDisplay => role.display;
  String get roleLabel => role.label;

  String get countryCode {
    const codes = {
      'India': 'IND',
      'Australia': 'AUS',
      'England': 'ENG',
      'Pakistan': 'PAK',
      'South Africa': 'SA',
      'New Zealand': 'NZ',
      'Sri Lanka': 'SL',
      'West Indies': 'WI',
      'Bangladesh': 'BAN',
      'Afghanistan': 'AFG',
    };
    return codes[country] ?? country.substring(0, 3).toUpperCase();
  }
}
