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
import 'app_theme.dart';                 // Custom colors and styles
import 'notification_details_screen.dart'; // Screen to view the full notification

/// A screen that displays the user's notifications.
/// It uses a TabBar to separate notifications into Unread and Read tabs.
/// It fetches data from Supabase and listens for realtime updates.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

// SingleTickerProviderStateMixin is used for the TabController.
// WidgetsBindingObserver is used to detect when the app is resumed so we can refresh.
class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final TabController _tabController;
  
  // Realtime channel to listen for new notifications
  RealtimeChannel? _channel;

  // State variables
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _unreadNotifs = [];
  List<Map<String, dynamic>> _readNotifs = [];

  @override
  void initState() {
    super.initState();
    // Initialize the TabController with 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    
    // Add observer to detect app lifecycle changes (e.g., app minimized then resumed)
    WidgetsBinding.instance.addObserver(this);
    
    // Fetch initial data and start listening for realtime updates
    _loadNotifications();
    _subscribeToChanges();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the user comes back to the app, refresh the notifications silently
    if (state == AppLifecycleState.resumed) {
      _loadNotifications(showLoading: false);
    }
  }

  @override
  void dispose() {
    // Clean up resources to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    _channel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  /// Fetches the notifications from Supabase.
  /// [showLoading] determines whether to show the full-screen spinner.
  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _loading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Please sign in to view your notifications.';
          });
        }
        return;
      }

      // Fetch notifications. We use `.or()` to check both `user_id` and `profile_id`
      // because the database schema might use either one depending on the backend.
      final data = await _supabase
          .from('notifications')
          .select()
          .or('user_id.eq.${user.id},profile_id.eq.${user.id}') 
          .order('created_at', ascending: false); // Newest first

      final all = List<Map<String, dynamic>>.from(data);

      if (!mounted) return;
      setState(() {
        // Separate the list into unread and read notifications
        _unreadNotifs = all.where((n) => n['is_read'] != true).toList();
        _readNotifs = all.where((n) => n['is_read'] == true).toList();
        _error = null;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Error loading notifications: $error');
      if (!mounted) return;
      setState(() {
        _error = 'Could not load notifications. Pull down to try again.';
        _loading = false;
      });
    }
  }

  /// Sets up a realtime listener for the 'notifications' table.
  /// Any insert or update will trigger a silent reload of the list.
  void _subscribeToChanges() {
    final user = _supabase.auth.currentUser;
    if (user == null || _channel != null) return;

    _channel = _supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Listen to inserts, updates, and deletes
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            // Reload the notifications list without showing the spinner
            _loadNotifications(showLoading: false);
          },
        )
        .subscribe();
  }

  /// Handles the tap event on a single notification.
  /// It marks the notification as "read" in the database and local state, 
  /// then navigates to the details screen.
  Future<void> _handleNotificationTap(Map<String, dynamic> notif) async {
    final title = (notif['title'] ?? 'Notification').toString();
    final message = (notif['message'] ?? '').toString();
    final notificationType = notif['notification_type']?.toString();
    final createdAt = DateTime.tryParse((notif['created_at'] ?? '').toString());

    // If the notification is unread, mark it as read
    if (notif['is_read'] != true) {
      // The primary key might be named 'notification_id' or 'id'
      final idColumn = notif.containsKey('notification_id') ? 'notification_id' : 'id';
      final id = notif[idColumn];

      // Optimistically update the UI immediately
      setState(() {
        _unreadNotifs.removeWhere((n) => identical(n, notif));
        _readNotifs.insert(0, {...notif, 'is_read': true});
      });

      // Update the database in the background
      if (id != null) {
        try {
          await _supabase.from('notifications').update({'is_read': true}).eq(idColumn, id);
        } catch (error) {
          debugPrint('Could not mark notification as read: $error');
        }
      }
    }

    if (!mounted) return;
    // Navigate to the details screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailsScreen(
          title: title,
          message: message,
          notificationType: notificationType,
          createdAt: createdAt,
        ),
      ),
    );
    
    // Refresh the list when returning from the details screen
    if (mounted) _loadNotifications(showLoading: false);
  }

  /// Determines which icon to show based on the notification's content.
  IconData _iconFor(Map<String, dynamic> notification) {
    final text = '${notification['notification_type'] ?? ''} ${notification['title'] ?? ''}'.toLowerCase();
    if (text.contains('apology') || text.contains('apologise') || text.contains('apologize')) return Icons.favorite_border;
    if (text.contains('cancel')) return Icons.cancel_outlined;
    if (text.contains('promo')) return Icons.local_offer_outlined;
    if (text.contains('booking') || text.contains('appointment') || text.contains('reschedul')) return Icons.calendar_month_outlined;
    return Icons.notifications_none;
  }

  /// Formats a raw timestamp into a readable date and time string.
  String _dateLabel(dynamic date) {
    // Convert to local time
    final dt = DateTime.tryParse((date ?? '').toString())?.toLocal();
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        // The TabBar sits at the bottom of the AppBar
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [Tab(text: 'UNREAD'), Tab(text: 'READ')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadNotifications, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Unread Notifications
                    _buildList(_unreadNotifs, 'No unread notifications.'),
                    // Tab 2: Read Notifications
                    _buildList(_readNotifs, 'No read notifications.'),
                  ],
                ),
    );
  }

  /// Builds the list of notifications for a given tab.
  Widget _buildList(List<Map<String, dynamic>> items, String emptyText) {
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceAlt,
      onRefresh: () => _loadNotifications(showLoading: false),
      child: items.isEmpty
          // Empty state when there are no notifications
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.55,
                  child: Center(child: Text(emptyText, style: const TextStyle(color: AppColors.textMuted))),
                ),
              ],
            )
          // List of notifications
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final notif = items[index];
                final unread = notif['is_read'] != true;
                final title = (notif['title'] ?? 'Notification').toString();
                final message = (notif['message'] ?? '').toString();

                return InkWell(
                  onTap: () => _handleNotificationTap(notif),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      // Unread notifications have a gold border, read ones have a standard border
                      border: Border.all(
                        color: unread ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border, 
                        width: unread ? 1.5 : 1
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon box
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Icon(_iconFor(notif), color: AppColors.gold, size: 20),
                        ),
                        const SizedBox(width: 14),
                        // Text content (Title, Message, Date)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title, 
                                style: TextStyle(
                                  color: Colors.white, 
                                  fontSize: 14, 
                                  fontWeight: unread ? FontWeight.w700 : FontWeight.w500
                                )
                              ),
                              if (message.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                              const SizedBox(height: 6),
                              Text(_dateLabel(notif['created_at']), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        // Unread indicator dot
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5), decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}