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
import 'app_theme.dart';       // Custom colors and styles
import 'app_bars.dart';        // Custom AppBar widgets (though AppBar is used directly here)
import 'stylist_session.dart'; // Helper to get the current stylist's ID

/// A screen that displays the daily schedule for the logged-in stylist.
/// It fetches today's bookings and listens for real-time updates (e.g., if a customer cancels).
class DailyScheduleScreen extends StatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  final _supabase = Supabase.instance.client;
  
  // State variables for UI rendering
  bool _loading = true;
  String? _error;
  dynamic _stylistId;
  
  // List to hold today's appointments
  List<Map<String, dynamic>> _appointments = [];
  
  // Subscription to listen for real-time updates on the bookings table
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Initializes the screen by resolving the stylist's ID and loading data.
  Future<void> _init() async {
    // Attempt to get the stylist ID from the session manager
    _stylistId = await StylistSession.resolve();
    if (!mounted) return;
    
    // If no ID is found, show an error
    if (_stylistId == null) {
      setState(() {
        _error = 'Account not linked to a stylist.';
        _loading = false;
      });
      return;
    }
    
    // Load the initial schedule and start listening for changes
    _loadSchedule();
    _subscribeToRealtime();
  }

  /// Subscribes to the Supabase realtime stream for the 'bookings' table.
  /// If any booking for this stylist changes, it silently reloads the schedule.
  void _subscribeToRealtime() {
    // Cancel any existing subscription to prevent memory leaks
    _sub?.cancel();
    
    _sub = _supabase
        .from('bookings')
        .stream(primaryKey: ['booking_id'])
        .eq('stylist_id', _stylistId)
        .listen((_) {
          // When a change is detected, reload the data without showing the big loading spinner
          _loadSchedule(silent: true); 
        });
  }

  /// Fetches the schedule for today.
  /// [silent] determines whether to show the full-screen loading spinner.
  Future<void> _loadSchedule({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 1. Fetch Bookings WITHOUT joining profiles.
      // We select 'status' and 'cancellation_reason' to handle cancelled appointments.
      final data = await _supabase
          .from('bookings')
          .select('booking_id, start_time, status, customer_id, cancellation_reason, services(name)')
          .eq('stylist_id', _stylistId)
          .eq('appointment_date', dateStr)
          .order('start_time', ascending: true);

      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(data);

      // 2. Fetch the customer names separately.
      // This avoids complex nested joins which can sometimes fail in Supabase.
      final customerIds = list.map((b) => b['customer_id']).where((id) => id != null).toSet().toList();
      
      if (customerIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', customerIds);
            
        final profileMap = { for (var p in profiles) p['id']: p };

        // 3. Attach the profile to the booking object
        for (var b in list) {
          b['customer_profile'] = profileMap[b['customer_id']];
        }
      }

      if (!mounted) return;
      setState(() {
        _appointments = list;
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

  /// Formats a DateTime object into a readable string (e.g., "Monday, 24 October 2026").
  String _formatDate(DateTime d) {
    const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const mo = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  @override
  void dispose() {
    // Clean up the real-time subscription when leaving the screen
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('DAILY SCHEDULE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold),
            onPressed: () => _loadSchedule(),
          ),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
        : _error != null 
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadSchedule(),
              color: AppColors.gold,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display today's date at the top
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.gold, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(DateTime.now()),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Conditional rendering: Show empty state if no appointments exist
                    if (_appointments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text('No appointments scheduled today', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                        ),
                      )
                    else
                      // Otherwise, map the appointments to Timeline Items
                      ..._appointments.map((appt) => _TimelineItem(appointment: appt)).toList(),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A custom widget that displays a single appointment in a timeline format.
class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const _TimelineItem({required this.appointment});

  @override
  Widget build(BuildContext context) {
    // Extract data from the appointment map
    final String time = (appointment['start_time'] as String? ?? '00:00').substring(0, 5);
    final String serviceName = appointment['services']?['name'] ?? 'Service';
    final String clientName = appointment['customer_profile']?['full_name'] ?? 'Client';
    
    final String status = (appointment['status'] ?? 'confirmed').toString().toLowerCase();
    final String? reason = appointment['cancellation_reason'] as String?;

    // Determine Colors and Labels based on the appointment status
    Color statusColor = AppColors.gold;
    String statusLabel = 'CONFIRMED';

    if (status.contains('complet')) {
      statusColor = AppColors.success;
      statusLabel = 'COMPLETED';
    } else if (status.contains('cancel')) {
      statusColor = AppColors.error;
      statusLabel = status.contains('stylist') ? 'CANCELLED BY STYLIST' : 'CANCELLED BY CUSTOMER';
    } else if (status.contains('no_show')) {
      statusColor = AppColors.error;
      statusLabel = 'NO SHOW';
    }

    // Format the title (e.g., append "(Cancelled)" if applicable)
    String headerText = serviceName;
    if (statusLabel.contains('CANCELLED')) {
       headerText = '$serviceName (Cancelled)';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Time indicator
        SizedBox(
          width: 60,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              time,
              style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        
        // Right side: The appointment card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row with Title and Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        headerText,
                        style: TextStyle(
                          color: status.contains('cancel') ? AppColors.textMuted : Colors.white, 
                          fontSize: 14, 
                          fontWeight: FontWeight.w800,
                          // Add a strikethrough if the appointment was cancelled
                          decoration: status.contains('cancel') ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // The colored status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Client Name
                Text(
                  clientName,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                
                // If the appointment was cancelled and a reason exists, display it
                if (reason != null && reason.isNotEmpty && status.contains('cancel')) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.error, size: 12),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Reason: $reason',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }
}