import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'cards.dart';

class ManageAvailabilityScreen extends StatefulWidget {
  const ManageAvailabilityScreen({super.key});
  @override
  State<ManageAvailabilityScreen> createState() => _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  final Map<String, bool> _days = {
    'Monday': true, 'Tuesday': true, 'Wednesday': true,
    'Thursday': true, 'Friday': true, 'Saturday': true, 'Sunday': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Manage Availability'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Working Days',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._days.keys.map((d) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Text(d, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                      const Spacer(),
                      Switch(
                        value: _days[d]!,
                        activeThumbColor: AppColors.gold,
                        activeTrackColor: AppColors.gold.withValues(alpha: 0.35),
                        onChanged: (v) => setState(() => _days[d] = v),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            const Text('Working Hours',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const AppCard(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _TimeField(label: 'Start', value: '09:00')),
                  SizedBox(width: 12),
                  Expanded(child: _TimeField(label: 'End', value: '18:00')),
                ],
              ),
            ),
            const SizedBox(height: 26),
            GoldButton(
              label: 'Save Changes',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Availability updated'),
                    backgroundColor: AppColors.surfaceAlt,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label, value;
  const _TimeField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10,
                letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            const Icon(Icons.access_time, color: AppColors.gold, size: 16),
          ],
        ),
      ],
    );
  }
}