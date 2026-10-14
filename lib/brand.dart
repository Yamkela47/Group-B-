import 'package:flutter/material.dart';
import 'app_theme.dart';

/* ===================================================================
   BRAND LOGO
   A circular gold-bordered logo. If the image file exists at
   assets/images/logo.png it will show it; otherwise a scissors
   icon placeholder appears (so the app never breaks).
   =================================================================== */
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 1.8),
        color: Colors.black,
      ),
      // ClipOval crops the image into a circle.
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',  // ← put your logo here later
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Fallback icon if logo.png is missing:
          errorBuilder: (context, error, stack) => Center(
            child: Icon(
              Icons.content_cut,
              color: AppColors.gold,
              size: size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================================================================
   BRAND TITLE
   Stacked version: logo on top, brand name, then slogan below.
   Used on splash / login / role-selection screens.
   =================================================================== */
class BrandTitle extends StatelessWidget {
  final double logoSize;
  final bool showSubtitle;
  const BrandTitle({super.key, this.logoSize = 56, this.showSubtitle = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: logoSize),
        const SizedBox(height: 12),
        const Text(
          'CUTTING EDGE',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 3),
          const Text(
            'OUR VISION. YOUR STYLE',   // ← updated slogan
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

/* ===================================================================
   BRAND TITLE ROW  (horizontal version for app bars)
   Logo on the left, then "CUTTING EDGE" + slogan stacked on the right.
   This is what appears at the top of every screen header.
   =================================================================== */
class BrandTitleRow extends StatelessWidget {
  final double logoSize;
  const BrandTitleRow({super.key, this.logoSize = 40});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo placeholder (or real image if present)
        BrandLogo(size: logoSize),
        const SizedBox(width: 12),

        // Brand name + slogan stacked vertically
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'CUTTING EDGE',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'OUR VISION. YOUR STYLE',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}