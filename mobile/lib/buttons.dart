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

/// A custom button widget that renders a solid gold, full-width button.
/// It is typically used for primary actions across the app (like "Save", "Confirm", "Next").
/// The actual gold color and styling are usually inherited from the app's global theme.
class GoldButton extends StatelessWidget {
  final String label; // The text to display on the button
  final VoidCallback? onPressed; // The action to perform when tapped (can be null to disable the button)
  final IconData? icon; // An optional icon to show next to the text

  const GoldButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Forces the button to take the full width of its parent and a fixed height of 52
      width: double.infinity, 
      height: 52,
      
      child: ElevatedButton(
        onPressed: onPressed,
        child: Row(
          // Centers the text and optional icon horizontally within the button
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The button text, converted to uppercase
            Text(label.toUpperCase()),
            
            // Conditionally render the icon if it was provided
            if (icon != null) ...[
              const SizedBox(width: 8), // Spacing between text and icon
              Icon(icon, size: 16),    // The icon itself
            ],
          ],
        ),
      ),
    );
  }
}

/// A custom button widget that renders a transparent button with a border.
/// It is typically used for secondary actions (like "Cancel", "Go Back", or "Edit").
/// The border and text styling are usually inherited from the app's global theme.
class GhostButton extends StatelessWidget {
  final String label; // The text to display on the button
  final VoidCallback? onPressed; // The action to perform when tapped (can be null to disable the button)

  const GhostButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Forces the button to take the full width of its parent and a fixed height of 52
      width: double.infinity, 
      height: 52,
      
      child: OutlinedButton(
        onPressed: onPressed,
        // The button text, converted to uppercase
        child: Text(label.toUpperCase()),
      ),
    );
  }
}