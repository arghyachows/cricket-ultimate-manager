import 'enums.dart';

class MarketListing {
  final String id;
  final String sellerId;
  final String? userCardId;
  final int buyNowPrice;
  final int startingBid;
  final int currentBid;
  final String? currentBidderId;
  final ListingStatus status;
  final DateTime expiresAt;
  final DateTime? soldAt;
  final String? sellerUsername;
  final Map<String, dynamic>? userCardData;
  // Contract listing fields
  final ListingType listingType;
  final String? contractTypeId;
  final int quantity;
  final Map<String, dynamic>? contractTypeData;

  const MarketListing({
    required this.id,
    required this.sellerId,
    this.userCardId,
    required this.buyNowPrice,
    required this.startingBid,
    this.currentBid = 0,
    this.currentBidderId,
    this.status = ListingStatus.active,
    required this.expiresAt,
    this.soldAt,
    this.sellerUsername,
    this.userCardData,
    this.listingType = ListingType.card,
    this.contractTypeId,
    this.quantity = 1,
    this.contractTypeData,
  }) : assert(buyNowPrice >= 0, 'buyNowPrice must be >= 0'),
       assert(startingBid >= 0, 'startingBid must be >= 0'),
       assert(currentBid >= 0, 'currentBid must be >= 0'),
       assert(quantity >= 1, 'quantity must be >= 1');

  factory MarketListing.fromJson(Map<String, dynamic> json) {
    final listingType = ListingType.fromValue(json['listing_type'] as String? ?? 'card');
    return MarketListing(
      id: json['id'],
      sellerId: json['seller_id'],
      userCardId: json['user_card_id'],
      buyNowPrice: json['buy_now_price'],
      startingBid: json['starting_bid'],
      currentBid: json['current_bid'] ?? 0,
      currentBidderId: json['current_bidder_id'],
      status: ListingStatus.fromValue(json['status'] as String? ?? 'active'),
      expiresAt: DateTime.parse(json['expires_at']),
      soldAt:
          json['sold_at'] != null ? DateTime.parse(json['sold_at']) : null,
      sellerUsername: json['users']?['username'],
      userCardData: json['user_cards'],
      listingType: listingType,
      contractTypeId: json['contract_type_id'],
      quantity: json['quantity'] ?? 1,
      contractTypeData: json['contract_types'],
    );
  }

  bool get isActive => status == ListingStatus.active;
  bool get hasExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'seller_id': sellerId,
        'user_card_id': userCardId,
        'buy_now_price': buyNowPrice,
        'starting_bid': startingBid,
        'current_bid': currentBid,
        'current_bidder_id': currentBidderId,
        'status': status.value,
        'expires_at': expiresAt.toIso8601String(),
        'sold_at': soldAt?.toIso8601String(),
        'listing_type': listingType.value,
        'contract_type_id': contractTypeId,
        'quantity': quantity,
      };

  Duration get timeRemaining => expiresAt.difference(DateTime.now().toUtc());
  String get timeRemainingDisplay {
    final remaining = timeRemaining;
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours > 0) return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    return '${remaining.inMinutes}m';
  }
}

class MarketBid {
  final String id;
  final String listingId;
  final String bidderId;
  final int bidAmount;
  final BidStatus status;
  final DateTime createdAt;
  final MarketListing? listing;

  const MarketBid({
    required this.id,
    required this.listingId,
    required this.bidderId,
    required this.bidAmount,
    this.status = BidStatus.active,
    required this.createdAt,
    this.listing,
  });

  factory MarketBid.fromJson(Map<String, dynamic> json) {
    return MarketBid(
      id: json['id'],
      listingId: json['listing_id'],
      bidderId: json['bidder_id'],
      bidAmount: json['bid_amount'],
      status: BidStatus.fromValue(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at']),
      listing: json['transfer_market'] != null
          ? MarketListing.fromJson(json['transfer_market'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'bidder_id': bidderId,
        'bid_amount': bidAmount,
        'status': status.value,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isActive => status == BidStatus.active;
  bool get isWon => status == BidStatus.won;
  bool get isOutbid => status == BidStatus.outbid;
  bool get isLost => status == BidStatus.lost;
}

class PackType {
  final String id;
  final String name;
  final String? description;
  final int coinCost;
  final int premiumCost;
  final int cardCount;
  final double bronzeChance;
  final double silverChance;
  final double goldChance;
  final double eliteChance;
  final double legendChance;
  final String? imageUrl;

  const PackType({
    required this.id,
    required this.name,
    this.description,
    this.coinCost = 0,
    this.premiumCost = 0,
    this.cardCount = 3,
    this.bronzeChance = 60,
    this.silverChance = 25,
    this.goldChance = 10,
    this.eliteChance = 4,
    this.legendChance = 1,
    this.imageUrl,
  });

  factory PackType.fromJson(Map<String, dynamic> json) {
    return PackType(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      coinCost: json['coin_cost'] ?? 0,
      premiumCost: json['premium_cost'] ?? 0,
      cardCount: json['card_count'] ?? 3,
      bronzeChance: (json['bronze_chance'] ?? 60).toDouble(),
      silverChance: (json['silver_chance'] ?? 25).toDouble(),
      goldChance: (json['gold_chance'] ?? 10).toDouble(),
      eliteChance: (json['elite_chance'] ?? 4).toDouble(),
      legendChance: (json['legend_chance'] ?? 1).toDouble(),
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'coin_cost': coinCost,
        'premium_cost': premiumCost,
        'card_count': cardCount,
        'bronze_chance': bronzeChance,
        'silver_chance': silverChance,
        'gold_chance': goldChance,
        'elite_chance': eliteChance,
        'legend_chance': legendChance,
        'image_url': imageUrl,
      };

  bool get isCoinPurchase => coinCost > 0;
  bool get isPremiumPurchase => premiumCost > 0;
}

class Transaction {
  final String id;
  final String userId;
  final String type;
  final int coinsAmount;
  final int premiumAmount;
  final String? description;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.userId,
    required this.type,
    this.coinsAmount = 0,
    this.premiumAmount = 0,
    this.description,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      coinsAmount: json['coins_amount'] ?? 0,
      premiumAmount: json['premium_amount'] ?? 0,
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'coins_amount': coinsAmount,
        'premium_amount': premiumAmount,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };
}

class DailyObjective {
  final String id;
  final String userId;
  final String title;
  final String description;
  final int targetValue;
  final int currentValue;
  final int rewardCoins;
  final int rewardPremium;
  final int rewardXp;
  final ObjectiveStatus status;

  const DailyObjective({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.targetValue = 1,
    this.currentValue = 0,
    this.rewardCoins = 0,
    this.rewardPremium = 0,
    this.rewardXp = 0,
    this.status = ObjectiveStatus.active,
  });

  factory DailyObjective.fromJson(Map<String, dynamic> json) {
    return DailyObjective(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      targetValue: json['target_value'] ?? 1,
      currentValue: json['current_value'] ?? 0,
      rewardCoins: json['reward_coins'] ?? 0,
      rewardPremium: json['reward_premium'] ?? 0,
      rewardXp: json['reward_xp'] ?? 0,
      status: ObjectiveStatus.fromValue(json['status'] as String? ?? 'active'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'target_value': targetValue,
        'current_value': currentValue,
        'reward_coins': rewardCoins,
        'reward_premium': rewardPremium,
        'reward_xp': rewardXp,
        'status': status.value,
      };

  double get progress => targetValue > 0 ? currentValue / targetValue : 0;
  bool get isCompleted => currentValue >= targetValue;
}

class Tournament {
  final String id;
  final String name;
  final String? description;
  final String format;
  final int maxParticipants;
  final int currentParticipants;
  final int entryFeeCoins;
  final int prizeCoins;
  final TournamentStatus status;
  final DateTime startsAt;

  const Tournament({
    required this.id,
    required this.name,
    this.description,
    this.format = 't20',
    this.maxParticipants = 16,
    this.currentParticipants = 0,
    this.entryFeeCoins = 0,
    this.prizeCoins = 0,
    this.status = TournamentStatus.open,
    required this.startsAt,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) {
    return Tournament(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      format: json['format'] ?? 't20',
      maxParticipants: json['max_participants'] ?? 16,
      currentParticipants: json['current_participants'] ?? 0,
      entryFeeCoins: json['entry_fee_coins'] ?? 0,
      prizeCoins: json['prize_coins'] ?? 0,
      status: TournamentStatus.fromValue(json['status'] as String? ?? 'open'),
      startsAt: DateTime.parse(json['starts_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'format': format,
        'max_participants': maxParticipants,
        'current_participants': currentParticipants,
        'entry_fee_coins': entryFeeCoins,
        'prize_coins': prizeCoins,
        'status': status.value,
        'starts_at': startsAt.toIso8601String(),
      };

  bool get isFull => currentParticipants >= maxParticipants;
  bool get isOpen => status == TournamentStatus.open && !isFull;
}
