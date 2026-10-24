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
import 'app_theme.dart';       
import 'buttons.dart';      
import 'customer_home_screen.dart'; 

/// This screen serves as a success confirmation page shown immediately 
/// after a user successfully creates a new account.
class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea prevents the UI from overlapping with phone notches or status bars
      body: SafeArea(
        child: Padding(
          // Horizontal padding so content doesn't touch the screen edges
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Spacer pushes the content towards the vertical center of the screen
              const Spacer(),

              // Success circle + check icon
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle, // Makes the container a perfect circle
                  border: Border.all(color: AppColors.gold, width: 1.5), // Gold border
                ),
                child: const Icon(
                  Icons.check, // The checkmark icon indicating success
                  color: AppColors.gold,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28), // Spacing below the icon

              // Title Text
              const Text(
                'Account Created!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10), // Spacing between title and subtitle

              // Subtitle Text
              const Text(
                'Welcome to Cutting Edge Salon!\nYour account has been successfully created.',
                textAlign: TextAlign.center, // Centers the multi-line text
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5, // Adds line spacing for readability
                ),
              ),
              const SizedBox(height: 30),

              // Feature icons row (displays the perks of creating an account)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Spreads the badges evenly
                children: const [
                  _FeatureBadge(
                    icon: Icons.calendar_month_outlined,
                    label: 'Easy\nBooking',
                  ),
                  _FeatureBadge(
                    icon: Icons.notifications_none,
                    label: 'Reminders',
                  ),
                  _FeatureBadge(
                    icon: Icons.person_outline,
                    label: 'Stylist\nProfiles',
                  ),
                  _FeatureBadge(
                    icon: Icons.cancel_outlined,
                    label: 'Cancel\nAnytime',
                  ),
                ],
              ),

              // Spacer pushes the bottom button to the bottom of the screen
              const Spacer(),

              // Primary action button → Navigates to Customer Home
              GoldButton(
                label: 'Continue to Home',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerHomeScreen(),
                  ),
                  // (route) => false clears the entire back-stack.
                  // This prevents the user from pressing "back" and returning to the sign-up flow.
                  (route) => false,
                ),
              ),
              const SizedBox(height: 22), // Spacing below the button

              // Footer Text
              const Text(
                'Need help? Contact us',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------- Feature Badge */

/// A custom private widget used to display a circular icon with a text label below it.
/// It is reused for the row of features on the success screen.
class _FeatureBadge extends StatelessWidget {
  final IconData icon; // The icon to display inside the circle
  final String label;  // The text to display below the circle

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The circular container holding the icon
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceAlt,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.gold, size: 22),
        ),
        const SizedBox(height: 8),
        
        // The text label under the icon
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}