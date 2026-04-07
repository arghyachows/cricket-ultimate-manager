class AppConstants {
  // Game settings
  static const int maxSquadSize = 30;
  static const int playingXISize = 11;
  static const int maxChemistry = 100;

  // Match formats
  static const int t20Overs = 20;
  static const int odiOvers = 50;

  // Economy
  static const int startingCoins = 5000;
  static const int startingPremium = 50;
  static const int matchWinCoins = 500;
  static const int matchLoseCoins = 100;
  static const int matchDrawCoins = 250;
  static const int matchWinXP = 100;
  static const int matchPlayXP = 30;

  // Leveling
  static const int xpPerLevel = 500;
  static const int maxLevel = 100;

  /// Returns the pack name awarded for reaching a given level, or null if no change.
  static String? packNameForLevel(int level) {
    if (level <= 10) return 'Bronze Pack';
    if (level <= 25) return 'Silver Pack';
    if (level <= 45) return 'Gold Pack';
    if (level <= 65) return 'Elite Pack';
    return 'Legend Pack';
  }

  // Market
  static const int minListingPrice = 100;
  static const int maxListingPrice = 10000000;
  static const int listingDurationHours = 6;
  static const double marketTax = 0.05;
  static const int minBidIncrement = 10;

  /// Minimum starting bid per rarity when listing a card for sale
  static const Map<String, int> minBidByRarity = {
    'bronze': 50,
    'silver': 200,
    'gold': 1000,
    'elite': 5000,
    'legend': 25000,
  };

  // Chemistry bonuses
  static const int countryChemistryBonus = 3;
  static const int teamChemistryBonus = 5;
  static const int leagueChemistryBonus = 2;
  static const int roleBalanceBonus = 10;

  // Pack probabilities by rarity
  static const Map<String, Map<String, double>> packProbabilities = {
    'Bronze Pack': {
      'bronze': 0.70,
      'silver': 0.22,
      'gold': 0.06,
      'elite': 0.015,
      'legend': 0.005,
    },
    'Silver Pack': {
      'bronze': 0.30,
      'silver': 0.45,
      'gold': 0.18,
      'elite': 0.05,
      'legend': 0.02,
    },
    'Gold Pack': {
      'bronze': 0.10,
      'silver': 0.25,
      'gold': 0.40,
      'elite': 0.18,
      'legend': 0.07,
    },
    'Elite Pack': {
      'bronze': 0.05,
      'silver': 0.15,
      'gold': 0.35,
      'elite': 0.30,
      'legend': 0.15,
    },
    'Legend Pack': {
      'bronze': 0.00,
      'silver': 0.05,
      'gold': 0.25,
      'elite': 0.40,
      'legend': 0.30,
    },
  };

  // Quick Sell prices by rarity
  static const Map<String, int> quickSellPrices = {
    'bronze': 25,
    'silver': 75,
    'gold': 250,
    'elite': 1000,
    'legend': 5000,
  };

  // Routes
  static const String loginRoute = '/login';
  static const String dashboardRoute = '/dashboard';
  static const String packsRoute = '/packs';
  static const String packOpeningRoute = '/packs/open';
  static const String collectionRoute = '/collection';
  static const String squadBuilderRoute = '/squad';
  static const String matchRoute = '/match';
  static const String matchPreviewRoute = '/match/preview';
  static const String liveMatchRoute = '/match/live';
  static const String marketRoute = '/market';
  static const String leaderboardRoute = '/leaderboard';
  static const String tournamentsRoute = '/tournaments';
  static const String tournamentMatchRoute = '/tournaments/match';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';
  static const String matchHistoryRoute = '/match/history';
  static const String multiplayerRoute = '/multiplayer';
  static const String multiplayerRoomRoute = '/multiplayer/room';
}
