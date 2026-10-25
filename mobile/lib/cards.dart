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
import 'app_theme.dart'; // Custom colors and text styles

/// A highly reusable custom card widget used throughout the app.
/// It provides a consistent background color, border, and rounded corners.
/// It can optionally be made tappable by providing an [onTap] callback.
class AppCard extends StatelessWidget {
  final Widget child;             // The content inside the card
  final EdgeInsets padding;       // Internal spacing around the content
  final EdgeInsets? margin;       // External spacing around the card
  final Color? color;             // Optional custom background color
  final Color? borderColor;       // Optional custom border color
  final VoidCallback? onTap;      // Optional tap action for the card

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        // Uses the provided color, or defaults to the standard surfaceAlt color
        color: color ?? AppColors.surfaceAlt,
        // Rounded corners for the card
        borderRadius: BorderRadius.circular(12),
        // Uses the provided border color, or defaults to the standard border color
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      // Material widget is required to show the InkWell ripple effect properly
      child: Material(
        color: Colors.transparent, // Transparent so the Container's background color shows through
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12), // Ensures the ripple stays within the rounded corners
          child: Padding(
            padding: padding, 
            child: child, // The actual content of the card
          ),
        ),
      ),
    );
  }
}

/// A reusable widget for displaying section titles.
/// It renders a small, gold, uppercase text with optional trailing widgets
/// (like a "View All" button) on the right side.
class SectionHeading extends StatelessWidget {
  final String text;            // The title text to display
  final Widget? trailing;       // Optional widget to display on the right side

  const SectionHeading({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Adds vertical spacing above and below the heading
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // The main section title text
          Text(
            text.toUpperCase(), // Converts to uppercase for consistent styling
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              letterSpacing: 1.6, // Adds space between letters
              fontWeight: FontWeight.w800,
            ),
          ),
          
          // Spacer pushes the trailing widget to the far right
          const Spacer(),
          
          // Conditionally renders the trailing widget if provided
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}