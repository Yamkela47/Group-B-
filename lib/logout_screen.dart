import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'buttons.dart';
import 'role_selection_screen.dart';

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
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: const Icon(Icons.logout, color: AppColors.gold, size: 40),
              ),
              const SizedBox(height: 28),
              const Text('Are you sure you want to logout?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 40),
              GoldButton(
                label: 'Yes, Logout',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}