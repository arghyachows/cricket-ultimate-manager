import 'package:flutter/material.dart';

/// Small stat column used inside featured card.
class MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const MiniStat({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}