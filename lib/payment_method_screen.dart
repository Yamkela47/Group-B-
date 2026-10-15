import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'booking_confirmed_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String service;
  final String servicePrice;
  final String serviceImagePath;
  final String stylist;
  final int stylistId; // <--- ADDED THIS
  final DateTime date;
  final String time;

  const PaymentMethodScreen({
    super.key,
    required this.service,
    required this.servicePrice,
    required this.serviceImagePath,
    required this.stylist,
    required this.stylistId, // <--- ADDED THIS
    required this.date,
    required this.time,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _supabase = Supabase.instance.client;
  String _selectedMethod = 'Cash';
  bool _saving = false;

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

  Future<void> _confirmBooking() async {
    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('You must be signed in.');

      // Convert payment method name to ID (1 = Cash, 2 = Card)
      final paymentMethodId = _selectedMethod == 'Cash' ? 1 : 2;

      // Save the date as YYYY-MM-DD
      final dateStr =
          '${widget.date.year.toString().padLeft(4, '0')}-'
          '${widget.date.month.toString().padLeft(2, '0')}-'
          '${widget.date.day.toString().padLeft(2, '0')}';

      await _supabase.from('bookings').insert({
        'customer_id': user.id,
        'appointment_date': dateStr,
        'start_time': widget.time,
        'status': 'confirmed',
        'payment_method_id': paymentMethodId,
        'stylist_id': widget.stylistId, // <--- ADDED THIS
        // IMPORTANT: If your bookings table requires a service_id, 
        // uncomment the line below and put a valid ID from your services table.
        // 'service_id': 1, 
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingConfirmedScreen(
            service: widget.service,
            stylist: widget.stylist,
            date: _formatLongDate(widget.date),
            time: widget.time,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save booking: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Row(
              children: [
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text('Review & Pay',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Confirm your appointment details below.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          /* ---------- SERVICE CARD ---------- */
          Container(
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
                    widget.serviceImagePath,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.content_cut,
                          color: AppColors.gold, size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.service,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(widget.stylist,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(widget.servicePrice,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          /* ---------- DETAILS ---------- */
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _SummaryRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: _formatLongDate(widget.date)),
                const SizedBox(height: 12),
                _SummaryRow(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: widget.time),
                const SizedBox(height: 12),
                _SummaryRow(
                    icon: Icons.payments_outlined,
                    label: 'Total',
                    value: widget.servicePrice),
              ],
            ),
          ),
          const SizedBox(height: 22),

          /* ---------- PAYMENT METHOD ---------- */
          const Text('Choose a Payment Method',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _PaymentOption(
            icon: Icons.payments_outlined,
            title: 'Cash',
            subtitle: 'Pay at the salon on arrival',
            selected: _selectedMethod == 'Cash',
            onTap: () => setState(() => _selectedMethod = 'Cash'),
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            icon: Icons.credit_card,
            title: 'Card',
            subtitle: 'Tap or insert card on arrival',
            selected: _selectedMethod == 'Card',
            onTap: () => setState(() => _selectedMethod = 'Card'),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No online payment is processed. Your chosen method will be '
                  'used when you pay at the salon.',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.9),
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
              onPressed: _saving ? null : _confirmBooking,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                  : const Text('CONFIRM BOOKING'),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 16),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
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
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.gold : AppColors.textSecondary,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Center(
                      child: Icon(Icons.check,
                          color: AppColors.gold, size: 14),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}