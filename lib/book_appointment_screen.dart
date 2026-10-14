import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'payment_method_screen.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String? initialStylist;
  final String? service;
  final String? price;
  final bool showServicePicker;

  const BookAppointmentScreen({
    super.key,
    this.initialStylist,
    this.service,
    this.price,
    this.showServicePicker = false,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  // ---------- Supabase ----------
  final _supabase = Supabase.instance.client;

  // ---------- Stylists ----------
  final List<_Stylist> _stylists = const [
    _Stylist(name: 'Nqobile', rating: 4.8),
    _Stylist(name: 'Thabo',   rating: 4.9),
    _Stylist(name: 'Nkosi',   rating: 4.9),
    _Stylist(name: 'Sipho',   rating: 4.9),
    _Stylist(name: 'Lerato',  rating: 5.0),
  ];
  late String _stylist = widget.initialStylist ?? _stylists.first.name;

  // ---------- Dates ----------
  DateTime _selectedDate = DateTime.now();
  late final List<DateTime> _quickDates = List.generate(
    7,
    (i) => DateTime.now().add(Duration(days: i)),
  );

  // ---------- Time ----------
  String? _selectedTime;

  // ---------- Taken slots (double-booking prevention) ----------
  Set<String> _takenSlots = {};
  bool _loadingSlots = false;

  // ---------- Service ----------
  late final _ServiceInfo _service = _ServiceInfo(
    name: widget.service ?? 'Standard Haircut',
    description: 'Clean. Stylish. Always in trend.',
    duration: '40 minutes',
    price: widget.price ?? 'R140',
    imagePath: 'assets/images/standard_haircut.jpg',
  );

  // =================================================================
  //  LIFECYCLE
  // =================================================================
  @override
  void initState() {
    super.initState();
    _refreshTakenSlots();
  }

  // =================================================================
  //  FETCH TAKEN SLOTS FROM SUPABASE
  // =================================================================
  Future<void> _refreshTakenSlots() async {
    if (!mounted) return;
    setState(() => _loadingSlots = true);

    try {
      final dateStr =
          '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      final data = await _supabase
          .from('bookings')
          .select('start_time')
          .eq('stylist_name', _stylist)
          .eq('appointment_date', dateStr)
          .neq('status', 'cancelled');

      final set = <String>{};
      for (final row in (data as List)) {
        final raw = row['start_time'] as String? ?? '';
        if (raw.length >= 5) set.add(raw.substring(0, 5));
      }

      if (!mounted) return;
      setState(() => _takenSlots = set);
    } catch (_) {
      if (mounted) setState(() => _takenSlots = {});
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  // =================================================================
  //  HELPERS
  // =================================================================

  String _weekdayShort(DateTime d) {
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[d.weekday - 1];
  }

  String _dayNum(DateTime d) => d.day.toString();

  String _monthShort(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return m[d.month - 1];
  }

  String _formatLongDate(DateTime d) {
    const wd = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const mo = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _openingHourFor(DateTime d) => d.weekday == DateTime.sunday ? 8 : 9;
  int _closingHourFor(DateTime d) => d.weekday == DateTime.sunday ? 13 : 17;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
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
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
      });
      _refreshTakenSlots();
    }
  }

  Map<String, List<String>> _groupedSlots() {
    final now = DateTime.now();
    final open = _openingHourFor(_selectedDate);
    final close = _closingHourFor(_selectedDate);
    final isToday = _isSameDay(_selectedDate, now);

    final morning = <String>[];
    final afternoon = <String>[];

    for (int hour = open; hour < close; hour++) {
      for (final minute in [0, 30]) {
        if (isToday) {
          final slotMin = hour * 60 + minute;
          final nowMin = now.hour * 60 + now.minute;
          if (slotMin <= nowMin) continue;
        }
        final hh = hour.toString().padLeft(2, '0');
        final mm = minute.toString().padLeft(2, '0');
        final slot = '$hh:$mm';
        (hour < 12 ? morning : afternoon).add(slot);
      }
    }

    return {'Morning': morning, 'Afternoon': afternoon};
  }

  void _continue() {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          service: _service.name,
          servicePrice: _service.price,
          serviceImagePath: _service.imagePath,
          stylist: _stylist,
          date: _selectedDate,
          time: _selectedTime!,
        ),
      ),
    ).then((_) {
      // When user comes back, refresh the taken slots in case
      // the booking succeeded or failed
      _refreshTakenSlots();
    });
  }

  // =================================================================
  //  BUILD
  // =================================================================

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedSlots();
    final hasSlots =
        grouped['Morning']!.isNotEmpty || grouped['Afternoon']!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 90,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: const [
                Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Back',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.4),
              ),
              child: const Icon(Icons.content_cut,
                  color: AppColors.gold, size: 13),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('CUTTING EDGE',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8)),
                Text('OUR VISION, YOUR STYLE',
                    style: TextStyle(
                        color: AppColors.goldDim,
                        fontSize: 6.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
        actions: const [SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          /* ---------- SERVICE TITLE ---------- */
          Text(_service.name,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_service.description,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),

          /* ---------- HERO CARD ---------- */
          _HeroServiceCard(service: _service),
          const SizedBox(height: 22),

          /* ---------- STYLIST ---------- */
          Row(
            children: [
              const Text('Select a Stylist',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('View All',
                  style: TextStyle(
                      color: AppColors.gold.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _stylists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final s = _stylists[i];
                final selected = s.name == _stylist;
                return _StylistChip(
                  stylist: s,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      _stylist = s.name;
                      _selectedTime = null;
                    });
                    _refreshTakenSlots();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          /* ---------- DATE ---------- */
          Row(
            children: [
              const Text('Select a Date',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              GestureDetector(
                onTap: _pickDate,
                child: Text('View Calendar',
                    style: TextStyle(
                        color: AppColors.gold.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickDates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final d = _quickDates[i];
                final selected = _isSameDay(d, _selectedDate);
                return _DateChip(
                  weekday: _weekdayShort(d),
                  day: _dayNum(d),
                  month: _monthShort(d),
                  selected: selected,
                  onTap: () {
                    setState(() {
                      _selectedDate = d;
                      _selectedTime = null;
                    });
                    _refreshTakenSlots();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              _formatLongDate(_selectedDate),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 22),

          /* ---------- TIME ---------- */
          Row(
            children: [
              const Text('Select Time',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_loadingSlots)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: AppColors.gold,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _closingHourFor(_selectedDate) == 13
                ? 'Sundays: 08:00 – 13:00'
                : 'Mon–Sat: 09:00 – 17:00',
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.gold, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Greyed out slots are already booked.',
                  style: TextStyle(
                    color: AppColors.textMuted.withOpacity(0.9),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!hasSlots)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.gold, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No more time slots available for this day. '
                      'Please pick another date.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else
            _TimeGroups(
              grouped: grouped,
              selected: _selectedTime,
              taken: _takenSlots,
              onSelect: (t) => setState(() => _selectedTime = t),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.black,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _continue,
              child: const Text('CONTINUE'),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================================================================
   HERO SERVICE CARD
   =================================================================== */
class _HeroServiceCard extends StatelessWidget {
  final _ServiceInfo service;
  const _HeroServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 1.2),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              service.imagePath,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withOpacity(0.4)),
                ),
                child: const Icon(Icons.content_cut,
                    color: AppColors.gold, size: 34),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Duration',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(service.duration,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text('Price',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(service.price,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Fresh, clean and professionally styled.',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================================================================
   STYLIST CHIP
   =================================================================== */
class _StylistChip extends StatelessWidget {
  final _Stylist stylist;
  final bool selected;
  final VoidCallback onTap;

  const _StylistChip({
    required this.stylist,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border,
                  width: selected ? 2 : 1.2,
                ),
                color: AppColors.surface,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/stylist_${stylist.name.toLowerCase()}.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    color: AppColors.gold,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stylist.name,
              style: TextStyle(
                color: selected ? AppColors.gold : Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: AppColors.gold, size: 10),
                const SizedBox(width: 2),
                Text(stylist.rating.toString(),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ===================================================================
   DATE CHIP
   =================================================================== */
class _DateChip extends StatelessWidget {
  final String weekday;
  final String day;
  final String month;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
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
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.gold : AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekday,
                style: TextStyle(
                    color: selected
                        ? Colors.black
                        : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(day,
                style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 1),
            Text(month,
                style: TextStyle(
                    color: selected
                        ? Colors.black.withOpacity(0.75)
                        : AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/* ===================================================================
   TIME GROUPS
   =================================================================== */
class _TimeGroups extends StatelessWidget {
  final Map<String, List<String>> grouped;
  final String? selected;
  final Set<String> taken;
  final ValueChanged<String> onSelect;

  const _TimeGroups({
    required this.grouped,
    required this.selected,
    required this.taken,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped['Morning']!.isNotEmpty) ...[
          _SubLabel(text: 'Morning'),
          const SizedBox(height: 10),
          _ChipWrap(
            slots: grouped['Morning']!,
            selected: selected,
            taken: taken,
            onSelect: onSelect,
          ),
          const SizedBox(height: 18),
        ],
        if (grouped['Afternoon']!.isNotEmpty) ...[
          _SubLabel(text: 'Afternoon'),
          const SizedBox(height: 10),
          _ChipWrap(
            slots: grouped['Afternoon']!,
            selected: selected,
            taken: taken,
            onSelect: onSelect,
          ),
        ],
      ],
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: AppColors.gold, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> slots;
  final String? selected;
  final Set<String> taken;
  final ValueChanged<String> onSelect;

  const _ChipWrap({
    required this.slots,
    required this.selected,
    required this.taken,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((time) {
        final isSelected = time == selected;
        final isTaken = taken.contains(time);

        return GestureDetector(
          onTap: isTaken ? null : () => onSelect(time),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isTaken
                  ? AppColors.surface
                  : isSelected
                      ? AppColors.gold
                      : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isTaken
                    ? AppColors.border
                    : isSelected
                        ? AppColors.gold
                        : AppColors.border,
              ),
              boxShadow: isSelected && !isTaken
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTaken) ...[
                  const Icon(Icons.block,
                      color: AppColors.textMuted, size: 12),
                  const SizedBox(width: 5),
                ],
                Text(
                  time,
                  style: TextStyle(
                    color: isTaken
                        ? AppColors.textMuted
                        : isSelected
                            ? Colors.black
                            : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    decoration: isTaken
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/* ===================================================================
   DATA MODELS
   =================================================================== */
class _Stylist {
  final String name;
  final double rating;
  const _Stylist({required this.name, required this.rating});
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