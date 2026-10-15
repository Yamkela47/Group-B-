import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_bars.dart';       // ScreenAppBar
import 'buttons.dart';       // GoldButton, GhostButton
import 'book_appointment_screen.dart';
import 'our_team_screen.dart'; // TeamMember data class

class TeamMemberProfileScreen extends StatefulWidget {
  final TeamMember member;
  const TeamMemberProfileScreen({super.key, required this.member});

  @override
  State<TeamMemberProfileScreen> createState() =>
      _TeamMemberProfileScreenState();
}

class _TeamMemberProfileScreenState extends State<TeamMemberProfileScreen> {
  // The user's own rating (starts at 0 = nothing picked yet).
  // When they tap a star, this becomes 1..5.
  int _myRating = 0;

  // Small comment that appears after rating
  String _thanksMessage = '';

  // Called when the user taps a star
  void _setRating(int stars) {
    setState(() {
      _myRating = stars;
      _thanksMessage = 'Thanks! You rated ${widget.member.name.split(' ').first} $stars star${stars == 1 ? '' : 's'}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return Scaffold(
      appBar: const ScreenAppBar(title: 'Stylist Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =========================================================
            //  HEADER CARD — big photo, name, role, overall rating
            // =========================================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  // ---- Big circular photo ----
                  ClipOval(
                    child: Image.asset(
                      member.imagePath,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.gold,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ---- Name ----
                  Text(
                    member.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ---- Role ----
                  Text(
                    member.role,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---- Overall rating line ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: AppColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${member.rating.toStringAsFixed(1)} overall',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // =========================================================
            //  BIO
            // =========================================================
            const _SectionLabel(text: 'About'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                member.bio,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // =========================================================
            //  SERVICES
            // =========================================================
            const _SectionLabel(text: 'Services Offered'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: member.services
                  .map((s) => _ServiceChip(label: s))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // =========================================================
            //  RATE THIS STYLIST
            // =========================================================
            const _SectionLabel(text: 'Rate This Stylist'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Text(
                    'How was your experience?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ---- 5 tappable stars ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starValue = i + 1;
                      final filled = starValue <= _myRating;
                      return IconButton(
                        onPressed: () => _setRating(starValue),
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: AppColors.gold,
                          size: 34,
                        ),
                      );
                    }),
                  ),

                  // ---- Thank-you message after tapping ----
                  if (_thanksMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _thanksMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // =========================================================
            //  ACTIONS
            // =========================================================
            GoldButton(
  label: 'Book with ${member.name.split(' ').first}',
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      // Pass the stylist name so the booking screen can pre-select
      // them in the "Choose Stylist" dropdown.
      builder: (_) => BookAppointmentScreen(
        initialStylist: member.name,
      ),
    ),
  ),
),
            const SizedBox(height: 12),
            GhostButton(
              label: 'Back to Team',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/* ===================================================================
   SECTION LABEL
   Small gold uppercase heading used before each section.
   =================================================================== */
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/* ===================================================================
   SERVICE CHIP
   Small gold-bordered pill showing a service name.
   =================================================================== */
class _ServiceChip extends StatelessWidget {
  final String label;
  const _ServiceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}