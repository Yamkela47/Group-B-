import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';   // ScreenAppBar
import 'buttons.dart';    // GoldButton, GhostButton
import 'cards.dart';      // AppCard

class AppointmentDetailsScreen extends StatelessWidget {
  const AppointmentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Appointment Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withOpacity(0.12),
                      border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.person, color: AppColors.gold, size: 30),
                  ),
                  const SizedBox(height: 12),
                  const Text('Lethabo Kgame',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Client',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: const [
                  _DetailRow(label: 'Service', value: 'Cut & Dye'),
                  Divider(height: 22),
                  _DetailRow(label: 'Date', value: '21 September 2026'),
                  Divider(height: 22),
                  _DetailRow(label: 'Time', value: '10:30 – 11:45'),
                  Divider(height: 22),
                  _DetailRow(label: 'Duration', value: '1h 15min'),
                  Divider(height: 22),
                  _DetailRow(label: 'Payment', value: 'Cash on arrival'),
                  Divider(height: 22),
                  _DetailRow(label: 'Phone', value: '071 234 5678'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GoldButton(label: 'Contact Client', onPressed: () {}),
            const SizedBox(height: 12),
            GhostButton(
              label: 'Back to Appointments',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12.5)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}