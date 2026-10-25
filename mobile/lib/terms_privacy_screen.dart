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
import 'app_theme.dart';  // Custom colors and styles
import 'app_bars.dart';   // Custom AppBar widget

/// A static screen that displays the salon's Terms of Service and Privacy Policy.
/// It uses helper methods to format section titles and body paragraphs 
/// consistently throughout the document.
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Terms & Privacy'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Header Title
            const Text(
              'Terms of Service & Privacy Policy',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            
            // Last Updated Date
            const Text(
              'Last Updated: October 2026',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // --- Section 1 ---
            _buildSectionTitle('1. Introduction'),
            _buildParagraph(
              'Welcome to Cutting Edge Salon. By using our mobile application and booking our services, you agree to comply with and be bound by the following terms and conditions. Please read them carefully.',
            ),

            // --- Section 2 ---
            _buildSectionTitle('2. Bookings & Cancellations'),
            _buildParagraph(
              '• All bookings are subject to stylist availability.\n'
              '• We kindly ask that you arrive 5 minutes before your scheduled appointment time.\n'
              '• You may reschedule or cancel your appointment through the app. Cancellations made less than 2 hours before the appointment may incur a penalty or affect your ability to book in the future.',
            ),

            // --- Section 3 ---
            _buildSectionTitle('3. Payment Policy & Non-Payment'),
            _buildParagraph(
              '• We accept Cash and Card payments at the salon upon arrival.\n'
              '• By confirming a booking, you agree to pay the full amount for the service(s) rendered.\n'
              '• **Strict Action on Non-Payment:** If you receive the service and fail to pay, or if you leave the premises without settling your bill, we reserve the right to contact the South African Police Service (SAPS) and lay a charge of theft or fraud. We will also permanently ban the associated account and phone number from using our services.',
            ),

            // --- Section 4 ---
            _buildSectionTitle('4. Privacy Policy (POPIA Compliance)'),
            _buildParagraph(
              'We respect your privacy and are committed to protecting your personal data in accordance with the Protection of Personal Information Act (POPIA).\n\n'
              '• Information We Collect: We collect your name, email address, phone number, and booking history.\n'
              '• How We Use It: Your data is used solely to manage your bookings, send appointment reminders, and notify you of promotions.\n'
              '• Data Sharing: We do not sell your data to third parties. Data is securely stored via our encrypted database provider (Supabase).',
            ),

            // --- Section 5 ---
            _buildSectionTitle('5. User Conduct'),
            _buildParagraph(
              'You agree not to use the app for any unlawful purpose, to harass our staff, or to make fake bookings. We reserve the right to terminate your account without notice if you violate these terms.',
            ),

            // --- Section 6 ---
            _buildSectionTitle('6. Limitation of Liability'),
            _buildParagraph(
              'Cutting Edge Salon is not liable for any allergic reactions to products used during your service. If you have sensitive skin, please inform your stylist prior to your appointment.',
            ),

            // --- Section 7 ---
            _buildSectionTitle('7. Contact Us'),
            _buildParagraph(
              'If you have any questions about these Terms or your privacy, please contact us at:\n\n'
              '📍 10 Melck Street, Pioneer Building, Welkom Central\n'
              '📞 078 767 6599\n'
              '📧 cuttinged@88@gmail.com',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Helper method to build the gold section headings.
  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Helper method to build the white body text for each section.
  /// Includes a specific line height (1.6) to make long paragraphs easier to read.
  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        height: 1.6, // Line height for readability
      ),
    );
  }
}