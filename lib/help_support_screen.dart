import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'cards.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Help & Support'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _HelpTile(icon: Icons.help_outline, title: 'FAQ'),
          _HelpTile(icon: Icons.support_agent, title: 'Contact Support'),
          _HelpTile(icon: Icons.feedback_outlined, title: 'Report an Issue'),
          _HelpTile(icon: Icons.info_outline, title: 'About Cutting Edge'),
          SizedBox(height: 24),
          Text('Popular Topics',
              style: TextStyle(
                  color: AppColors.gold, fontSize: 11,
                  letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          _TopicCard(title: 'How to book an appointment'),
          _TopicCard(title: 'How to cancel a booking'),
          _TopicCard(title: 'Payment methods explained'),
          _TopicCard(title: 'Salon operating hours'),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _HelpTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      onTap: () {},
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final String title;
  const _TopicCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}