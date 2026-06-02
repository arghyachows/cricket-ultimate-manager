import 'package:flutter/material.dart';

/// Individual action tile used in quick actions grid.
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<Color> gradient;
  final VoidCallback onTap;
  final double height;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.gradient,
    required this.onTap,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}