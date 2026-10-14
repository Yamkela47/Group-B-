import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'bottom_nav.dart';
import 'cards.dart';
import 'notifications_screen.dart';
import 'my_profile_screen.dart';
import 'my_appointment_screen.dart';
import 'daily_schedule_screen.dart';
import 'manage_availability_screen.dart';
import 'blocked_dates_screen.dart';

class StylistHomeScreen extends StatefulWidget {
  const StylistHomeScreen({super.key});
  @override
  State<StylistHomeScreen> createState() => _StylistHomeScreenState();
}

class _StylistHomeScreenState extends State<StylistHomeScreen> {
  int _nav = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
        onBell: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            const Text('Good Morning, Nqobile',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Monday, 21 September 2026',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withOpacity(0.35)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.gold.withOpacity(0.12), AppColors.surfaceAlt],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("TODAY'S APPOINTMENTS",
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 10,
                                letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                        SizedBox(height: 6),
                        Text('3',
                            style: TextStyle(
                                color: AppColors.gold, fontSize: 36, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Next at 10:30 · Cut & Dye',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withOpacity(0.12),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.event_available, color: AppColors.gold, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeading(text: 'Quick Actions'),
            _ActionRow(icon: Icons.calendar_month_outlined, title: 'My Appointments',
                subtitle: 'View upcoming and completed jobs', screen: const MyAppointmentsScreen()),
            _ActionRow(icon: Icons.schedule_outlined, title: 'Daily Schedule',
                subtitle: 'See your bookings for today', screen: const DailyScheduleScreen()),
            _ActionRow(icon: Icons.tune_outlined, title: 'Manage Availability',
                subtitle: 'Set your working days and hours', screen: const ManageAvailabilityScreen()),
            _ActionRow(icon: Icons.block_outlined, title: 'Blocked Dates',
                subtitle: 'Mark days you are unavailable', screen: const BlockedDatesScreen()),
            _ActionRow(icon: Icons.person_outline, title: 'My Profile',
                subtitle: 'Update your details', screen: const MyProfileScreen()),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        index: _nav,
        onChanged: (i) {
          if (i == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DailyScheduleScreen()));
          } else if (i == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MyProfileScreen()));
          } else {
            setState(() => _nav = i);
          }
        },
        items: const [
          BottomNavItem(Icons.home_outlined, 'Home'),
          BottomNavItem(Icons.schedule_outlined, 'Schedule'),
          BottomNavItem(Icons.person_outline, 'Profile'),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget screen;
  const _ActionRow({
    required this.icon, required this.title,
    required this.subtitle, required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => screen)),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}