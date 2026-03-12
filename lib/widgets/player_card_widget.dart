import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';

enum CardSize { small, medium, large }

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
          gradient: LinearGradient(
            colors: [
              rarityColor,
              rarityColor.withValues(alpha: 0.6),
              rarityColor.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
            // Background pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: CustomPaint(
                  painter: _CardPatternPainter(rarityColor),
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
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
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
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

class _CardPatternPainter extends CustomPainter {
  final Color color;
  _CardPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
