class PlayerCard {
  final String id;
  final String playerName;
  final String country;
  final String? league;
  final String? team;
  final String role;
  final int rating;
  final int batting;
  final int bowling;
  final int fielding;
  final int stamina;
  final int pace;
  final int spin;
  final String rarity;
  final String cardType;
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
    required this.rarity,
    this.cardType = 'standard',
    this.imageUrl,
    this.countryFlagUrl,
  });

  factory PlayerCard.fromJson(Map<String, dynamic> json) {
    return PlayerCard(
      id: json['id'],
      playerName: json['player_name'],
      country: json['country'],
      league: json['league'],
      team: json['team'],
      role: json['role'],
      rating: json['rating'],
      batting: json['batting'],
      bowling: json['bowling'],
      fielding: json['fielding'],
      stamina: json['stamina'],
      pace: json['pace'] ?? 50,
      spin: json['spin'] ?? 50,
      rarity: json['rarity'],
      cardType: json['card_type'] ?? 'standard',
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
        'role': role,
        'rating': rating,
        'batting': batting,
        'bowling': bowling,
        'fielding': fielding,
        'stamina': stamina,
        'pace': pace,
        'spin': spin,
        'rarity': rarity,
        'card_type': cardType,
      };

  String get roleDisplay {
    switch (role) {
      case 'batsman':
        return 'BAT';
      case 'bowler':
        return 'BOWL';
      case 'all_rounder':
        return 'ALL';
      case 'wicket_keeper':
        return 'WK';
      default:
        return role.toUpperCase();
    }
  }

  String get roleLabel {
    switch (role) {
      case 'batsman':
        return 'Batsman';
      case 'bowler':
        return 'Bowler';
      case 'all_rounder':
        return 'All-Rounder';
      case 'wicket_keeper':
        return 'Wicket Keeper';
      default:
        return role.replaceAll('_', ' ');
    }
  }

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
