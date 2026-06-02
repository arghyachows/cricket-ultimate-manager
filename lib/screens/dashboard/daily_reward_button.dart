import 'package:flutter/material.dart';

/// Daily reward claim button.
class DailyRewardButton extends StatelessWidget {
  final VoidCallback onTap;
  const DailyRewardButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard, size: 14, color: Colors.black87),
            SizedBox(width: 4),
            Text('Daily!',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}