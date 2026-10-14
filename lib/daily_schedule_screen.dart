import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';   // ScreenAppBar
import 'cards.dart';      // AppCard

class DailyScheduleScreen extends StatelessWidget {
  const DailyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final slots = [
      ('09:00', 'Available', false),
      ('10:30', 'Lethabo Kgame · Cut & Dye', true),
      ('11:45', 'Thandi Nkosi · Standard Haircut', true),
      ('13:00', 'Lunch break', false),
      ('14:00', 'Bongani Zulu · Beard Shave', true),
      ('15:30', 'Available', false),
      ('16:30', 'Walk-in · Standard Haircut', true),
    ];

    return Scaffold(
      appBar: const ScreenAppBar(title: 'Daily Schedule'),
      body: Column(
        children: [
          // Date header
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: AppColors.gold, size: 16),
                SizedBox(width: 8),
                Text(
                  'Monday, 21 September 2026',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Timeline list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final slot = slots[i];
                return Row(
                  children: [
                    // Time label
                    SizedBox(
                      width: 54,
                      child: Text(
                        slot.$1,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Appointment card
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        color: slot.$3
                            ? AppColors.gold.withOpacity(0.08)
                            : AppColors.surfaceAlt,
                        borderColor: slot.$3
                            ? AppColors.gold.withOpacity(0.35)
                            : AppColors.border,
                        child: Text(
                          slot.$2,
                          style: TextStyle(
                            color: slot.$3
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight:
                                slot.$3 ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}