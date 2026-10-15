import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'cards.dart';
import 'notification_details_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Notifications'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _NotifyRow(
            icon: Icons.calendar_month_outlined,
            title: 'New booking assigned',
            time: '20 min ago',
            unread: true,
          ),
          const _NotifyRow(
            icon: Icons.check_circle_outline,
            title: 'Appointment confirmed',
            time: '1 hour ago',
            unread: true,
          ),
          const _NotifyRow(
            icon: Icons.schedule_outlined,
            title: 'Upcoming appointment reminder',
            time: '3 hours ago',
          ),
          const _NotifyRow(
            icon: Icons.star_outline,
            title: 'Special offer this weekend',
            time: 'Yesterday',
          ),
        ],
      ),
    );
  }
}

class _NotifyRow extends StatelessWidget {
  final IconData icon;
  final String title, time;
  final bool unread;
  const _NotifyRow({
    required this.icon, required this.title,
    required this.time, this.unread = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const NotificationDetailsScreen())),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    )),
                const SizedBox(height: 3),
                Text(time,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          if (unread)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppColors.gold, shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}