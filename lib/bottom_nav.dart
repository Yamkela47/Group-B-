import 'package:flutter/material.dart';
import 'app_theme.dart';

class BottomNavItem {
  final IconData icon;
  final String label;
  const BottomNavItem(this.icon, this.label);
}

class BottomNav extends StatelessWidget {
  final int index;
  final List<BottomNavItem> items;
  final ValueChanged<int> onChanged;
  const BottomNav({
    super.key, required this.index,
    required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon,
                          color: selected ? AppColors.gold : AppColors.textMuted,
                          size: 20),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected ? AppColors.gold : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}