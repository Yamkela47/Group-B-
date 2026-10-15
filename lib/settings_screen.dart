import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'cards.dart';
import 'logout_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifs = true;
  bool _emailNotifs = true;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('NOTIFICATIONS',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _SwitchRow(
            label: 'Push Notifications',
            value: _pushNotifs,
            onChanged: (v) => setState(() => _pushNotifs = v),
          ),
          _SwitchRow(
            label: 'Email Notifications',
            value: _emailNotifs,
            onChanged: (v) => setState(() => _emailNotifs = v),
          ),
          const SizedBox(height: 22),
          const Text('APPEARANCE',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _SwitchRow(
            label: 'Dark Mode',
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          const SizedBox(height: 22),
          const Text('ACCOUNT',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: () {},
            child: const Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.gold, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text('Change Password',
                      style: TextStyle(color: Colors.white, fontSize: 13.5)),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                      style: TextStyle(color: AppColors.error, fontSize: 13.5)),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.label, required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.gold,
            activeTrackColor: AppColors.gold.withValues(alpha: 0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}