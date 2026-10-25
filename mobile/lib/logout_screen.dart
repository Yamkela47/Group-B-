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
import 'app_theme.dart';             // Custom colors and styles
import 'buttons.dart';               // Custom GoldButton and GhostButton widgets
import 'role_selection_screen.dart'; // The screen where the user chooses Customer or Stylist

/// A confirmation screen shown when a user attempts to log out.
/// It asks for confirmation and, if accepted, clears the navigation stack 
/// and returns the user to the role selection screen.
class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Spacer pushes the content to the vertical center of the screen
              const Spacer(),
              
              // Circular Icon Indicator
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: const Icon(Icons.logout, color: AppColors.gold, size: 40),
              ),
              const SizedBox(height: 28),
              
              // Confirmation Text
              const Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 20, 
                  fontWeight: FontWeight.w800
                ),
              ),
              const SizedBox(height: 40),
              
              // Primary Action: Confirm Logout
              GoldButton(
                label: 'Yes, Logout',
                onPressed: () {
                  // Note: While this navigates back to the login/role screen, 
                  // you should ideally call Supabase.instance.client.auth.signOut() 
                  // right before this navigation to properly clear the user session.
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                    (route) => false, // Clears the entire back-stack so they can't press back
                  );
                },
              ),
              const SizedBox(height: 12),
              
              // Secondary Action: Cancel
              GhostButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
              
              // Spacer pushes the content to the vertical center of the screen
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}