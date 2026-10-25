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
import 'app_theme.dart'; // Imports AppColors for default styling

/// A reusable widget used to display a small, pill-shaped status indicator.
/// Typically used to show the state of a booking (e.g., "Pending", "Completed", "Cancelled").
class StatusBadge extends StatelessWidget {
  final String text; // The text to display inside the badge
  final Color color; // The color theme for the badge (text, border, and background tint)
  
  // Constructor allows the color to default to gold if not provided
  const StatusBadge({super.key, required this.text, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding inside the pill shape
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      
      // Styling for the pill shape
      decoration: BoxDecoration(
        // Background color: the provided color with very low opacity (12%)
        color: color.withValues(alpha: 0.12),
        
        // Rounded corners to make it look like a pill
        borderRadius: BorderRadius.circular(20),
        
        // Border: the provided color with slightly higher opacity (40%)
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      
      // The text inside the badge
      child: Text(
        // Converts the text to uppercase (e.g., "pending" becomes "PENDING")
        text.toUpperCase(),
        
        // Text styling
        style: TextStyle(
          color: color, // Text color matches the provided theme color
          fontSize: 9,  // Very small font size suitable for a badge
          fontWeight: FontWeight.w800, // Extra bold for visibility
          letterSpacing: 1, // Adds space between letters for a clean look
        ),
      ),
    );
  }
}