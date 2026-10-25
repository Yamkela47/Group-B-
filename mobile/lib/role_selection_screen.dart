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
import 'brand.dart';                // Brand logo and title widget
import 'login_screen.dart';         // Screen to sign in
import 'create_account_screen.dart'; // Screen to register a new account

/// The initial screen where users choose whether they are a Customer or a Stylist.
/// Based on the selection, the UI changes (e.g., showing the "Create Account" button).
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // State to track whether the user has selected the "Customer" role.
  // Defaults to true. If false, it implies the "Stylist" role is selected.
  bool _isCustomer = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Spacers are used to push the content to the middle of the screen
              const Spacer(flex: 2),
              
              // --- BRAND LOGO ---
              const BrandTitle(logoSize: 80),
              
              const Spacer(flex: 2),
              
              // --- WELCOME TEXT ---
              const Text(
                'Welcome',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Welcome to Cutting Edge Salon application.\nPlease select how you would like to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              
              const Spacer(flex: 3),
              
              // --- ROLE SELECTION CARDS ---
              // Customer Card
              _RoleCard(
                title: 'Customer',
                icon: Icons.person_outline,
                isSelected: _isCustomer,
                onTap: () => setState(() => _isCustomer = true),
              ),
              const SizedBox(height: 16),
              
              // Stylist Card
              _RoleCard(
                title: 'Stylist',
                icon: Icons.content_cut,
                isSelected: !_isCustomer, // Selected if _isCustomer is false
                onTap: () => setState(() => _isCustomer = false),
              ),
              
              const Spacer(flex: 4),
              
              // --- ACTION BUTTONS ---
              // Sign In Button (always visible)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to the Login Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(), 
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SIGN IN',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
              ),
              
              // Create Account Button (Only visible if the Customer role is selected)
              if (_isCustomer) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to the Create Account Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateAccountScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.gold, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CUSTOM ROLE SELECTION CARD ---
/// A custom widget representing a selectable card for choosing a user role.
/// It uses an AnimatedContainer to smoothly transition colors when selected.
class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), // Smooth transition speed
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          // Change background color slightly if selected (light gold tint)
          color: isSelected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          // Change border color if selected
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon changes color based on selection
            Icon(
              icon,
              color: isSelected ? AppColors.gold : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            
            // Text changes color based on selection
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.gold : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const Spacer(),
            
            // Show a checkmark icon only if this card is selected
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.gold,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}