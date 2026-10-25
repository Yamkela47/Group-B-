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
import 'app_theme.dart';       
import 'app_bars.dart';        
import 'buttons.dart';         
import 'cards.dart';           
import 'stylist_session.dart'; 
import 'package:intl/intl.dart'; 

/// A screen that allows a stylist to manage their weekly working hours.
/// It also displays any specific date overrides/blocks set by the manager.
class ManageAvailabilityScreen extends StatefulWidget {
  const ManageAvailabilityScreen({super.key});
  @override
  State<ManageAvailabilityScreen> createState() =>
      _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  final _supabase = Supabase.instance.client;

  // Holds the configuration for each day of the week (1 = Monday, 7 = Sunday)
  final Map<int, _DayConfig> _days = {
    for (var i = 1; i <= 7; i++) i: _DayConfig(),
  };

  // List of specific dates overridden or blocked by the manager
  List<_ManagerBlock> _managerBlocks = [];
  
  // State to toggle between showing 3 items or all items in the manager overrides list
  bool _showAllOverrides = false; 

  bool _loading = true;
  bool _saving = false;
  String? _error;
  dynamic _stylistId;

  // Holds the ordered list of weekdays starting from today
  List<int> _orderedWeekdays = [];
  // Holds the actual date for each weekday
  Map<int, DateTime> _nextDates = {};

  @override
  void initState() {
    super.initState();
    _calculateDates();
    _load();
  }

  /// Calculates the upcoming dates and reorders weekdays starting from today
  void _calculateDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    _orderedWeekdays.clear();
    _nextDates.clear();

    for (int i = 0; i < 7; i++) {
      int wd = ((today.weekday + i - 1) % 7) + 1;
      _orderedWeekdays.add(wd);
      
      int daysToAdd = (wd - today.weekday) % 7;
      _nextDates[wd] = today.add(Duration(days: daysToAdd));
    }
  }

  /// Loads the stylist's weekly schedule, specific schedules, and blocked dates from Supabase
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await StylistSession.resolve();
      if (!mounted) return;
      if (id == null) {
        setState(() {
          _error = 'This account is not linked to a stylist profile.';
          _loading = false;
        });
        return;
      }
      _stylistId = id;

      final todayStr = DateTime.now().toIso8601String().split('T').first;

      // Fetch weekly hours, specific schedules, and blocked dates in parallel
      final results = await Future.wait([
        _supabase.from('stylist_working_hours').select().eq('stylist_id', id),
        _supabase.from('stylist_schedules').select().eq('stylist_id', id).gte('work_date', todayStr).order('work_date'),
        _supabase.from('blocked_dates').select().eq('stylist_id', id).gte('blocked_date', todayStr).order('blocked_date'),
      ]);

      // Process weekly working hours
      final map = <int, _DayConfig>{};
      for (final r in (results[0] as List)) {
        final wd = (r['weekday'] as num).toInt();
        map[wd] = _DayConfig(
          isWorking: true, 
          start: _toTimeOfDay(r['start_time'] as String?),
          end: _toTimeOfDay(r['end_time'] as String?),
        );
      }
      // Fill in defaults for any missing days
      for (var i = 1; i <= 7; i++) {
        map.putIfAbsent(i, () => _DayConfig(isWorking: true));
      }

      // Process manager schedule overrides
      final blocks = <_ManagerBlock>[];
      for (final r in (results[1] as List)) {
        blocks.add(_ManagerBlock(
          dateStr: r['work_date'] as String,
          startTime: r['start_time'] as String?,
          endTime: r['end_time'] as String?,
          isAvailable: r['is_available'] as bool? ?? true,
        ));
      }

      // Process full-day blocks
      for (final r in (results[2] as List)) {
        final dateStr = r['blocked_date'] as String;
        if (!blocks.any((b) => b.dateStr == dateStr)) {
          blocks.add(_ManagerBlock(
            dateStr: dateStr,
            isAvailable: false,
          ));
        }
      }

      blocks.sort((a, b) => a.dateStr.compareTo(b.dateStr));

      if (!mounted) return;
      setState(() {
        _days
          ..clear()
          ..addAll(map);
        _managerBlocks = blocks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  TimeOfDay _toTimeOfDay(String? raw) {
    if (raw == null || raw.length < 5) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    return TimeOfDay(
        hour: int.parse(raw.substring(0, 2)),
        minute: int.parse(raw.substring(3, 5)));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:00';

  /// Validates and saves the new working hours to the database
  Future<void> _save() async {
    if (_stylistId == null) return;
    setState(() => _saving = true);

    try {
      // 1. Validation: Ensure Start Time is before End Time
      for (final entry in _days.entries) {
        final cfg = entry.value;
        final startMins = cfg.start.hour * 60 + cfg.start.minute;
        final endMins = cfg.end.hour * 60 + cfg.end.minute;
        
        if (startMins >= endMins) {
          _showError('Invalid Hours: On ${DateFormat('EEEE').format(_nextDates[entry.key]!)}, your Start Time must be before your End Time.');
          return;
        }
      }

      // 2. Validation: Ensure new hours do not overlap with existing bookings
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final bookingsData = await _supabase
          .from('bookings')
          .select('appointment_date, start_time, end_time')
          .eq('stylist_id', _stylistId)
          .gte('appointment_date', todayStr)
          .or('status.eq.confirmed,status.eq.pending'); 

      final upcomingBookings = List<Map<String, dynamic>>.from(bookingsData);

      for (final entry in _days.entries) {
        final wd = entry.key;
        final cfg = entry.value;

        final dayBookings = upcomingBookings.where((b) {
          final d = DateTime.parse(b['appointment_date'] as String);
          return d.weekday == wd;
        }).toList();

        if (dayBookings.isEmpty) continue;

        final newStart = cfg.start.hour * 60 + cfg.start.minute;
        final newEnd = cfg.end.hour * 60 + cfg.end.minute;

        for (var b in dayBookings) {
          final bStartStr = b['start_time'] as String? ?? '';
          final bEndStr = b['end_time'] as String? ?? '';
          
          if (bStartStr.length >= 5 && bEndStr.length >= 5) {
            final bStart = int.parse(bStartStr.substring(0, 2)) * 60 + int.parse(bStartStr.substring(3, 5));
            final bEnd = int.parse(bEndStr.substring(0, 2)) * 60 + int.parse(bEndStr.substring(3, 5));

            if (bStart < newStart || bEnd > newEnd) {
              final bDate = DateTime.parse(b['appointment_date'] as String);
              final formattedDate = DateFormat('EEEE, d MMM').format(bDate);
              
              _showError(
                'Action Blocked: You have an active appointment on $formattedDate at ${bStartStr.substring(0, 5)}.\n\n'
                'Your new shift (${_formatTime(cfg.start).substring(0, 5)} - ${_formatTime(cfg.end).substring(0, 5)}) does not cover this appointment.'
              );
              return; 
            }
          }
        }
      }

      // 3. Save the data to Supabase
      final payload = _days.entries
          .map((e) => {
                'stylist_id': _stylistId,
                'weekday': e.key,
                'start_time': _formatTime(e.value.start),
                'end_time': _formatTime(e.value.end),
                'is_working': true, 
              })
          .toList();

      // Crucial: If this fails, it throws an exception caught below.
      await _supabase
          .from('stylist_working_hours')
          .upsert(payload, onConflict: 'stylist_id,weekday');

      // Reload the data to ensure the UI reflects the saved state
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Availability updated successfully'),
          backgroundColor: AppColors.success));

    } catch (e) {
      if (!mounted) return;
      _showError('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, height: 1.4)),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 6)));
  }

  /// Opens a time picker dialog and handles validation
  Future<void> _pickTime(int weekday, bool isStart) async {
    final current =
        isStart ? _days[weekday]!.start : _days[weekday]!.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
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
    if (picked == null) return;

    final pickedMins = picked.hour * 60 + picked.minute;
    final startMins = _days[weekday]!.start.hour * 60 + _days[weekday]!.start.minute;
    final endMins = _days[weekday]!.end.hour * 60 + _days[weekday]!.end.minute;

    if (isStart) {
      if (pickedMins >= endMins) {
        _showError('Start time cannot be equal to or later than End time.');
        return;
      }
      setState(() => _days[weekday]!.start = picked);
    } else {
      if (pickedMins <= startMins) {
        _showError('End time cannot be equal to or earlier than Start time.');
        return;
      }
      setState(() => _days[weekday]!.end = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Manage Availability'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Manager Overrides Section
                      if (_managerBlocks.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Manager Overrides',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            if (_managerBlocks.length > 3)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showAllOverrides = !_showAllOverrides;
                                  });
                                },
                                child: Text(
                                  _showAllOverrides ? 'Show Less' : 'View All',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                            'These specific dates have been blocked or adjusted by management. You cannot edit these.',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                height: 1.4)),
                        const SizedBox(height: 12),
                        
                        // Shows 3 items unless "View All" is clicked
                        ..._managerBlocks
                            .take(_showAllOverrides ? _managerBlocks.length : 3)
                            .map((block) => _buildManagerBlock(block)),
                            
                        const SizedBox(height: 28),
                      ],

                      // Weekly Schedule Section
                      const Text('Weekly Schedule',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text(
                          'Set your recurring working hours. The dates shown are your next upcoming shifts.',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.4)),
                      const SizedBox(height: 12),
                      
                      // Loop through the ordered weekdays
                      ..._orderedWeekdays.map((wd) {
                        final cfg = _days[wd]!;
                        final dateStr = DateFormat('EEEE, d MMM').format(_nextDates[wd]!);
                        
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Column(
                            children: [
                              Row(children: [
                                Text(dateStr,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700)),
                              ]),
                              
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(children: [
                                  Expanded(
                                    child: _TimePill(
                                      label: 'Start',
                                      value: _formatTime(cfg.start)
                                          .substring(0, 5),
                                      onTap: () =>
                                          _pickTime(wd, true),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TimePill(
                                      label: 'End',
                                      value: _formatTime(cfg.end)
                                          .substring(0, 5),
                                      onTap: () =>
                                          _pickTime(wd, false),
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      
                      // Save Button
                      _saving
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.gold)))
                          : GoldButton(
                              label: 'Save Changes',
                              onPressed: _save,
                            ),
                    ],
                  ),
                ),
    );
  }

  /// Builds the UI card for a manager override/block.
  Widget _buildManagerBlock(_ManagerBlock block) {
    final date = DateTime.parse(block.dateStr);
    final formattedDate = DateFormat('EEEE, d MMM yyyy').format(date);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            block.isAvailable ? Icons.edit_calendar : Icons.lock_clock,
            color: AppColors.error,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (!block.isAvailable)
                  const Text(
                    'Unavailable (Full Day Blocked)',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    'Custom Hours: ${block.startTime?.substring(0, 5) ?? "09:00"} - ${block.endTime?.substring(0, 5) ?? "17:00"}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayConfig {
  bool isWorking;
  TimeOfDay start;
  TimeOfDay end;
  _DayConfig({
    this.isWorking = true,
    this.start = const TimeOfDay(hour: 9, minute: 0),
    this.end = const TimeOfDay(hour: 17, minute: 0),
  });
}

class _ManagerBlock {
  final String dateStr;
  final String? startTime;
  final String? endTime;
  final bool isAvailable;

  _ManagerBlock({
    required this.dateStr,
    this.startTime,
    this.endTime,
    required this.isAvailable,
  });
}

class _TimePill extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  const _TimePill(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          const Icon(Icons.access_time,
              color: AppColors.gold, size: 14),
        ]),
      ),
    );
  }
}