/*
===========================================================
PROJECT: Cutting Edge Salon
STUDENT DETAILS:
-----------------------------------------------------------
Name                  | Student Number
-----------------------------------------------------------
Goitse Kgwele         | 221050663
Thabang Zitha         | 223007074
Yamkela Mazamani      | 224007421
Nyakallo Pali         | 223060226
Bennet Linda          | 224004294
===========================================================
*/

import 'package:flutter/material.dart';
import 'app_theme.dart'; // Imports custom colors (AppColors)

/// A reusable widget that displays a square icon inside a stylish 
/// gradient container. It is often used as a placeholder thumbnail 
/// or an icon button.
class GradientThumb extends StatelessWidget {
  final IconData icon; // The icon to display in the center
  final double size;   // The overall width and height of the square container

  const GradientThumb({super.key, required this.icon, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Sets fixed dimensions based on the provided size parameter
      width: size, 
      height: size,
      
      // Applies the visual styling: rounded corners, a border, and a gradient background
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10), // Rounded corners
        border: Border.all(color: AppColors.border), // Subtle border color
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.18), // Semi-transparent gold at the top left
            Colors.black,                           // Solid black at the bottom right
          ],
        ),
      ),
      
      // The icon is centered by default and sized proportionally to the container
      child: Icon(
        icon, 
        color: AppColors.gold, 
        size: size * 0.42, // Icon takes up 42% of the container's overall size
      ),
    );
  }
}