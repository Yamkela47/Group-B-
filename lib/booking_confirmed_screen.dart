import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'buttons.dart';
import 'my_bookings_screen.dart';
import 'customer_home_screen.dart';

class BookingConfirmedScreen extends StatelessWidget {
  // ----------------------------------------------------------------
  //  Booking data passed in from the previous screen.
  //  Every field has a sensible default so this screen still works
  //  even if you open it without passing anything (handy while testing).
  // ----------------------------------------------------------------
  final String bookingId;        // NEW — UUID from Supabase
  final String service;
  final String serviceImagePath;
  final String stylist;
  final String date;             // e.g. "26 Sep 2026"
  final String time;             // e.g. "14:00"
  final String payment;          // "Cash" or "Card"
  final String total;            // e.g. "R140"

  const BookingConfirmedScreen({
    super.key,
    this.bookingId = '—',
    this.service = 'Standard Haircut',
    this.serviceImagePath = 'assets/images/service_standard_haircut.jpg',
    this.stylist = 'Nqobile',
    this.date = '26 Sep 2026',
    this.time = '14:00',
    this.payment = 'Cash',
    this.total = 'R140',
  });

  /// Turns a UUID like "a1b2c3d4-e5f6-..." into a short
  /// human-readable reference like "A1B2C3D4".
  String get _shortRef {
    if (bookingId == '—' || bookingId.isEmpty) return '—';
    final cleaned = bookingId.replaceAll('-', '');
    final short = cleaned.length >= 8 ? cleaned.substring(0, 8) : cleaned;
    return short.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 12),

            /* =====================================================
               SUCCESS CHECKMARK
               ===================================================== */
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Icon(Icons.check, color: AppColors.gold, size: 40),
            ),
            const SizedBox(height: 26),

            /* =====================================================
               TITLE + SUBTITLES
               ===================================================== */
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your appointment has been successfully booked.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'We look forward to seeing you!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),

            /* =====================================================
               BOOKING DETAILS CARD
               ===================================================== */
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /* ---- Card title ---- */
                  const Text(
                    'Booking Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  /* ---- Two-column layout: photo | rows ---- */
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /* ============================================
                         LEFT: service photo + service name
                         ============================================ */
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              serviceImagePath,
                              width: 110,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  Container(
                                width: 110,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.gold.withOpacity(0.5),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.content_cut,
                                        color: AppColors.gold, size: 28),
                                    SizedBox(height: 8),
                                    Text(
                                      'service\nphoto',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 110,
                            child: Text(
                              service,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      /* ============================================
                         RIGHT: detail rows
                         ============================================ */
                      Expanded(
                        child: Column(
                          children: [
                            _DetailRow(
                              icon: Icons.content_cut,
                              label: 'Service',
                              value: service,
                            ),
                            const _RowDivider(),
                            _DetailRow(
                              icon: Icons.person_outline,
                              label: 'Stylist',
                              value: stylist,
                            ),
                            const _RowDivider(),
                            _DetailRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Date',
                              value: date,
                            ),
                            const _RowDivider(),
                            _DetailRow(
                              icon: Icons.access_time,
                              label: 'Time',
                              value: time,
                            ),
                            const _RowDivider(),
                            _DetailRow(
                              icon: Icons.credit_card,
                              label: 'Payment',
                              value: payment,
                            ),
                            const _RowDivider(),
                            _DetailRow(
                              icon: Icons.local_offer_outlined,
                              label: 'Total',
                              value: total,
                              valueIsGold: true,
                            ),
                            const _RowDivider(),
                            _DetailRow(
                              icon: Icons.confirmation_number_outlined,
                              label: 'Ref',
                              value: '#$_shortRef',
                              valueIsGold: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            /* =====================================================
               IMPORTANT NOTICE
               ===================================================== */
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.gold, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Important',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please arrive 5 minutes before your appointment.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Reschedule or cancel from My Booking.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            /* =====================================================
               ACTIONS
               ===================================================== */
            GoldButton(
              label: 'View My Bookings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MyBookingsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            GhostButton(
              label: 'Back to Home',
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomerHomeScreen()),
                (route) => false,
              ),
            ),
            const SizedBox(height: 20),

            /* =====================================================
               FOOTER
               ===================================================== */
            const Text(
              'Thank you for choosing Cutting Edge!',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

/* ===================================================================
   DETAIL ROW
   =================================================================== */
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool valueIsGold;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueIsGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueIsGold ? AppColors.gold : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================================================================
   Small gold divider between rows.
   =================================================================== */
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.gold.withOpacity(0.25),
    );
  }
}