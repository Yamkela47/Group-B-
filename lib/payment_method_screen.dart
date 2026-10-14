import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'booking_confirmed_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String service;
  final String servicePrice;
  final String serviceImagePath;
  final String stylist;
  final DateTime date;
  final String time;

  const PaymentMethodScreen({
    super.key,
    required this.service,
    required this.servicePrice,
    required this.serviceImagePath,
    required this.stylist,
    required this.date,
    required this.time,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _supabase = Supabase.instance.client;
  String _payment = 'Cash';
  bool _loading = false;

  String _formatShortDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
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

  void _message(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool> _isSlotTaken() async {
    try {
      final dateStr =
          '${widget.date.year.toString().padLeft(4, '0')}-'
          '${widget.date.month.toString().padLeft(2, '0')}-'
          '${widget.date.day.toString().padLeft(2, '0')}';

      final data = await _supabase
          .from('bookings')
          .select('id')
          .eq('stylist_name', widget.stylist)
          .eq('appointment_date', dateStr)
          .eq('start_time', '${widget.time}:00')
          .neq('status', 'cancelled')
          .limit(1);

      return (data as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmBooking() async {
    setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _message('You must be signed in to book.',
            color: AppColors.error);
        return;
      }

      /* ---------- App-side conflict check ---------- */
      final taken = await _isSlotTaken();
      if (!mounted) return;

      if (taken) {
        _message(
          '${widget.stylist} is already booked at ${widget.time} on '
          '${_formatShortDate(widget.date)}.',
          color: AppColors.error,
        );
        return;
      }

      final dateStr =
          '${widget.date.year.toString().padLeft(4, '0')}-'
          '${widget.date.month.toString().padLeft(2, '0')}-'
          '${widget.date.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('bookings')
          .insert({
            'customer_id': user.id,
            'stylist_name': widget.stylist,
            'service_name': widget.service,
            'service_price': widget.servicePrice,
            'appointment_date': dateStr,
            'start_time': '${widget.time}:00',
            'payment_method': _payment,
            'status': 'confirmed',
          })
          .select()
          .single();

      if (!mounted) return;
      final bookingId = response['id'] as String;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmedScreen(
            bookingId: bookingId,
            service: widget.service,
            serviceImagePath: widget.serviceImagePath,
            stylist: widget.stylist,
            date: _formatShortDate(widget.date),
            time: widget.time,
            payment: _payment,
            total: widget.servicePrice,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _message(
          'That slot was just taken. Please pick another time.',
          color: AppColors.error,
        );
      } else {
        _message('Could not save booking: ${e.message}',
            color: AppColors.error);
      }
    } catch (e) {
      _message('Something went wrong. Please try again.',
          color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        actions: const [SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          /* ---------- PAGE TITLE ---------- */
          const Text('Payment Method',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('How would you like to pay?',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 22),

          /* ---------- BOOKING SUMMARY ---------- */
          _SummaryCard(
            service: widget.service,
            stylist: widget.stylist,
            date: _formatLongDate(widget.date),
            time: widget.time,
            total: widget.servicePrice,
          ),
          const SizedBox(height: 24),

          /* ---------- PAYMENT OPTIONS ---------- */
          const Text('Choose a Payment Method',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          _PayOption(
            icon: Icons.payments_outlined,
            label: 'Cash',
            subtitle: 'Pay at the salon on arrival',
            selected: _payment == 'Cash',
            onTap: () => setState(() => _payment = 'Cash'),
          ),
          const SizedBox(height: 12),
          _PayOption(
            icon: Icons.credit_card,
            label: 'Card',
            subtitle: 'Tap or insert card on arrival',
            selected: _payment == 'Card',
            onTap: () => setState(() => _payment = 'Card'),
          ),

          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, color: AppColors.gold, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No online payment is processed. Your chosen method will be '
                  'used when you pay at the salon.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
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
              onPressed: _loading ? null : _confirmBooking,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Text('CONFIRM BOOKING'),
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================================================================
   SUMMARY CARD
   =================================================================== */
class _SummaryCard extends StatelessWidget {
  final String service;
  final String stylist;
  final String date;
  final String time;
  final String total;

  const _SummaryCard({
    required this.service,
    required this.stylist,
    required this.date,
    required this.time,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _SummaryRow(
              icon: Icons.content_cut, label: 'Service', value: service),
          const _RowDivider(),
          _SummaryRow(
              icon: Icons.person_outline, label: 'Stylist', value: stylist),
          const _RowDivider(),
          _SummaryRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: date),
          const _RowDivider(),
          _SummaryRow(icon: Icons.access_time, label: 'Time', value: time),
          const _RowDivider(),
          _SummaryRow(
              icon: Icons.local_offer_outlined,
              label: 'Total',
              value: total,
              valueIsGold: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool valueIsGold;

  const _SummaryRow({
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
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
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

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.gold.withOpacity(0.25),
    );
  }
}

/* ===================================================================
   PAY OPTION
   =================================================================== */
class _PayOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PayOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withOpacity(0.08)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? AppColors.gold
                    : AppColors.textSecondary,
                size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.gold : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppColors.gold, size: 22),
          ],
        ),
      ),
    );
  }
}