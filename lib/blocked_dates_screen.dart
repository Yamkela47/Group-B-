import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'catalog_image.dart';
import 'payment_method_screen.dart';
import 'booking_availability.dart';
import 'app_bars.dart';

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

  StylistBookingAvailability? _availability;
  String? _availabilityError;
  bool _loadingSlots = false;
  int _availabilityRequest = 0;

  bool get _dayBlocked =>
      _availability?.isDayBlocked(_selectedDate) ?? false;
  bool get _dayNotWorking =>
      _availability?.isDateUnavailable(_selectedDate) ?? false;

  bool _dateUnavailable(DateTime date) =>
      _availability?.isDateUnavailable(date) ?? false;

  Set<String> _unavailableSlots(List<String> slots) =>
      _availability?.unavailableTimeSlots(
        _selectedDate, slots, widget.durationMinutes,
      ) ?? slots.toSet();

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
      if (initial != null) _refreshAvailability();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stylistError = '$e';
        _loadingStylists = false;
      });
    }
  }

  Future<void> _refreshAvailability() async {
    final stylist = _selectedStylist;
    if (stylist == null || !mounted) return;
    final request = ++_availabilityRequest;
    final requestedDate = _selectedDate;
    setState(() {
      _loadingSlots = true;
      _availability = null;
      _availabilityError = null;
      _selectedTime = null;
    });

    try {
      final availability = await StylistBookingAvailabilityService(_supabase)
          .load(stylistId: stylist.id, selectedDate: requestedDate);
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _availability = availability);
    } catch (error) {
      if (!mounted || request != _availabilityRequest) return;
      // Never silently treat a failed Supabase lookup as an available day.
      debugPrint('Customer booking availability query failed: $error');
      setState(() => _availabilityError =
          'Could not load stylist availability. Please retry.');
    } finally {
      if (mounted && request == _availabilityRequest) {
        setState(() => _loadingSlots = false);
      }
    }
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
    if (_loadingSlots || _availability == null) return;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final last = first.add(const Duration(days: 365));
    DateTime initial = _selectedDate;
    if (_dateUnavailable(initial)) {
      initial = first;
      while (!initial.isAfter(last) && _dateUnavailable(initial)) {
        initial = initial.add(const Duration(days: 1));
      }
      if (initial.isAfter(last)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This stylist has no available dates.'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (day) => !_dateUnavailable(day),
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
    final availability = _availability;
    if (availability == null || _dayNotWorking) {
      return {'Morning': [], 'Afternoon': []};
    }
    final shifts = availability.shiftsOn(_selectedDate);
    if (shifts.isEmpty) return {'Morning': [], 'Afternoon': []};

    // Include unavailable times in the grid, but grey them out below.
    final earliest = shifts.map((s) => s.start).reduce((a, b) => a < b ? a : b);
    final latest = shifts.map((s) => s.end).reduce((a, b) => a > b ? a : b);
    final firstSlot = ((earliest + 29) ~/ 30) * 30;
    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final morning = <String>[];
    final afternoon = <String>[];

    for (int minute = firstSlot; minute < latest; minute += 30) {
      if (isToday && minute <= now.hour * 60 + now.minute) continue;
      final h = minute ~/ 60;
      final m = minute % 60;
      final slot =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      (h < 12 ? morning : afternoon).add(slot);
    }
    return {'Morning': morning, 'Afternoon': afternoon};
  }

  void _continue() {
    if (_selectedStylist == null || _loadingSlots || _availability == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please wait for stylist availability to load.'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_dayNotWorking) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This stylist is unavailable on the selected date.'),
          backgroundColor: AppColors.error));
      return;
    }
    if (_selectedTime == null ||
        _availability!.isTimeUnavailable(
            _selectedDate, _selectedTime!, widget.durationMinutes)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please choose an available time that fits the full service.'),
          backgroundColor: AppColors.error));
      return;
    }

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
          time: _selectedTime!,
        ),
      ),
    ).then((_) => _refreshAvailability());
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedSlots();
    final hasSlots = grouped['Morning']!.isNotEmpty || grouped['Afternoon']!.isNotEmpty;
    final unavailable = _dayBlocked || _dayNotWorking;

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

                    // Stylists
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
                              _refreshAvailability();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dates
                    Row(children: [
                      const Text('Select a Date',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _loadingSlots || _availability == null ? null : _pickDate,
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
                            disabled: _loadingSlots || _availability == null || _dateUnavailable(d),
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

                    // Times
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

                    if (_availabilityError != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Column(children: [
                          Text(_availabilityError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13)),
                          TextButton(onPressed: _refreshAvailability,
                            child: const Text('Retry', style: TextStyle(color: AppColors.gold))),
                        ]),
                      )
                    else if (_loadingSlots)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ))
                    else if (unavailable)
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
                    else if (!hasSlots)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: AppColors.gold, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                'No more time slots available for this day. Please pick another date.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                          ),
                        ]),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 👇 MORNING HEADER 👇
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
                              taken: _unavailableSlots(grouped['Morning']!),
                              onSelect: (t) => setState(() => _selectedTime = t),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // 👇 AFTERNOON HEADER 👇
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
                              taken: _unavailableSlots(grouped['Afternoon']!),
                              onSelect: (t) => setState(() => _selectedTime = t),
                            ),
                          ],
                        ],
                      ),
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
              onPressed: _loadingStylists || _loadingSlots ||
                  _availability == null || _availabilityError != null ||
                  unavailable ? null : _continue,
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
  final bool disabled;
  final VoidCallback onTap;
  const _DateCard({
    required this.weekday,
    required this.day,
    required this.month,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: disabled ? AppColors.surfaceAlt : selected ? AppColors.gold : AppColors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled ? AppColors.border : selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekday, style: TextStyle(color: disabled ? AppColors.textMuted : selected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$day $month', style: TextStyle(color: disabled ? AppColors.textMuted : selected ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  final List<String> slots;
  final String? selected;
  final Set<String> taken;
  final ValueChanged<String> onSelect;
  
  const _TimeGrid({
    required this.slots,
    required this.selected,
    required this.taken,
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
        final isTaken = taken.contains(time);
        
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
