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
import 'catalog_image.dart';      
import 'payment_method_screen.dart'; 
import 'app_bars.dart';           

/// The main screen for booking an appointment.
class BookAppointmentScreen extends StatefulWidget {
  final String? initialStylist;
  final String? service;
  final String? price;
  final dynamic serviceId;
  final int durationMinutes;
  final String? serviceImagePath;

  const BookAppointmentScreen({
    super.key,
    this.initialStylist,
    this.service,
    this.price,
    this.serviceId = 1,
    this.durationMinutes = 40,
    this.serviceImagePath,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _supabase = Supabase.instance.client;

  List<_Stylist> _stylists = [];
  bool _loadingStylists = true;
  String? _stylistError;
  _Stylist? _selectedStylist;

  DateTime _selectedDate = DateTime.now();
  late final List<DateTime> _quickDates =
      List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

  String? _selectedTime;

  List<Map<String, String>> _existingBookings = [];
  Map<int, Map<String, dynamic>> _workingHours = {};
  Map<String, dynamic>? _specificSchedule; 

  bool _dayBlocked = false;
  bool _dayNotWorking = false;
  bool _loadingSlots = false;
  bool _stylistFullyUnavailable = false;

  RealtimeChannel? _realtimeChannel;

  late final _ServiceInfo _service = _ServiceInfo(
    name: widget.service ?? 'Standard Haircut',
    description: 'Clean. Stylish. Always in trend.',
    duration: _formatDuration(widget.durationMinutes),
    price: widget.price ?? 'R140',
    imagePath: widget.serviceImagePath ?? '',
  );

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  void initState() {
    super.initState();
    _loadStylists();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadStylists() async {
    try {
      final rows = await _supabase
          .from('stylists')
          .select('stylist_id, rating, profile_id');

      if (!mounted) return;

      List<_Stylist> list = [];

      for (var r in rows as List) {
        String name = 'Stylist';
        String? photoUrl;
        dynamic profileId = r['profile_id'];

        if (profileId != null) {
          try {
            final profile = await _supabase
                .from('profiles')
                .select('full_name, photo_url')
                .eq('id', profileId)
                .maybeSingle();
                
            if (profile != null) {
              if (profile['full_name'] != null) name = profile['full_name'];
              if (profile['photo_url'] != null) photoUrl = profile['photo_url'];
            }
          } catch (_) {}
        }

        list.add(_Stylist(
          id: r['stylist_id'],
          name: name,
          rating: (r['rating'] as num?)?.toDouble() ?? 0.0,
          photoUrl: photoUrl, 
        ));
      }

      _Stylist? initial;
      if (list.isNotEmpty) {
        final target = widget.initialStylist?.toLowerCase().split(' ').first;
        if (target != null && target.isNotEmpty) {
          initial = list.cast<_Stylist?>().firstWhere(
                (s) => s!.name.toLowerCase().startsWith(target),
                orElse: () => null,
              );
        }
        initial ??= list.first;
      }

      setState(() {
        _stylists = list;
        _selectedStylist = initial;
        _loadingStylists = false;
      });
      
      if (initial != null) {
        _setupRealtimeListener(initial.id); 
        _refreshAvailability();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stylistError = '$e';
        _loadingStylists = false;
      });
    }
  }

  void _setupRealtimeListener(dynamic stylistId) {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }

    _realtimeChannel = _supabase.channel('customer_view_$stylistId');
    
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bookings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'stylist_id',
        value: stylistId,
      ),
      callback: (payload) {
        _refreshAvailability(showLoading: false);
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blocked_dates',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'stylist_id',
        value: stylistId,
      ),
      callback: (payload) {
        _refreshAvailability(showLoading: false);
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'stylist_working_hours',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'stylist_id',
        value: stylistId,
      ),
      callback: (payload) {
        _refreshAvailability(showLoading: false);
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'stylist_schedules',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'stylist_id',
        value: stylistId,
      ),
      callback: (payload) {
        _refreshAvailability(showLoading: false);
      },
    ).subscribe();
  }

  Future<void> _refreshAvailability({bool showLoading = true}) async {
    final stylist = _selectedStylist;
    if (stylist == null) return;
    if (!mounted) return;
    
    if (showLoading) setState(() => _loadingSlots = true);

    try {
      final dateStr =
          '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        _supabase
            .from('bookings')
            .select('start_time, end_time, status')
            .eq('stylist_id', stylist.id)
            .eq('appointment_date', dateStr)
            .neq('status', 'cancelled')
            .neq('status', 'cancelled_by_stylist'),
        _supabase
            .from('blocked_dates')
            .select('blocked_date')
            .eq('stylist_id', stylist.id)
            .eq('blocked_date', dateStr),
        _supabase
            .from('stylist_working_hours')
            .select()
            .eq('stylist_id', stylist.id),
        _supabase
            .from('stylist_schedules')
            .select()
            .eq('stylist_id', stylist.id)
            .eq('work_date', dateStr),
      ]);

      if (!mounted) return;

      final booked = <Map<String, String>>[];
      for (final row in (results[0] as List)) {
        final rawStart = row['start_time'] as String? ?? '';
        final rawEnd = row['end_time'] as String? ?? '';
        if (rawStart.length >= 5 && rawEnd.length >= 5) {
          booked.add({
            'start': rawStart.substring(0, 5),
            'end': rawEnd.substring(0, 5),
          });
        }
      }

      final hours = <int, Map<String, dynamic>>{};
      for (final r in (results[2] as List)) {
        hours[(r['weekday'] as num).toInt()] = Map<String, dynamic>.from(r);
      }

      final specificList = results[3] as List;
      Map<String, dynamic>? specific = specificList.isNotEmpty 
          ? Map<String, dynamic>.from(specificList.first) 
          : null;

      final hasAnyWorkingDays = hours.values.any((h) => h['is_working'] == true);
      final isFullyUnavailable = hours.isEmpty || !hasAnyWorkingDays;

      final isBlocked = (results[1] as List).isNotEmpty;
      
      final wh = hours[_selectedDate.weekday];
      final isWorking = wh != null && wh['is_working'] == true;
      final isAvailableOnSpecificDate = specific == null ? true : specific['is_available'] == true;

      setState(() {
        _stylistFullyUnavailable = isFullyUnavailable;
        _existingBookings = booked;
        _workingHours = hours;
        _specificSchedule = specific; 
        _dayBlocked = isBlocked;
        _dayNotWorking = !isWorking || !isAvailableOnSpecificDate;
        
        if (isBlocked || !isWorking || !isAvailableOnSpecificDate) {
          _selectedTime = null;
        } else if (_selectedTime != null && _isSlotBlocked(_selectedTime!)) {
          _selectedTime = null;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The time slot you selected was just booked. Please pick another.'),
            backgroundColor: AppColors.error,
          ));
        }
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted && showLoading) setState(() => _loadingSlots = false);
    }
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]) * 60) + int.parse(parts[1]);
  }

  bool _isSlotBlocked(String slotTime) {
    final slotStart = _toMinutes(slotTime);
    final slotEnd = slotStart + widget.durationMinutes;

    for (var booking in _existingBookings) {
      final takenStart = _toMinutes(booking['start']!);
      final takenEnd = _toMinutes(booking['end']!);

      if (slotStart < takenEnd && slotEnd > takenStart) {
        return true;
      }
    }
    return false;
  }

  String _weekdayShort(DateTime d) {
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[d.weekday - 1];
  }

  String _dayNum(DateTime d) => d.day.toString();

  String _monthShort(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[d.month - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: Colors.black,
            surface: AppColors.surfaceAlt,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: AppColors.surface,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
      _refreshAvailability();
    }
  }

  Map<String, List<String>> _groupedSlots() {
    if (_dayBlocked || _dayNotWorking || _stylistFullyUnavailable) {
      return {'Morning': [], 'Afternoon': []};
    }
    
    final now = DateTime.now();
    final wh = _workingHours[_selectedDate.weekday];

    if (wh == null && _specificSchedule == null) {
      return {'Morning': [], 'Afternoon': []};
    }

    int openH = 9, openM = 0, closeH = 17, closeM = 0;

    if (_specificSchedule != null) {
      final s = (_specificSchedule!['start_time'] as String? ?? '09:00');
      final e = (_specificSchedule!['end_time'] as String? ?? '17:00');
      openH = int.tryParse(s.substring(0, 2)) ?? 9;
      openM = int.tryParse(s.substring(3, 5)) ?? 0;
      closeH = int.tryParse(e.substring(0, 2)) ?? 17;
      closeM = int.tryParse(e.substring(3, 5)) ?? 0;
    } else if (wh != null) {
      final s = (wh['start_time'] as String? ?? '09:00');
      final e = (wh['end_time'] as String? ?? '17:00');
      openH = int.tryParse(s.substring(0, 2)) ?? 9;
      openM = int.tryParse(s.substring(3, 5)) ?? 0;
      closeH = int.tryParse(e.substring(0, 2)) ?? 17;
      closeM = int.tryParse(e.substring(3, 5)) ?? 0;
    }

    final startTotal = openH * 60 + openM;
    final endTotal = closeH * 60 + closeM;
    
    if (endTotal - startTotal < widget.durationMinutes) {
      return {'Morning': [], 'Afternoon': []};
    }

    final isToday = _isSameDay(_selectedDate, now);
    final morning = <String>[];
    final afternoon = <String>[];

    for (int m = startTotal; m < endTotal; m += 30) {
      if (isToday && m <= now.hour * 60 + now.minute) continue;
      
      if (m + widget.durationMinutes > endTotal) {
        continue; 
      }

      final h = m ~/ 60;
      final mm = m % 60;
      final slot = '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      
      (h < 12 ? morning : afternoon).add(slot);
    }
    return {'Morning': morning, 'Afternoon': afternoon};
  }

  void _continue() {
    if (_selectedStylist == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a stylist.'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_stylistFullyUnavailable || _dayBlocked || _dayNotWorking) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This stylist is not available on the selected date.'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a time slot.'),
          backgroundColor: AppColors.error));
      return;
    }

    final String finalSelectedTime = _selectedTime!;

    setState(() {
      _selectedTime = null;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          service: _service.name,
          servicePrice: _service.price,
          serviceImagePath: _service.imagePath,
          stylist: _selectedStylist!.name,
          stylistId: _selectedStylist!.id, 
          serviceId: widget.serviceId, 
          durationMinutes: widget.durationMinutes,
          date: _selectedDate,
          time: finalSelectedTime,
        ),
      ),
    ).then((_) => _refreshAvailability());
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedSlots();
    final hasSlots = grouped['Morning']!.isNotEmpty || grouped['Afternoon']!.isNotEmpty;
    final unavailable = _dayBlocked || _dayNotWorking || !hasSlots;

    return Scaffold(
      appBar: const ScreenAppBar(title: 'Book Appointment'),
      body: _loadingStylists
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _stylistError != null
              ? _StylistError(message: _stylistError!, onRetry: _loadStylists)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: const [
                          Icon(Icons.arrow_back_ios_new, color: AppColors.gold, size: 18),
                          SizedBox(width: 4),
                          Text('Back', style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      _service.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _service.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary, 
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _HeroServiceCard(service: _service),
                    const SizedBox(height: 28),

                    Row(children: [
                      const Text('Select a Stylist',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('View All',
                          style: TextStyle(
                              color: AppColors.gold.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 135, 
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _stylists.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          final s = _stylists[i];
                          return _StylistCard(
                            stylist: s,
                            selected: s.id == _selectedStylist?.id,
                            onTap: () {
                              setState(() {
                                _selectedStylist = s;
                                _selectedTime = null;
                              });
                              _setupRealtimeListener(s.id); 
                              _refreshAvailability();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_stylistFullyUnavailable)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.person_off, color: AppColors.error, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'Stylist Unavailable',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'This stylist\'s availability has been cancelled by the manager. Please select a different stylist.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Row(children: [
                        const Text('Select a Date',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Text('View Calendar',
                              style: TextStyle(
                                  color: AppColors.gold.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 70,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _quickDates.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final d = _quickDates[i];
                            return _DateCard(
                              weekday: _weekdayShort(d),
                              day: _dayNum(d),
                              month: _monthShort(d),
                              selected: _isSameDay(d, _selectedDate),
                              onTap: () {
                                setState(() {
                                  _selectedDate = d;
                                  _selectedTime = null;
                                });
                                _refreshAvailability();
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(children: [
                        const Text('Select Time',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (_loadingSlots)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                          ),
                      ]),
                      const SizedBox(height: 14),

                      if (unavailable)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(children: [
                            Icon(Icons.event_busy, color: AppColors.gold, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  'This stylist is not available on the selected date. Please pick another date.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                            ),
                          ]),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (grouped['Morning']!.isNotEmpty) ...[
                              const Row(
                                children: [
                                  Icon(Icons.wb_sunny_outlined, color: AppColors.gold, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'MORNING',
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _TimeGrid(
                                slots: grouped['Morning']!,
                                selected: _selectedTime,
                                isSlotBlocked: _isSlotBlocked,
                                onSelect: (t) => setState(() => _selectedTime = t),
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            if (grouped['Afternoon']!.isNotEmpty) ...[
                              const Row(
                                children: [
                                  Icon(Icons.light_mode_outlined, color: AppColors.gold, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'AFTERNOON',
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _TimeGrid(
                                slots: grouped['Afternoon']!,
                                selected: _selectedTime,
                                isSlotBlocked: _isSlotBlocked,
                                onSelect: (t) => setState(() => _selectedTime = t),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ],
                ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(color: AppColors.black),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _loadingStylists || _stylistFullyUnavailable || unavailable ? null : _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HELPER WIDGETS
// ==========================================

class _StylistError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _StylistError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.gold, size: 42),
            const SizedBox(height: 12),
            const Text('Could not load stylists', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}

class _HeroServiceCard extends StatelessWidget {
  final _ServiceInfo service;
  const _HeroServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CatalogImage(
              source: service.imagePath,
              width: 110,
              height: 120,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.access_time, color: AppColors.gold, size: 18),
                    SizedBox(width: 8),
                    Text('Duration', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(service.duration, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                
                Row(
                  children: const [
                    Icon(Icons.local_offer, color: AppColors.gold, size: 18),
                    SizedBox(width: 8),
                    Text('Price', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(service.price, style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StylistCard extends StatelessWidget {
  final _Stylist stylist;
  final bool selected;
  final VoidCallback onTap;
  const _StylistCard({required this.stylist, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 105,
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: stylist.photoUrl != null && stylist.photoUrl!.isNotEmpty
                        ? CatalogImage(source: stylist.photoUrl, width: double.infinity, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.surface,
                            child: const Center(child: Icon(Icons.person, color: AppColors.gold, size: 30)),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stylist.name.split(' ').first,
                        style: TextStyle(
                          color: selected ? AppColors.gold : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            stylist.rating.toStringAsFixed(1),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.black, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String weekday;
  final String day;
  final String month;
  final bool selected;
  final VoidCallback onTap;
  const _DateCard({
    required this.weekday,
    required this.day,
    required this.month,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekday, style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$day $month', style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  final List<String> slots;
  final String? selected;
  final bool Function(String) isSlotBlocked;
  final ValueChanged<String> onSelect;
  
  const _TimeGrid({
    required this.slots,
    required this.selected,
    required this.isSlotBlocked,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: slots.map((time) {
        final isSelected = time == selected;
        final isTaken = isSlotBlocked(time);
        
        final width = (MediaQuery.of(context).size.width - 40 - 24) / 3;

        return GestureDetector(
          onTap: isTaken ? null : () => onSelect(time),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTaken 
                  ? AppColors.surface 
                  : isSelected 
                      ? AppColors.gold 
                      : AppColors.black,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isTaken 
                      ? AppColors.border 
                      : isSelected 
                          ? AppColors.gold 
                          : AppColors.border,
                  width: 1.2),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: isTaken
                    ? AppColors.textMuted
                    : isSelected
                        ? Colors.black
                        : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                decoration: isTaken ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Stylist {
  final dynamic id;
  final String name;
  final double rating;
  final String? photoUrl;

  const _Stylist({
    required this.id, 
    required this.name, 
    required this.rating,
    this.photoUrl,
  });
}

class _ServiceInfo {
  final String name;
  final String description;
  final String duration;
  final String price;
  final String imagePath;
  const _ServiceInfo({
    required this.name,
    required this.description,
    required this.duration,
    required this.price,
    required this.imagePath,
  });
}