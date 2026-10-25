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
import 'app_theme.dart';       // Custom colors and themes
import 'app_bars.dart';        // Custom AppBar
import 'cards.dart';           // Custom Card widgets
import 'stylist_session.dart'; // Helper to resolve the current stylist's ID
import 'package:intl/intl.dart'; // For formatting dates

/// A screen that allows a stylist to request leave or block specific dates.
/// Requests are sent to the manager for approval and categorized into 
/// Pending, Approved, and Declined sections. It uses Supabase Realtime 
/// to update the UI instantly when the manager makes a decision.
class BlockedDatesScreen extends StatefulWidget {
  const BlockedDatesScreen({super.key});
  @override
  State<BlockedDatesScreen> createState() => _BlockedDatesScreenState();
}

class _BlockedDatesScreenState extends State<BlockedDatesScreen> {
  final _supabase = Supabase.instance.client;
  
  // Lists to hold the categorized requests
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _approvedBlocks = [];
  List<Map<String, dynamic>> _declinedRequests = [];
  
  bool _loading = true;
  dynamic _stylistId;
  
  // Realtime channel to listen for manager approvals/declines
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Clean up the realtime channel when leaving the screen to prevent memory leaks
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  /// Fetches the leave requests from the database and categorizes them.
  /// 
  /// [showLoading] determines whether to show the full-screen loading spinner.
  /// It is set to false for silent background refreshes (e.g., when realtime triggers).
  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    
    try {
      final id = await StylistSession.resolve();
      if (!mounted) return;
      if (id == null) {
        setState(() => _loading = false);
        return;
      }
      
      // Setup Realtime listener only once per stylist
      if (_stylistId != id) {
        _stylistId = id;
        _setupRealtimeListener(id);
      }

      // Fetch all leave requests for this stylist
      final response = await _supabase
          .from('stylist_leave_requests')
          .select()
          .eq('stylist_id', id)
          .order('requested_date', ascending: false);

      if (!mounted) return;

      final allDates = List<Map<String, dynamic>>.from(response);
      
      // Clear current lists before repopulating
      _pendingRequests.clear();
      _approvedBlocks.clear();
      _declinedRequests.clear();

      // Categorize each request based on its status
      for (var b in allDates) {
        final status = b['status']?.toString().toLowerCase() ?? 'pending';
        
        if (status == 'rejected' || status == 'declined') {
          _declinedRequests.add(b);
        } else if (status == 'approved') {
          _approvedBlocks.add(b);
        } else {
          _pendingRequests.add(b);
        }
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error loading blocked dates: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  /// Sets up a Supabase Realtime listener to watch for changes in the 
  /// 'stylist_leave_requests' table specifically for this stylist.
  void _setupRealtimeListener(dynamic id) {
    // Remove existing channel if any
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }

    _channel = _supabase.channel('stylist_leave_$id');
    
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all, // Listen to inserts, updates, and deletes
      schema: 'public',
      table: 'stylist_leave_requests', 
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'stylist_id',
        value: id,
      ),
      callback: (payload) {
        debugPrint('Realtime change detected! Payload: ${payload.toString()}');
        // Silently reload the lists without showing the full-screen spinner
        _load(showLoading: false);
      },
    ).subscribe();
  }

  /// Opens a series of dialogs for the stylist to request a new block/leave.
  /// It asks for a Start Date, End Date, Request Type, and a Reason.
  Future<void> _requestNewBlock() async {
    final now = DateTime.now();
    
    // 1. Pick Start Date
    final pickedStartDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: Colors.black,
            surface: AppColors.surfaceAlt,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedStartDate == null || !mounted) return;

    // 2. Pick End Date (cannot be before Start Date)
    final pickedEndDate = await showDatePicker(
      context: context,
      initialDate: pickedStartDate,
      firstDate: pickedStartDate,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: Colors.black,
            surface: AppColors.surfaceAlt,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedEndDate == null || !mounted) return;

    // 3. Ask for Request Type and Reason
    String selectedType = 'leave'; 
    final TextEditingController reasonController = TextEditingController();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        // StatefulBuilder allows the dialog to update its own state (like the dropdown)
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceAlt,
              title: const Text('Request Leave', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('d MMM').format(pickedStartDate)} - ${DateFormat('d MMM yyyy').format(pickedEndDate)}',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    const Text('Request Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          dropdownColor: AppColors.surfaceAlt,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'leave', 
                              child: Text('Leave (Day Off, Sick, etc.)')
                            ),
                            DropdownMenuItem(
                              value: 'block_date', 
                              child: Text('Block Specific Date (Emergency)')
                            ),
                          ],
                          onChanged: (String? val) {
                            if (val != null) {
                              setStateDialog(() {
                                selectedType = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Reason (Min 5 characters)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Provide a reason for the manager...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validation: Ensure the reason is at least 5 characters long
                    if (reasonController.text.trim().length < 5) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Reason must be at least 5 characters.'),
                        backgroundColor: AppColors.error,
                      ));
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                  child: const Text('Send Request'),
                ),
              ],
            );
          }
        );
      },
    );

    if (confirm != true) return;

    // 4. Send the request to the database via an RPC function
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      final stylistId = await StylistSession.resolve();
      if (stylistId == null) throw Exception('Stylist profile not found.');

      // Calls the PostgreSQL function 'ce_request_stylist_leave'
      await _supabase.rpc(
        'ce_request_stylist_leave',
        params: {
          'p_stylist_id': stylistId,
          'p_start_date': pickedStartDate.toIso8601String().substring(0, 10),
          'p_end_date': pickedEndDate.toIso8601String().substring(0, 10),
          'p_request_type': selectedType, 
          'p_reason': reasonController.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading spinner
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Leave request sent to manager successfully.'),
        backgroundColor: AppColors.success,
      ));
      _load(showLoading: false); // Refresh the list silently

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading spinner
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to send request: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Blocked Dates'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.gold,
              backgroundColor: AppColors.surfaceAlt,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Blocked dates are hidden from customers immediately. You cannot block a date if you have active appointments on it. Requests must be approved by the manager.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // PENDING SECTION
                    if (_pendingRequests.isNotEmpty) ...[
                      _buildSectionHeader('PENDING APPROVAL', Colors.orange, Icons.hourglass_empty),
                      const SizedBox(height: 12),
                      ..._pendingRequests.map((b) => _buildBlockedDateCard(b, Colors.orange, 'PENDING')),
                      const SizedBox(height: 24),
                    ],

                    // APPROVED SECTION
                    if (_approvedBlocks.isNotEmpty) ...[
                      _buildSectionHeader('APPROVED DATES', AppColors.success, Icons.check_circle_outline),
                      const SizedBox(height: 12),
                      ..._approvedBlocks.map((b) => _buildBlockedDateCard(b, AppColors.success, 'APPROVED')),
                      const SizedBox(height: 24),
                    ],

                    // DECLINED SECTION
                    if (_declinedRequests.isNotEmpty) ...[
                      _buildSectionHeader('DECLINED REQUESTS', AppColors.error, Icons.cancel_outlined),
                      const SizedBox(height: 12),
                      ..._declinedRequests.map((b) => _buildBlockedDateCard(b, AppColors.error, 'DECLINED')),
                      const SizedBox(height: 24),
                    ],

                    // Empty State
                    if (_pendingRequests.isEmpty && _approvedBlocks.isEmpty && _declinedRequests.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text('No blocked dates yet', style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Button to trigger the request flow
                    ElevatedButton.icon(
                      onPressed: _requestNewBlock,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('REQUEST A NEW BLOCK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Builds a styled header for the sections (Pending, Approved, Declined).
  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  /// Builds the individual card for each blocked date request.
  Widget _buildBlockedDateCard(Map<String, dynamic> block, Color statusColor, String statusText) {
    // Parse the date string from the database
    final date = DateTime.parse(block['requested_date']);
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(date);
    final reason = block['reason']?.toString() ?? 'No reason provided';
    final type = block['request_type']?.toString() ?? 'leave';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              // Status Badge (Pending, Approved, Declined)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Type: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text(
                type == 'leave' ? 'Leave' : 'Block Date', 
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reason: $reason',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}