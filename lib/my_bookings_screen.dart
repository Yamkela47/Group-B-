import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'book_appointment_screen.dart';
import 'services_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tab = TabController(length: 3, vsync: this);

  bool _loading = true;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];
  List<Map<String, dynamic>> _cancelled = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _upcoming = [];
          _past = [];
          _cancelled = [];
          _loading = false;
        });
        return;
      }

      final data = await _supabase
          .from('bookings')
          .select()
          .eq('customer_id', user.id)
          .order('appointment_date', ascending: false);

      final all = List<Map<String, dynamic>>.from(data);
      final now = DateTime.now();

      setState(() {
        _upcoming = all.where((b) {
          final d = DateTime.parse(b['appointment_date']);
          return b['status'] == 'confirmed' && !d.isBefore(DateTime(now.year, now.month, now.day));
        }).toList();

        _past = all.where((b) {
          final d = DateTime.parse(b['appointment_date']);
          return b['status'] == 'completed' ||
              (b['status'] == 'confirmed' && d.isBefore(DateTime(now.year, now.month, now.day)));
        }).toList();

        _cancelled = all.where((b) => b['status'] == 'cancelled').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load bookings: $e')),
      );
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        title: const Text('Cancel booking?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to cancel your '
          '${booking['service_name']} appointment?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', booking['id']);

      await _supabase.from('cancellations').insert({
        'booking_id': booking['id'],
        'cancelled_by': _supabase.auth.currentUser?.id,
        'reason': 'Cancelled by customer',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled.'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _reschedule(Map<String, dynamic> booking) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          initialStylist: booking['stylist_name'],
          service: booking['service_name'],
          price: booking['service_price'],
          showServicePicker: false,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                /* ---------- TITLES ---------- */
                const Text('My Bookings',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('View and manage your appointments.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 20),

                /* ---------- PILL TABS WITH COUNTS ---------- */
                Row(
                  children: [
                    _PillTab(
                      label: 'Upcoming',
                      count: _upcoming.length,
                      selected: _tab.index == 0,
                      onTap: () => setState(() => _tab.index = 0),
                    ),
                    const SizedBox(width: 8),
                    _PillTab(
                      label: 'Past',
                      count: _past.length,
                      selected: _tab.index == 1,
                      onTap: () => setState(() => _tab.index = 1),
                    ),
                    const SizedBox(width: 8),
                    _PillTab(
                      label: 'Cancelled',
                      count: _cancelled.length,
                      selected: _tab.index == 2,
                      onTap: () => setState(() => _tab.index = 2),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                /* ---------- ACTIVE TAB CONTENT ---------- */
                ..._buildTabContent(),
              ],
            ),
    );
  }

  List<Widget> _buildTabContent() {
    final List<Map<String, dynamic>> items;
    final String emptyText;

    switch (_tab.index) {
      case 0:
        items = _upcoming;
        emptyText = 'No upcoming bookings';
        break;
      case 1:
        items = _past;
        emptyText = 'No past bookings';
        break;
      default:
        items = _cancelled;
        emptyText = 'No cancelled bookings';
    }

    if (items.isEmpty) {
      return [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_busy_outlined,
                  color: AppColors.gold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  emptyText,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      ...items.map((b) => _BookingCard(
            booking: b,
            onCancel: _tab.index == 0 ? () => _cancelBooking(b) : null,
            onReschedule: _tab.index == 0 ? () => _reschedule(b) : null,
          )),
      const SizedBox(height: 16),

      /* ---------- INFO BOX ---------- */
      if (_tab.index == 0)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: const [
              Icon(Icons.cancel_outlined,
                  color: AppColors.gold, size: 30),
              SizedBox(height: 12),
              Text('No double bookings allowed!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                'You already have an active booking. '
                'Complete or cancel your current booking before making another.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4),
              ),
            ],
          ),
        ),

      const SizedBox(height: 18),

      /* ---------- BOOK ANOTHER SERVICE ---------- */
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServicesScreen()),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.content_cut, size: 18),
              SizedBox(width: 10),
              Text('BOOK ANOTHER SERVICE'),
            ],
          ),
        ),
      ),
    ];
  }
}

/* ===================================================================
   PILL TAB
   =================================================================== */
class _PillTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PillTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? Colors.black : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/* ===================================================================
   BOOKING CARD
   =================================================================== */
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;

  const _BookingCard({
    required this.booking,
    this.onCancel,
    this.onReschedule,
  });

  String _formatShortDate(String iso) {
    final d = DateTime.parse(iso);
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String _formatTime(String t) =>
      t.length >= 5 ? t.substring(0, 5) : t;

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'confirmed';
    final isCancelled = status == 'cancelled';
    final isCompleted = status == 'completed';
    final statusColor = isCancelled
        ? AppColors.error
        : isCompleted
            ? AppColors.gold
            : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ---------- IMAGE ---------- */
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/service_default.jpg',
              width: 80,
              height: 108,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 108,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withOpacity(0.4)),
                ),
                child: const Icon(Icons.content_cut,
                    color: AppColors.gold, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),

          /* ---------- CONTENT ---------- */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /* Service name + status badge */
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        booking['service_name'] ?? '—',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                /* Date */
                _DetailLine(
                  icon: Icons.calendar_today_outlined,
                  text: _formatShortDate(booking['appointment_date']),
                ),
                const SizedBox(height: 5),

                /* Time */
                _DetailLine(
                  icon: Icons.access_time,
                  text: _formatTime(booking['start_time']),
                ),
                const SizedBox(height: 5),

                /* Stylist */
                _DetailLine(
                  icon: Icons.person_outline,
                  text: booking['stylist_name'] ?? '—',
                ),
                const SizedBox(height: 5),

                /* Payment */
                _DetailLine(
                  icon: Icons.credit_card,
                  text: booking['payment_method'] ?? 'Cash',
                ),

                const SizedBox(height: 12),

                /* ---------- ACTION BUTTONS ---------- */
                if (onCancel != null && onReschedule != null)
                  Row(
                    children: [
                      /* Confirmed pill (static) */
                      _ActionPill(
                        label: 'Confirmed',
                        color: AppColors.success,
                        onTap: null,
                      ),
                      const SizedBox(width: 6),
                      /* Reschedule */
                      _ActionPill(
                        label: 'Reschedule',
                        color: AppColors.gold,
                        onTap: onReschedule!,
                      ),
                      const SizedBox(width: 6),
                      /* Cancel */
                      _ActionPill(
                        label: 'Cancel',
                        color: AppColors.error,
                        onTap: onCancel!,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================================================================
   DETAIL LINE (icon + text)
   =================================================================== */
class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 13),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 12.5),
        ),
      ],
    );
  }
}

/* ===================================================================
   ACTION PILL BUTTON
   =================================================================== */
class _ActionPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: onTap == null
                ? color.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}