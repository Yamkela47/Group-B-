import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'cards.dart';

class NotificationDetailsScreen extends StatelessWidget {
  const NotificationDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Notification Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calendar_month_outlined, color: AppColors.gold, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('New booking assigned',
                            style: TextStyle(
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('20 min ago',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                  const Divider(height: 30),
                  const Text('Appointment Details',
                      style: TextStyle(
                          color: AppColors.gold, fontSize: 12,
                          letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const _Row(label: 'Service', value: 'Cut & Dye'),
                  const SizedBox(height: 8),
                  const _Row(label: 'Client', value: 'Lethabo Kgame'),
                  const SizedBox(height: 8),
                  const _Row(label: 'Date', value: 'Tue, 15 Sep 2026'),
                  const SizedBox(height: 8),
                  const _Row(label: 'Time', value: '10:30 – 11:45'),
                  const SizedBox(height: 24),
                  GoldButton(label: 'View Appointment', onPressed: () {}),
                  const SizedBox(height: 10),
                  GhostButton(label: 'Back to Notifications',
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}