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
import 'app_theme.dart';           // Custom colors and styles
import 'buttons.dart';            // Custom GoldButton and GhostButton
import 'catalog_image.dart';      // Custom image widget with error handling
import 'my_bookings_screen.dart'; // Screen to view all bookings
import 'customer_home_screen.dart'; // Main home screen for customers

/// A success screen displayed after a user successfully books an appointment.
/// It shows a summary of the booking details and prevents the user from
/// navigating back to the payment screen using the physical back button.
class BookingConfirmedScreen extends StatefulWidget {
  // Booking details passed from the previous screen
  final String bookingId;
  final String service;
  final String serviceImagePath;
  final String stylist;
  final String date;
  final String time;
  final String payment;
  final String total;

  const BookingConfirmedScreen({
    super.key,
    this.bookingId = '—', // Default fallback values just in case
    this.service = 'Standard Haircut',
    this.serviceImagePath = '',
    this.stylist = 'Nqobile',
    this.date = '26 Sep 2026',
    this.time = '14:00',
    this.payment = 'Cash',
    this.total = 'R140',
  });

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen> {
  
  @override
  void initState() {
    super.initState();
    // 👇 Trigger the popup notification when the screen loads
    // We use addPostFrameCallback to ensure the widget is fully built 
    // before trying to show the SnackBar (which requires a valid context).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification: Booking Confirmed!'),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    });
  }

  /// A helper getter to create a short, readable reference number from the UUID.
  /// It removes dashes and returns the first 8 characters in uppercase.
  String get _shortRef {
    if (widget.bookingId == '—' || widget.bookingId.isEmpty) return '—';
    final cleaned = widget.bookingId.replaceAll('-', '');
    final short = cleaned.length >= 8 ? cleaned.substring(0, 8) : cleaned;
    return short.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents the user from using the device's physical back button 
    // (or swipe gesture) to return to the payment screen.
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Hides the default back arrow
          title: const SizedBox.shrink(),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Success checkmark icon inside a gold circle
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: const Icon(Icons.check, color: AppColors.gold, size: 40),
              ),
              const SizedBox(height: 26),

              // Success text
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

              // ==========================================
              // BOOKING DETAILS CARD
              // ==========================================
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
                    const Text(
                      'Booking Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Side: Service Image & Title
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CatalogImage(
                                source: widget.serviceImagePath,
                                width: 110,
                                height: 140,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 110,
                              child: Text(
                                widget.service,
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
                        
                        // Right Side: Detailed Rows
                        Expanded(
                          child: Column(
                            children: [
                              _DetailRow(
                                  icon: Icons.content_cut,
                                  label: 'Service',
                                  value: widget.service),
                              const _RowDivider(),
                              _DetailRow(
                                  icon: Icons.person_outline,
                                  label: 'Stylist',
                                  value: widget.stylist),
                              const _RowDivider(),
                              _DetailRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Date',
                                  value: widget.date),
                              const _RowDivider(),
                              _DetailRow(
                                  icon: Icons.access_time,
                                  label: 'Time',
                                  value: widget.time),
                              const _RowDivider(),
                              _DetailRow(
                                  icon: Icons.credit_card,
                                  label: 'Payment',
                                  value: widget.payment),
                              const _RowDivider(),
                              _DetailRow(
                                  icon: Icons.local_offer_outlined,
                                  label: 'Total',
                                  value: widget.total,
                                  valueIsGold: true),
                              const _RowDivider(),
                              _DetailRow(
                                  icon: Icons.confirmation_number_outlined,
                                  label: 'Ref',
                                  value: '#$_shortRef',
                                  valueIsGold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ==========================================
              // IMPORTANT INFO CARD
              // ==========================================
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

              // ==========================================
              // ACTION BUTTONS
              // ==========================================
              GoldButton(
                label: 'View My Bookings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              GhostButton(
                label: 'Back to Home',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerHomeScreen()),
                  (route) => false, // Clears the navigation stack
                ),
              ),
              const SizedBox(height: 20),

              // Footer text
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
      ),
    );
  }
}

/// A custom widget used to display a single row in the booking details card.
/// It contains an icon, a label (left), and a value (right).
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool valueIsGold; // Determines if the value text should be gold

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
              textAlign: TextAlign.right, // Aligns the value to the right side
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

/// A custom widget for a thin, semi-transparent gold divider line.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.gold.withValues(alpha: 0.25),
    );
  }
}