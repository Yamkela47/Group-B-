import 'package:flutter/material.dart';
import 'app_theme.dart';      // AppColors
import 'buttons.dart';       // GoldButton
import 'customer_home_screen.dart'; // next destination

class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              // Success circle + check icon
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.gold,
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),

              // Title
              const Text(
                'Account Created!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Welcome to Cutting Edge Salon!\nYour account has been successfully created.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),

              // Feature icons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

              const Spacer(),

              // Primary action → Customer Home
              GoldButton(
                label: 'Continue to Home',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerHomeScreen(),
                  ),
                  (route) => false,
                ),
              ),
              const SizedBox(height: 22),

              // Footer
              const Text(
                'Need help? Contact us',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------- Feature Badge */

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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