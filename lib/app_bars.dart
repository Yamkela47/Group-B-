import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'brand.dart';   // BrandTitleRow

/* ===================================================================
   MAIN APP BAR
   Used on the home screens. Hamburger menu on the left,
   brand logo + slogan in the middle, bell on the right.
   =================================================================== */
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenu;
  final VoidCallback? onBell;
  final bool showBellBadge;

  const MainAppBar({
    super.key,
    this.onMenu,
    this.onBell,
    this.showBellBadge = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leadingWidth: 52,
      leading: IconButton(
        icon: const Icon(Icons.menu, size: 22),
        onPressed: onMenu ?? () {},
      ),
      // ---- Brand logo + slogan row ----
      title: const BrandTitleRow(logoSize: 40),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, size: 22),
              onPressed: onBell ?? () {},
            ),
            if (showBellBadge)
              Positioned(
                right: 12,
                top: 14,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }
}

/* ===================================================================
   SCREEN APP BAR
   Used on all inner screens. Back arrow on the left,
   brand row in the middle. Simple and consistent.
   =================================================================== */
class ScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const ScreenAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // The brand row replaces the plain text title.
      title: BrandTitleRow(logoSize: 40),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
    );
  }
}