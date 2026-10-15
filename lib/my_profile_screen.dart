import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'cards.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import 'logout_screen.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'My Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 82, height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: AppColors.gold, size: 40),
                  ),
                  const SizedBox(height: 14),
                  const Text('Nqobile Ngwenya',
                      style: TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Customer',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 16),
                  GoldButtonShort(
                    label: 'Edit Profile',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeading(text: 'Account'),
            _MenuRow(icon: Icons.person_outline, label: 'Edit Profile',
                screen: const EditProfileScreen()),
            _MenuRow(icon: Icons.help_outline, label: 'Help & Support',
                screen: const HelpSupportScreen()),
            _MenuRow(icon: Icons.settings_outlined, label: 'Settings',
                screen: const SettingsScreen()),
            _MenuRow(icon: Icons.logout, label: 'Logout',
                screen: const LogoutScreen()),
          ],
        ),
      ),
    );
  }
}

class GoldButtonShort extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GoldButtonShort({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160, height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(160, 42)),
        onPressed: onPressed,
        child: Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget screen;
  const _MenuRow({required this.icon, required this.label, required this.screen});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => screen)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}