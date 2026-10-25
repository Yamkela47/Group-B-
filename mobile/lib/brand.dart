/*
===========================================================
PROJECT: Cutting Edge Salon
STUDENT DETAILS:
-----------------------------------------------------------
Name                  | Student Number
-----------------------------------------------------------
Goitse Kgwele         | 221050663
Thabang Zitha         | 223007074
Yamkela Mazamani      | 224007421
Nyakallo Pali         | 223060226
Bennet Linda          | 224004294
===========================================================
*/

import 'package:flutter/material.dart';
import 'app_theme.dart'; // Custom colors like AppColors.gold and textSecondary

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
      // Sets the width and height dynamically based on the 'size' parameter
      width: size,
      height: size,
      
      // Creates a circular container with a gold border and black background
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 1.8),
        color: Colors.black,
      ),
      
      // ClipOval crops the image into a circle.
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.jpeg',  // ← put your logo here later
          width: size,
          height: size,
          fit: BoxFit.cover, // Ensures the image fills the circular area
          
          // Fallback icon if logo.jpeg is missing:
          errorBuilder: (context, error, stack) => Center(
            child: Icon(
              Icons.content_cut, // Scissors icon as a placeholder
              color: AppColors.gold,
              size: size * 0.42, // Icon size scales with the container size
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
      mainAxisSize: MainAxisSize.min, // Column takes up minimum vertical space
      children: [
        // Displays the circular brand logo
        BrandLogo(size: logoSize),
        const SizedBox(height: 12), // Spacing
        
        // Main brand name
        const Text(
          'CUTTING EDGE',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
          ),
        ),
        
        // Conditionally displays the slogan if showSubtitle is true
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
      mainAxisSize: MainAxisSize.min, // Row takes up minimum horizontal space
      children: [
        // Logo placeholder (or real image if present)
        BrandLogo(size: logoSize),
        const SizedBox(width: 12), // Spacing between logo and text

        // Brand name + slogan stacked vertically
        Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Aligns text to the left
          mainAxisSize: MainAxisSize.min,
          children: const [
            // Brand name
            Text(
              'CUTTING EDGE',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            SizedBox(height: 2), // Tiny spacing
            
            // Slogan
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