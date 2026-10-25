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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart'; // AppColors and text styles
import 'app_bars.dart';  // ScreenAppBar
import 'buttons.dart';   // GhostButton
import 'cards.dart';     // AppCard
import 'badges.dart';    // StatusBadge

/// A detailed view of a specific appointment.
/// This screen is typically used by a stylist or manager to view
/// full details of a booking and take action (mark as complete, no-show, or cancel).
class AppointmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> booking; // The booking data passed from the previous screen
  const AppointmentDetailsScreen({super.key, required this.booking});

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  final _supabase = Supabase.instance.client;
  
  // State to show a loading indicator while updating the database
  bool _isUpdating = false;
  
  // Local copy of the booking data so we can update the UI immediately without refetching
  late Map<String, dynamic> _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  /// Updates the status of the booking in the Supabase database.
  /// 
  /// [status] - The new status (e.g., 'completed', 'no_show', 'cancelled').
  /// [reason] - An optional cancellation reason provided by the user.
  Future<void> _updateStatus(String status, {String? reason}) async {
    setState(() => _isUpdating = true);
    try {
      // Build the payload to update. Only include reason if it was provided.
      final patch = <String, dynamic>{'status': status};
      if (reason != null) patch['cancellation_reason'] = reason;

      // Perform the update in Supabase on the 'bookings' table
      await _supabase
          .from('bookings')
          .update(patch)
          .eq('booking_id', _booking['booking_id']);
      
      if (!mounted) return;
      
      // Update the local state to reflect the change instantly
      setState(() {
        _booking['status'] = status;
        if (reason != null) _booking['cancellation_reason'] = reason;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Booking marked as ${status.replaceAll('_', ' ')}'),
          backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      // Show error message if the database update fails
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Shows an AlertDialog asking the user to confirm cancellation and provide a reason.
  /// If confirmed, it calls [_updateStatus] with the 'cancelled' status and the reason.
  Future<void> _showCancelDialog() async {
    final ctrl = TextEditingController();
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        title: const Text('Cancel Appointment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Reason for cancellation (customer will see this)',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Keep', style: TextStyle(color: AppColors.textSecondary))
          ),
          TextButton(
            onPressed: () {
              // Require a reason before allowing cancellation
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    // If the user clicked "Confirm Cancel" and provided a reason
    if (ok == true) {
      await _updateStatus('cancelled', reason: ctrl.text.trim());
    }
    ctrl.dispose(); // Clean up the controller
  }

  @override
  Widget build(BuildContext context) {
    // Extract the status and determine the state of the booking
    final status = _booking['status'] as String? ?? 'confirmed';
    final isCancelled = status.contains('cancelled');
    final isCompleted = status == 'completed';
    final isNoShow = status == 'no_show';
    
    // A booking is "active" if it hasn't been cancelled, completed, or marked as no-show
    final isActive = !isCancelled && !isCompleted && !isNoShow;

    // Determine the color of the status badge based on the state
    final statusColor = isCancelled || isNoShow 
        ? AppColors.error 
        : isCompleted 
            ? AppColors.success 
            : AppColors.gold;

    // Safely extract nested customer data and booking details
    final profile = _booking['customer_profile'] as Map<String, dynamic>?;
    final customerName = profile?['full_name'] ?? 'Client';
    
    final serviceName = _booking['services']?['name'] ?? 'Service';
    final date = _booking['appointment_date'] ?? 'Unknown Date';
    final time = _booking['start_time'] ?? '00:00';

    return Scaffold(
      appBar: const ScreenAppBar(title: 'Appointment Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // CUSTOMER HEADER CARD
            // ==========================================
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Placeholder icon for the customer's profile picture
                  Container(
                    width: 66, height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.person, color: AppColors.gold, size: 30),
                  ),
                  const SizedBox(height: 12),
                  // Customer Name
                  Text(customerName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  // Status Badge (e.g., CONFIRMED, CANCELLED)
                  StatusBadge(text: status.replaceAll('_', ' ').toUpperCase(), color: statusColor),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // BOOKING INFO CARD
            // ==========================================
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(label: 'Service', value: serviceName),
                  const Divider(height: 22, color: AppColors.border),
                  _DetailRow(label: 'Date', value: date),
                  const Divider(height: 22, color: AppColors.border),
                  // Truncate time to HH:mm format
                  _DetailRow(label: 'Time', value: time.length >= 5 ? time.substring(0, 5) : time),
                  const Divider(height: 22, color: AppColors.border),
                  _DetailRow(label: 'Client Phone', value: profile?['phone'] ?? '—'),
                ],
              ),
            ),
            
            // ==========================================
            // CANCELLATION REASON (if applicable)
            // ==========================================
            if (isCancelled && _booking['cancellation_reason'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Text('Cancellation Reason', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _booking['cancellation_reason'],
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ==========================================
            // ACTION BUTTONS (Only shown if the booking is active)
            // ==========================================
            if (isActive) ...[
              Row(
                children: [
                  Expanded(child: _ActionButton(label: 'CANCEL', color: AppColors.error, onTap: _showCancelDialog)),
                  const SizedBox(width: 10),
                  Expanded(child: _ActionButton(label: 'NO-SHOW', color: AppColors.gold, onTap: () => _updateStatus('no_show'))),
                ],
              ),
              const SizedBox(height: 10),
              _ActionButton(label: 'MARK AS COMPLETED', color: AppColors.success, onTap: () => _updateStatus('completed')),
            ],

            const SizedBox(height: 20),
            
            // Back Button
            GhostButton(
              label: 'Back to Appointments',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// A helper widget to display a label-value pair in a row.
/// Used inside the "Booking Info" card.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
        const Spacer(), // Pushes the value to the far right
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// A custom button used for the Cancel, No-show, and Complete actions.
/// Styled with a transparent background, colored border, and colored text.
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  
  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15), // Very light background tint
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.2), // Solid colored border
        ),
        child: Text(
          label, 
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)
        ),
      ),
    );
  }
}