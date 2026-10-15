import 'package:flutter/material.dart';
import 'app_theme.dart';

class GradientThumb extends StatelessWidget {
  final IconData icon;
  final double size;
  const GradientThumb({super.key, required this.icon, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gold.withValues(alpha: 0.18), Colors.black],
        ),
      ),
      child: Icon(icon, color: AppColors.gold, size: size * 0.42),
    );
  }
}