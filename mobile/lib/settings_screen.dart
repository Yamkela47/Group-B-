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
import 'app_theme.dart';              // Custom colors and styles
import 'app_bars.dart';               // Custom AppBar widget
import 'cards.dart';                  // Custom AppCard widget
import 'logout_screen.dart';          // Screen to confirm logout
import 'help_support_screen.dart';    // Screen for FAQs and support
import 'terms_privacy_screen.dart';   // Screen for legal terms
import 'about_us_screen.dart';        // Screen for salon information

/// A screen that allows the user to manage their app preferences.
/// It handles notification toggles, location permissions, and links to 
/// support, legal, and account management screens.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ==========================================
  // STATE VARIABLES
  // ==========================================
  // Notification toggles
  bool _pushNotifs = true;
  bool _emailNotifs = true;
  
  // App preferences
  bool _useLocation = true;
  String _reminderTime = '1 hour before'; 

  /// Simulates clearing the app's cache and shows a success message.
  void _clearCache() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App cache cleared successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// Displays a bottom sheet allowing the user to select how early they 
  /// want to receive booking reminders.
  void _showReminderPicker() {
    final List<String> options = [
      '30 minutes before',
      '1 hour before',
      '3 hours before',
      '24 hours before',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom sheet title
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Select Reminder Time',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              // Generate a list tile for each option
              ...options.map((time) {
                return ListTile(
                  title: Text(time, style: const TextStyle(color: Colors.white)),
                  // Show a checkmark next to the currently selected option
                  trailing: _reminderTime == time 
                      ? const Icon(Icons.check, color: AppColors.gold) 
                      : null,
                  onTap: () {
                    // Update state, close the bottom sheet, and show confirmation
                    setState(() => _reminderTime = time);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reminders set to $time'), backgroundColor: AppColors.success),
                    );
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ==========================================
          // NOTIFICATIONS SECTION
          // ==========================================
          const Text('NOTIFICATIONS',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          
          // Toggle for Push Notifications
          _SwitchRow(
            label: 'Push Notifications',
            subtitle: 'Receive booking reminders and offers',
            value: _pushNotifs,
            onChanged: (v) => setState(() => _pushNotifs = v),
          ),
          // Toggle for Email Notifications
          _SwitchRow(
            label: 'Email Notifications',
            subtitle: 'Receive receipts and updates via email',
            value: _emailNotifs,
            onChanged: (v) => setState(() => _emailNotifs = v),
          ),

          // Card to select reminder time
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: _showReminderPicker,
            child: Row(
              children: [
                const Icon(Icons.alarm, color: AppColors.gold, size: 20),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking Reminder Time',
                          style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('Choose how early to be notified',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Text(_reminderTime, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
          
          const SizedBox(height: 22),
          
          // ==========================================
          // APP PREFERENCES SECTION
          // ==========================================
          const Text('APP PREFERENCES',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          
          // Toggle for Location Services
          _SwitchRow(
            label: 'Location Services',
            subtitle: 'Allow app to use your location for directions',
            value: _useLocation,
            onChanged: (v) => setState(() => _useLocation = v),
          ),
          
          // Card to clear app cache
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: _clearCache,
            child: const Row(
              children: [
                Icon(Icons.cleaning_services_outlined, color: AppColors.gold, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text('Clear App Cache',
                      style: TextStyle(color: Colors.white, fontSize: 13.5)),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),

          const SizedBox(height: 22),
          
          // ==========================================
          // ABOUT & SUPPORT SECTION
          // ==========================================
          const Text('ABOUT & SUPPORT',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),

          // Card to navigate to the About Us screen
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutUsScreen()),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.storefront_outlined, color: AppColors.gold, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text('About Us',
                      style: TextStyle(color: Colors.white, fontSize: 13.5)),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),

          // Card to navigate to the Help & Support screen
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text('Help & Support',
                      style: TextStyle(color: Colors.white, fontSize: 13.5)),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),

          // Card to navigate to Terms & Privacy Policy
          AppCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsPrivacyScreen()),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.description_outlined, color: AppColors.gold, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text('Terms & Privacy Policy',
                      style: TextStyle(color: Colors.white, fontSize: 13.5)),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),

          // Display app version (Read-only)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('App Version', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                Text('v1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: 22),
          
          // ==========================================
          // ACCOUNT SECTION
          // ==========================================
          const Text('ACCOUNT',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          
          // Card to navigate to the Logout Screen
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LogoutScreen())),
            child: const Row(
              children: [
                Icon(Icons.logout, color: AppColors.error, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text('Logout',
                      style: TextStyle(color: AppColors.error, fontSize: 13.5, fontWeight: FontWeight.bold)),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/* ===================================================================
   SWITCH ROW WIDGET
   =================================================================== */
/// A custom reusable widget that displays a label, subtitle, and a toggle switch.
/// It is wrapped in an AppCard for consistent styling.
class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Label and Subtitle on the left
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          // The toggle switch on the right
          Switch(
            value: value,
            activeThumbColor: Colors.black,
            activeTrackColor: AppColors.gold,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.surface,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}