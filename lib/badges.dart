import 'package:flutter/material.dart';
import 'app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge({super.key, required this.text, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color, fontSize: 9,
          fontWeight: FontWeight.w800, letterSpacing: 1,
        ),
      ),
    );
  }
}