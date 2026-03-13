import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme.dart';
import '../models/models.dart';

enum CardSize { small, medium, large }

/// Maps a country name to an ethnicity / skin-tone keyword that matches the
/// uploaded image filenames (brown / dark / white).
String _ethnicityForCountry(String country) {
  switch (country) {
    case 'India':
    case 'Pakistan':
    case 'Sri Lanka':
    case 'Bangladesh':
    case 'Afghanistan':
      return 'brown';
    case 'West Indies':
    case 'South Africa':
      return 'dark';
    case 'England':
    case 'Australia':
    case 'New Zealand':
    case 'Ireland':
      return 'white';
    default:
      return 'brown';
  }
}

/// Maps a role string to the image-file prefix.
String _imageRolePrefix(String role) {
  switch (role) {
    case 'batsman':
      return 'batsman';
    case 'bowler':
      return 'bowler';
    case 'all_rounder':
      return 'all';
    case 'wicket_keeper':
      return 'wk';
    default:
      return 'batsman';
  }
}

/// Supabase public storage URL for the images bucket.
const _storageBucket =
    'https://kollxlzqqgznfiutpqjz.supabase.co/storage/v1/object/public/images';

/// Builds the Supabase storage URL for a player card background image.
String playerCardImageUrl(PlayerCard card) {
  final prefix = _imageRolePrefix(card.role);
  final tone = _ethnicityForCountry(card.country);
  return '$_storageBucket/$prefix-$tone.jpg';
}

class PlayerCardWidget extends StatelessWidget {
  final PlayerCard? playerCard;
  final UserCard? userCard;
  final CardSize size;
  final VoidCallback? onTap;
  final bool showStats;
  final bool isSelected;

  const PlayerCardWidget({
    super.key,
    this.playerCard,
    this.userCard,
    this.size = CardSize.medium,
    this.onTap,
    this.showStats = false,
    this.isSelected = false,
  });

  PlayerCard? get _card => playerCard ?? userCard?.playerCard;

  @override
  Widget build(BuildContext context) {
    final card = _card;
    if (card == null) return const SizedBox();

    final rarityColor = AppTheme.getRarityColor(card.rarity);
    final rating = userCard?.effectiveRating ?? card.rating;

    final dimensions = switch (size) {
      CardSize.small => (width: 80.0, height: 110.0, fontSize: 11.0, ratingSize: 20.0),
      CardSize.medium => (width: 120.0, height: 165.0, fontSize: 12.0, ratingSize: 28.0),
      CardSize.large => (width: 200.0, height: 275.0, fontSize: 14.0, ratingSize: 36.0),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: dimensions.width,
        height: dimensions.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : rarityColor.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Player image background
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: CachedNetworkImage(
                  imageUrl: playerCardImageUrl(card),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rarityColor,
                          rarityColor.withValues(alpha: 0.6),
                          rarityColor.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rarityColor,
                          rarityColor.withValues(alpha: 0.6),
                          rarityColor.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Rarity colour overlay (bottom → top gradient)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        rarityColor.withValues(alpha: 0.45),
                        Colors.transparent,
                        Colors.transparent,
                        rarityColor.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.2, 0.4, 0.7, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Rarity top-left accent ribbon
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        rarityColor.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.center,
                    ),
                  ),
                ),
              ),
            ),

            // Card content
            Padding(
              padding: EdgeInsets.all(size == CardSize.small ? 6 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating
                  Text(
                    '$rating',
                    style: TextStyle(
                      fontSize: dimensions.ratingSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                      shadows: const [
                        Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black87),
                        Shadow(offset: Offset(0, 0), blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),

                  // Role abbreviation
                  if (size != CardSize.small) ...[
                    Text(
                      card.roleDisplay.substring(0, card.roleDisplay.length.clamp(0, 3)).toUpperCase(),
                      style: TextStyle(
                        fontSize: dimensions.fontSize - 2,
                        color: Colors.white70,
                        letterSpacing: 1,
                        shadows: const [
                          Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black54),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Country flag placeholder
                  if (size == CardSize.large) ...[
                    Text(
                      card.country,
                      style: TextStyle(
                        fontSize: dimensions.fontSize - 2,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Player name
                  Text(
                    size == CardSize.small
                        ? card.playerName.split(' ').last
                        : card.playerName,
                    style: TextStyle(
                      fontSize: dimensions.fontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: const [
                        Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black87),
                        Shadow(offset: Offset(0, 0), blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                    maxLines: size == CardSize.small ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Stats bar (medium/large only)
                  if (showStats && size != CardSize.small) ...[
                    const SizedBox(height: 6),
                    _buildMiniStats(card, dimensions.fontSize - 3),
                  ],

                  // Rarity label
                  if (size != CardSize.small) ...[
                    const SizedBox(height: 2),
                    Text(
                      card.rarity.toUpperCase(),
                      style: TextStyle(
                        fontSize: dimensions.fontSize - 4,
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Level badge (if user card)
            if (userCard != null && userCard!.level > 1)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+${userCard!.level - 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Selection checkmark
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 14, color: rarityColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStats(PlayerCard card, double fontSize) {
    return Row(
      children: [
        _miniStat('BAT', card.batting, fontSize),
        const SizedBox(width: 4),
        _miniStat('BWL', card.bowling, fontSize),
        const SizedBox(width: 4),
        _miniStat('FLD', card.fielding, fontSize),
      ],
    );
  }

  Widget _miniStat(String label, int value, double fontSize) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: fontSize + 2,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize - 1,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
