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
import 'app_theme.dart'; // Custom colors like AppColors.gold, black, and textMuted

/// A simple data class representing a single item in the bottom navigation bar.
/// It holds the [icon] to display and the text [label] beneath it.
class BottomNavItem {
  final IconData icon;
  final String label;
  const BottomNavItem(this.icon, this.label);
}

/// A custom Bottom Navigation Bar widget.
/// It replaces the standard Flutter BottomNavigationBar to match the specific
/// dark/gold aesthetic of the Cutting Edge app.
class BottomNav extends StatelessWidget {
  final int index; // The currently selected tab index (e.g., 0 for Home, 1 for Services)
  final List<BottomNavItem> items; // The list of navigation items to display
  final ValueChanged<int> onChanged; // Callback function triggered when a tab is tapped

  const BottomNav({
    super.key, 
    required this.index,
    required this.items, 
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // The container styling: black background with a subtle top border
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: AppColors.border)), // Separates the nav bar from the screen body
      ),
      
      // SafeArea ensures the navigation bar doesn't overlap with system gestures 
      // (like the iOS home indicator or Android navigation buttons).
      child: SafeArea(
        top: false, // We only want padding at the bottom, not the top
        child: SizedBox(
          height: 62, // Fixed height for the navigation bar
          
          // A Row holds the navigation items horizontally
          child: Row(
            // List.generate dynamically creates a widget for each item in the 'items' list
            children: List.generate(items.length, (i) {
              final item = items[i];
              // Check if this item is the currently selected one
              final selected = i == index;
              
              // Expanded ensures each item takes up an equal amount of horizontal space
              return Expanded(
                // InkWell provides the ripple effect when the user taps the item
                child: InkWell(
                  onTap: () => onChanged(i), // Trigger the callback when tapped
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                    children: [
                      // The Icon
                      Icon(
                        item.icon,
                        // Color changes based on selection: Gold if selected, Muted grey if not
                        color: selected ? AppColors.gold : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(height: 4), // Spacing between icon and text
                      
                      // The Label Text
                      Text(
                        item.label,
                        style: TextStyle(
                          // Text color matches the icon color logic
                          color: selected ? AppColors.gold : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}