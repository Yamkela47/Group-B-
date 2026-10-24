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
import 'app_theme.dart'; // Imports custom colors and themes (like AppColors.gold)
import 'app_bars.dart'; // Imports custom app bars (like ScreenAppBar)

/// The AboutUsScreen is a StatelessWidget because the content on this page
/// is static and does not change dynamically based on user interaction.
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Custom App Bar with the title "About Us"
      appBar: const ScreenAppBar(title: 'About Us'),
      
      // SingleChildScrollView allows the page to scroll if the content exceeds the screen height
      body: SingleChildScrollView(
        child: Column(
          // Stretch ensures the children take up the full width of the screen
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // about us image 
            // ==========================================
            // Stack allows us to place widgets on top of each other.
            // Here, we place a gradient overlay on top of the image.
            Stack(
              children: [
                // The main hero image of the salon
                Image.asset(
                  'assets/images/aboutUs.jpeg', //  new image path
                  height: 280,
                  width: double.infinity, // Takes full width
                  fit: BoxFit.cover, // Ensures the image fills the space without stretching
                  
                  // errorBuilder handles the scenario where the image fails to load
                  errorBuilder: (context, error, stack) => Container(
                    height: 280,
                    color: AppColors.surfaceAlt, // Fallback background color
                    child: const Center(
                      // Fallback icon if image is missing
                      child: Icon(Icons.storefront, color: AppColors.gold, size: 60),
                    ),
                  ),
                ),
                
                // Optional: A dark gradient at the bottom so the text below blends nicely
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      // Creates a fade effect from transparent to black at the bottom of the image
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Main content padding
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Aligns text to the left
                children: [
                  // Title
                  const Text(
                    'Welcome to Cutting Edge',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8), // Spacing
                  
                  // Subtitle
                  const Text(
                    'Our Vision. Your Style.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic, // Italic style for the slogan
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  // A horizontal line to separate the header from the story
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 24),

                  // Story Paragraph 1
                  const Text(
                    'Established in 2022, Cutting Edge was born from a simple idea: to provide the men, women, and children of Welkom Central with a premium, luxury grooming experience that doesn\'t compromise on quality.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6), // height 1.6 makes it readable
                  ),
                  const SizedBox(height: 16),
                  
                  // Story Paragraph 2
                  const Text(
                    'We understand that your hair is your crown. That is why our team of dedicated, highly skilled stylists is committed to precision, creativity, and making you feel confident every time you sit in our chairs. From classic standard haircuts to our flagship Cut & Dye transformations, we treat every appointment as a work of art.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Feature Highlights
                  // Calling the helper method to build list items
                  _buildFeatureRow(Icons.star_outline, 'Premium Services', 'From hot towel treatments to custom colouring.'),
                  _buildFeatureRow(Icons.groups_outlined, 'Expert Team', 'Stylists who specialise in all hair types and styles.'),
                  _buildFeatureRow(Icons.location_on_outlined, 'Welkom Central', 'Proudly serving our local community at 10 Melck Street.'),

                  const SizedBox(height: 40),

                  // Contact Section (Call to Action Box)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                      // Semi-transparent gold border
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.content_cut, color: AppColors.gold, size: 30),
                        SizedBox(height: 12),
                        Text(
                          'Ready for a fresh look?',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Book your appointment today and let us elevate your style.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget for the feature list.
  /// This reduces code duplication by allowing us to create multiple
  /// feature rows with different icons and text using the same layout.
  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16), // Space below each feature
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Aligns icon to the top of the text
        children: [
          // The Icon on the left
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(width: 14), // Space between icon and text
          
          // Expanded makes sure the text doesn't overflow the screen width
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Feature Title
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                // Feature Subtitle
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}