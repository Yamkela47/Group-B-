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
import 'app_theme.dart';          // Custom colors and styles
import 'app_bars.dart';           // Custom AppBar widget
import 'contact_support_screen.dart'; // Screen for sending a message to the salon

/// A static screen that provides users with answers to frequently asked questions 
/// and a direct button to contact the salon's support team.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Help & Support'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ==========================================
          // HEADER SECTION
          // ==========================================
          const Text(
            'How can we help you?',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find answers to common questions or reach out to our team.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // ==========================================
          // CONTACT SUPPORT BUTTON
          // ==========================================
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              // Navigates to the form where users can type a message to the manager
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
              ),
              icon: const Icon(Icons.support_agent, size: 20),
              label: const Text('Contact Support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // ==========================================
          // FAQ SECTION HEADER
          // ==========================================
          const Text(
            'FREQUENTLY ASKED QUESTIONS',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          // ==========================================
          // FAQ LIST
          // ==========================================
          _FaqItem(
            question: 'How do I book an appointment?',
            answer: 'Navigate to the Services tab, select your desired service, choose a stylist, pick an available date and time, and click "Confirm Booking".',
          ),
          _FaqItem(
            question: 'Can I reschedule my booking?',
            answer: 'Yes. Go to "My Bookings", find your upcoming appointment, and tap "Reschedule". You can select a new date and time based on the stylist\'s availability.',
          ),
          _FaqItem(
            question: 'How do I cancel my appointment?',
            answer: 'Go to "My Bookings", tap "Cancel" on the upcoming appointment, and provide a brief reason. Your slot will immediately become available to others.',
          ),
          _FaqItem(
            question: 'What payment methods do you accept?',
            answer: 'We accept both Cash and Card. You can select your preferred method during booking, but payment is made physically at the salon upon arrival.',
          ),
          _FaqItem(
            question: 'Where is the salon located?',
            answer: 'We are located at 10 Melck Street, Pioneer Building, Welkom Central. You can tap "Find Us" on the home screen to open Google Maps.',
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/* ===================================================================
   FAQ ITEM WIDGET (Expandable)
   =================================================================== */
/// A custom reusable widget that builds an expandable FAQ card.
/// It uses the `ExpansionTile` widget to show the question and reveal the answer on tap.
class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      // Override the default theme of ExpansionTile to remove the ugly divider lines
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.gold,               // Color of the arrow when expanded
          collapsedIconColor: AppColors.textSecondary, // Color of the arrow when collapsed
          title: Text(
            question,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          // The content that shows when the tile is expanded
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}