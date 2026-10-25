import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'cards.dart';

class BlockedDatesScreen extends StatelessWidget {
  const BlockedDatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Blocked Dates'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calendar_today_outlined, color: AppColors.gold, size: 16),
                      SizedBox(width: 8),
                      Text('September 2026',
                          style: TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MiniCalendar(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeading(text: 'Your Blocked Dates'),
            const _BlockedItem(date: 'Tue, 1 Sep 2026'),
            const _BlockedItem(date: 'Thu, 17 Sep 2026'),
            const _BlockedItem(date: 'Wed, 30 Sep 2026'),
            const SizedBox(height: 22),
            GoldButton(label: 'Block a New Date', icon: Icons.add, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class _MiniCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final days = List.generate(35, (i) => i + 1);
    return Column(
      children: [
        Row(
          children: labels
              .map((l) => Expanded(
                    child: Center(
                      child: Text(l,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4,
          ),
          itemCount: 35,
          itemBuilder: (_, i) {
            final day = days[i];
            final blocked = day == 1 || day == 17 || day == 30;
            final isToday = day == 21;
            return Container(
              decoration: BoxDecoration(
                color: blocked
                    ? AppColors.gold.withValues(alpha: 0.18)
                    : (isToday ? AppColors.gold.withValues(alpha: 0.08) : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: blocked
                      ? AppColors.gold.withValues(alpha: 0.6)
                      : (isToday ? AppColors.gold : AppColors.border),
                ),
              ),
              child: Center(
                child: Text('$day',
                    style: TextStyle(
                      color: blocked ? AppColors.gold : Colors.white,
                      fontSize: 11,
                      fontWeight: blocked || isToday ? FontWeight.w800 : FontWeight.w500,
                    )),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BlockedItem extends StatelessWidget {
  final String date;
  const _BlockedItem({required this.date});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.block, color: AppColors.gold, size: 18),
          const SizedBox(width: 12),
          Text(date, style: const TextStyle(color: Colors.white, fontSize: 13)),
          const Spacer(),
          const Icon(Icons.close, color: AppColors.textSecondary, size: 16),
        ],
      ),
    );
  }
}
