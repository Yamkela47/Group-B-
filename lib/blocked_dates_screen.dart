import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bars.dart';
import 'buttons.dart';
import 'cards.dart';
import 'stylist_session.dart';

class BlockedDatesScreen extends StatefulWidget {
  const BlockedDatesScreen({super.key});
  @override
  State<BlockedDatesScreen> createState() => _BlockedDatesScreenState();
}

class _BlockedDatesScreenState extends State<BlockedDatesScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  dynamic _stylistId;
  List<Map<String, dynamic>> _blocked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

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

      final rows = await _supabase
          .from('blocked_dates')
          .select()
          .eq('stylist_id', id)
          .order('blocked_date', ascending: true);

      if (!mounted) return;
      setState(() {
        _blocked = List<Map<String, dynamic>>.from(rows as List);
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

  Future<void> _addBlockedDate() async {
    if (_stylistId == null) return;
    final now = DateTime.now();
    
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
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
    if (picked == null) return;

    final dateStr = '${picked.year}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';

    // Show loading indicator while checking database
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      // 👇 BULLETPROOF CHECK 👇
      // Fetch ALL bookings for this date for this stylist.
      // We don't filter by status in the database query to avoid case-sensitivity bugs.
      final allBookings = await _supabase
          .from('bookings')
          .select('booking_id, status')
          .eq('stylist_id', _stylistId!)
          .eq('appointment_date', dateStr);

      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator

      // Check status in Dart (case-insensitive)
      final activeConflicts = (allBookings as List).where((b) {
        final s = (b['status'] ?? '').toString().toLowerCase();
        // If it's cancelled, completed, or no-show, ignore it. Otherwise, it's a conflict.
        return !s.contains('cancel') && 
               !s.contains('complet') && 
               !s.contains('no_show') && 
               !s.contains('noshow');
      }).toList();

      if (activeConflicts.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceAlt,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.error)),
            title: const Text('Action Restricted',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w800)),
            content: Text(
                'You cannot block this date because you have ${activeConflicts.length} active customer appointment(s) scheduled for $dateStr.\n\n'
                'You must either complete the appointments, mark them as a no-show, or have the customer cancel them before blocking this date.',
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Understood',
                      style: TextStyle(
                          color: AppColors.gold, fontWeight: FontWeight.bold))),
            ],
          ),
        );
        return; // Stop execution here
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error checking availability: $e'),
          backgroundColor: AppColors.error));
      return;
    }

    // 👇 If no conflicts, allow blocking the date 👇
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border)),
        title: const Text('Block this date?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No active appointments on $dateStr. This date will be '
              'removed from your booking availability.',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4),
            ),
            const SizedBox(height: 14),
            const Text('Reason (optional)',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Public holiday, personal leave',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.gold)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block date',
                  style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (ok != true) return;

    try {
      await _supabase.from('blocked_dates').insert({
        'stylist_id': _stylistId,
        'blocked_date': dateStr,
        'reason': reason.isEmpty ? null : reason,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Date blocked successfully'),
          backgroundColor: AppColors.success));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not block: $e'),
          backgroundColor: AppColors.error));
    }
  }

  Future<void> _unblock(String id) async {
    try {
      await _supabase.from('blocked_dates').delete().eq('id', id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not unblock: $e'),
          backgroundColor: AppColors.error));
    }
  }

  String _formatDate(String iso) {
    final d = DateTime.parse(iso);
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenAppBar(title: 'Blocked Dates'),
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
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.info_outline,
                                color: AppColors.gold, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  'Blocked dates are hidden from customers. '
                                  'You cannot block a date if you have active '
                                  'appointments on it.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeading(text: 'Your Blocked Dates'),
                      if (_blocked.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text('No blocked dates yet',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                          ),
                        )
                      else
                        ..._blocked.map((b) => AppCard(
                              margin:
                                  const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.block,
                                      color: AppColors.gold, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            _formatDate(
                                                b['blocked_date']),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        if ((b['reason'] as String?)
                                                ?.isNotEmpty ??
                                            false) ...[
                                          const SizedBox(height: 2),
                                          Text(b['reason'],
                                              style: const TextStyle(
                                                  color: AppColors
                                                      .textSecondary,
                                                  fontSize: 11.5)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: AppColors.textSecondary,
                                        size: 18),
                                    onPressed: () =>
                                        _unblock(b['id'].toString()),
                                  ),
                                ],
                              ),
                            )),
                      const SizedBox(height: 22),
                      GoldButton(
                          label: 'Block a New Date',
                          icon: Icons.add,
                          onPressed: _addBlockedDate),
                    ],
                  ),
                ),
    );
  }
}
