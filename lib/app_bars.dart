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
import 'app_theme.dart'; // Imports AppColors for consistent styling
import 'brand.dart';    // Imports BrandTitleRow to display the logo and brand text

/* ===================================================================
   MAIN APP BAR
   Used on the home screens. 
   =================================================================== */
/// A custom AppBar used for the main home screens (Customer and Stylist).
/// Implements [PreferredSizeWidget] so it can be assigned directly to the
/// `appBar` property of a Scaffold.
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  // Callback function triggered when the notification bell is tapped
  final VoidCallback? onBell;
  // Boolean to toggle the little gold dot notification badge
  final bool showBellBadge;
  // Allows adding a bottom widget (like a TabBar) to the app bar if needed
  final PreferredSizeWidget? bottom;

  const MainAppBar({
    super.key,
    this.onBell,
    this.showBellBadge = true,
    this.bottom,
  });

  // Defines the total height of the AppBar so the Scaffold knows how much space to reserve.
  // Base height is 80, plus the height of the bottom widget if it exists.
  @override
  Size get preferredSize => Size.fromHeight(80 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // We disable the default back button since this is a main screen
      automaticallyImplyLeading: false,
      // Transparent so the container's rounded corners and border show perfectly
      backgroundColor: Colors.transparent, 
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 80, // Fixed height for the toolbar
      titleSpacing: 0,
      
      // The custom "floating card" look for the app bar
      title: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(12), // Rounded corners
          border: Border.all(color: AppColors.gold, width: 1.5), // Gold border
        ),
        child: Row(
          children: [
            // The logo and "CUTTING EDGE" text on the left
            const BrandTitleRow(logoSize: 40),
            const Spacer(), // Pushes the next icons to the far right
            
            // Hamburger menu on the right
            // Using a Builder to access the correct Scaffold context to open the drawer
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 26, color: AppColors.gold),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            
            // Bell icon for notifications
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none, size: 24, color: Colors.white),
                  onPressed: onBell ?? () {},
                ),
                // The little gold dot showing there are unread notifications
                if (showBellBadge)
                  Positioned(
                    right: 12,
                    top: 14,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottom: bottom, // The optional bottom widget
    );
  }
}

/* ===================================================================
   SCREEN APP BAR
   Used on all inner screens.
   =================================================================== */
/// A custom AppBar used for all inner screens (e.g., Bookings, Services).
/// It includes a back button, the brand logo, and an optional title/actions.
class ScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; // The title text (sometimes hidden in favor of the logo)
  final List<Widget>? actions; // Optional action buttons on the right
  final PreferredSizeWidget? bottom; // Optional bottom widget (like tabs)
  
  const ScreenAppBar({
    super.key, 
    required this.title, 
    this.actions,
    this.bottom,
  });

  // Calculates the height of the app bar (80 base + bottom height)
  @override
  Size get preferredSize => Size.fromHeight(80 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false, // We build our own custom back button
      backgroundColor: Colors.transparent, // Transparent to show the custom container
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 80,
      titleSpacing: 0,
      
      // Custom floating card look
      title: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: Row(
          children: [
            // Custom back button
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.gold),
              onPressed: () => Navigator.pop(context),
            ),
            // Brand logo and text
            const BrandTitleRow(logoSize: 36),
            const Spacer(), // Pushes any actions to the right
            
            // Optional actions (e.g., refresh icon, edit button)
            if (actions != null) ...actions!,
          ],
        ),
      ),
      bottom: bottom,
    );
  }
}