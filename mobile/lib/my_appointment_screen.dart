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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';                   // Custom colors and styles
import 'badges.dart';                      // StatusBadge widget
import 'cards.dart';                       // AppCard widget
import 'appointment_details_screen.dart';  // Screen to view full booking details
import 'stylist_session.dart';             // Helper to get the current stylist's ID

/// A screen that displays all appointments for the logged-in stylist.
/// It uses a TabBar to separate appointments into Upcoming, Completed, and Cancelled.
/// It also features a background timer to automatically refresh the data.
class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});
  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

// Using SingleTickerProviderStateMixin because we are using a TabController
class _MyAppointmentsScreenState extends State<MyAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  
  // TabController manages the switching between the 3 tabs
  late final TabController _tab = TabController(length: 3, vsync: this);

  dynamic _stylistId;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  
  // Timer used to periodically fetch new appointments in the background
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Initializes the screen by resolving the stylist ID, loading data, and starting the auto-refresh timer.
  Future<void> _init() async {
    _stylistId = await StylistSession.resolve();
    if (!mounted) return;
    
    if (_stylistId == null) {
      setState(() {
        _error = 'This account is not linked to a stylist profile.';
        _loading = false;
      });
      return;
    }
    
    await _load();
    
    // Set up a timer to silently refresh the data every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _load(silent: true);
    });
  }

  /// Fetches all bookings for this stylist from the database.
  /// It fetches the bookings first, then fetches the customer profiles separately.
  Future<void> _load({bool silent = false}) async {
    if (_stylistId == null) return;
    if (!silent && mounted) setState(() => _loading = true);
    
    try {
      // 1. Fetch bookings joined with the 'services' table
      final rows = await _supabase
          .from('bookings')
          .select('booking_id, customer_id, appointment_date, start_time, end_time, status, cancellation_reason, services(name)')
          .eq('stylist_id', _stylistId)
          .order('appointment_date', ascending: false)
          .order('start_time', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows);

      // 2. Extract unique customer IDs to fetch their profiles
      final customerIds = list
          .map((b) => b['customer_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (customerIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('id, full_name, phone')
            .inFilter('id', customerIds);

        final profileMap = { for (var p in profiles) p['id']: p };

        // 3. Attach the customer profile data to each booking
        for (var b in list) {
          b['customer_profile'] = profileMap[b['customer_id']];
        }
      }

      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Updates the status of a booking (e.g., to 'completed', 'no_show', or 'cancelled').
  Future<void> _updateStatus(String bookingId, String status, {String? reason}) async {
    try {
      final patch = <String, dynamic>{'status': status};
      if (reason != null) patch['cancellation_reason'] = reason;
      
      await _supabase
          .from('bookings')
          .update(patch)
          .eq('booking_id', bookingId);
          
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Booking marked as ${status.replaceAll('_', ' ')}'),
          backgroundColor: AppColors.success));
      
      _load(); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not update: $e'),
          backgroundColor: AppColors.error));
    }
  }

  /// Shows a dialog asking the stylist to provide a reason for cancelling.
  Future<void> _showCancelDialog(String bookingId) async {
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
            hintText: 'Reason for cancellation...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirm Cancel', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    
    if (ok == true) {
      await _updateStatus(bookingId, 'cancelled', reason: ctrl.text.trim());
    }
    ctrl.dispose();
  }

  /// Filters the full list of appointments based on which tab is selected.
  /// Tab 0: Upcoming (confirmed, booked, pending)
  /// Tab 1: Completed & No-show
  /// Tab 2: Cancelled
  List<Map<String, dynamic>> _filter(int tabIndex) {
    String s(Map<String, dynamic> b) => b['status']?.toString().toLowerCase().trim() ?? '';

    switch (tabIndex) {
      case 0: // UPCOMING
        return _all.where((b) {
          final status = s(b);
          return status == 'confirmed' || status == 'booked' || status == 'pending';
        }).toList();
        
      case 1: // COMPLETED & NO-SHOW
        return _all.where((b) {
          final status = s(b);
          return status.contains('complet') || status == 'done' || status.contains('no_show') || status.contains('noshow'); 
        }).toList();
        
      default: // CANCELLED ONLY
        return _all.where((b) {
          final status = s(b);
          return status.contains('cancel');
        }).toList();
    }
  }

  @override
  void dispose() {
    // Clean up the timer and tab controller to free up memory
    _refreshTimer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY APPOINTMENTS'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, size: 20), onPressed: () => _load()),
        ],
        // The TabBar sits at the bottom of the AppBar
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'UPCOMING'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'CANCELLED'),
          ],
        ),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : TabBarView(
                  controller: _tab,
                  // Generate the content for each tab dynamically
                  children: List.generate(3, (i) {
                    final list = _filter(i);
                    
                    // Show a message if there are no appointments in this specific tab
                    if (list.isEmpty) {
                      return Center(
                        child: Text('No appointments in this tab', style: const TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    
                    return RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.gold,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: list.map((b) {
                          final status = b['status']?.toString().toLowerCase().trim() ?? '';
                          final isActive = status == 'confirmed' || status == 'booked' || status == 'pending';
                          
                          return _AppointmentCard(
                            booking: b,
                            onRefresh: () => _load(silent: true),
                            // Only show action buttons if the appointment is active
                            onComplete: isActive ? () => _updateStatus(b['booking_id'], 'completed') : null,
                            onNoShow: isActive ? () => _updateStatus(b['booking_id'], 'no_show') : null,
                            onCancel: isActive ? () => _showCancelDialog(b['booking_id']) : null,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ),
    );
  }
}

/// A custom widget that displays the details of a single appointment as a card.
class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onComplete;
  final VoidCallback? onNoShow;
  final VoidCallback? onCancel;
  final VoidCallback onRefresh;

  const _AppointmentCard({
    required this.booking,
    required this.onRefresh,
    this.onComplete,
    this.onNoShow,
    this.onCancel,
  });

  /// Formats a date string (ISO format) into a readable format (e.g., "24 Oct 2026").
  String _fmtDate(String iso) {
    final d = DateTime.parse(iso);
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  /// Determines the color of the status badge based on the booking status.
  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('complet')) return AppColors.gold; 
    if (s.contains('cancel') || s.contains('no_show') || s.contains('noshow')) return AppColors.error;
    return AppColors.success;
  }

  /// Converts a database status string (e.g., "no_show") into a pretty title (e.g., "No Show").
  String _prettyStatus(String s) {
    return s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    // Extract all necessary data from the booking map
    final status = booking['status'] as String? ?? 'confirmed';
    final profile = booking['customer_profile'] as Map<String, dynamic>?;
    final customerName = profile?['full_name'] ?? 'Client';
    final service = booking['services'] as Map<String, dynamic>?;
    final date = booking['appointment_date'] as String? ?? '';
    final time = (booking['start_time'] as String? ?? '00:00');
    final shortTime = time.length >= 5 ? time.substring(0, 5) : time;
    final reason = booking['cancellation_reason'] as String?;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Customer Name and Status Badge
          Row(children: [
            Expanded(child: Text(customerName, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800))),
            StatusBadge(text: _prettyStatus(status), color: _statusColor(status)),
          ]),
          const SizedBox(height: 6),
          
          // Service Name
          Text(service?['name'] ?? 'Service', style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          
          // Date and Time
          Row(children: [
            const Icon(Icons.access_time, color: AppColors.textSecondary, size: 14),
            const SizedBox(width: 6),
            Text('${_fmtDate(date)} · $shortTime', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ]),
          
          // Cancellation Reason (only shows if a reason exists)
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35))),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 14),

          // Action Buttons (Cancel, No-show, Complete) - Only visible for active appointments
          if (onComplete != null) ...[
            Row(children: [
              if (onCancel != null)
                Expanded(child: _Pill(label: 'Cancel', color: AppColors.error, onTap: onCancel!)),
              const SizedBox(width: 8),
              if (onNoShow != null)
                Expanded(child: _Pill(label: 'No-show', color: AppColors.gold, onTap: onNoShow!)),
              const SizedBox(width: 8),
              if (onComplete != null)
                Expanded(child: _Pill(label: 'Complete', color: AppColors.success, onTap: onComplete!)),
            ]),
          ],

          const SizedBox(height: 8),
          
          // View Details Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(booking: booking)));
                onRefresh(); // Refresh the list when returning from details
              },
              child: const Text('View Details', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill-shaped button used for actions like Cancel, No-show, and Complete.
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}