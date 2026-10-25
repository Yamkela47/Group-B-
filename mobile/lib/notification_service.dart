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
import 'app_theme.dart';          // Custom colors and styles
import 'notifications_screen.dart'; // Screen to view all notifications

/// A background service that listens for new notifications in real-time.
/// When a new notification is inserted into the database for the logged-in user,
/// this service displays a custom floating banner at the top of the screen.
class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BuildContext context;
  
  // List to hold active realtime channels so they can be cleaned up later.
  final List<RealtimeChannel> _channels = [];
  
  // A set to keep track of notification IDs that have already been shown.
  // This prevents the same notification from appearing multiple times.
  final Set<String> _shownIds = {};
  
  // Flag to prevent actions from executing after the widget using this service is disposed.
  bool _disposed = false;

  NotificationService(this.context);

  /// Initializes the service and starts listening for notifications.
  void initialize() {
    _startListening();
  }

  /// Sets up realtime listeners for the 'notifications' table.
  Future<void> _startListening() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _disposed) return;

    // The database schema might use 'profile_id' (from ASP.NET) or 'user_id' (from older Flutter versions).
    // We loop through both possible column names to ensure we catch the notification regardless of schema.
    for (final column in ['profile_id', 'user_id']) {
      try {
        // Test the query to ensure the column exists in the table.
        await _supabase.from('notifications').select().eq(column, user.id).limit(1);
      } on PostgrestException catch (error) {
        // If the column doesn't exist, skip to the next iteration.
        if (_missingColumn(error, column)) continue;
        debugPrint('Cannot check notification recipient field: $error');
        continue;
      } catch (error) {
        debugPrint('Notification listener setup error: $error');
        continue;
      }

      // Ensure the user hasn't changed or the service hasn't been disposed while checking.
      if (_disposed || _supabase.auth.currentUser?.id != user.id) return;

      // Create a realtime channel for this specific column and user.
      final channel = _supabase
          .channel('customer-notifications-$column-${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert, // Listen only to new inserts
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: user.id,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              // Extract the notification ID to ensure we don't show duplicates.
              final id = (record['notification_id'] ?? record['id'])?.toString();
              if (id != null && !_shownIds.add(id)) return;
              
              // Clear the cache if it gets too large to prevent memory leaks.
              if (_shownIds.length > 100) _shownIds.clear();

              // Extract the title and message, then show the custom overlay.
              final title = (record['title'] ?? 'Notification').toString();
              final message = (record['message'] ?? '').toString();
              _showCustomOverlay(title, message);
            },
          )
          .subscribe();

      _channels.add(channel);
    }
  }

  /// Helper method to determine if a Postgrest error is due to a missing column.
  bool _missingColumn(PostgrestException error, String column) {
    final msg = error.message.toLowerCase();
    return (error.code == '42703' || error.code == 'PGRST204' || msg.contains('schema cache')) &&
        msg.contains(column.toLowerCase());
  }

  /// Displays a custom, floating banner at the top of the screen.
  /// This replaces the default Flutter SnackBar for a more premium look.
  void _showCustomOverlay(String title, String message) {
    if (_disposed || !context.mounted) return;

    // Get the overlay of the current context to insert the banner.
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    // Create the overlay entry.
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Position the banner at the top of the screen, accounting for the status bar.
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          // Allows the user to swipe up to dismiss the banner.
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) {
              if (overlayEntry.mounted) overlayEntry.remove();
            },
            // Tapping the banner opens the full Notifications Screen.
            child: GestureDetector(
              onTap: () {
                if (overlayEntry.mounted) overlayEntry.remove();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold, width: 1.2),
                  // Adds a subtle drop shadow to make the banner float above the app.
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The icon box on the left.
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: AppColors.gold, size: 18),
                    ),
                    const SizedBox(width: 12),
                    // The title and message text.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          if (message.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Insert the banner into the screen overlay.
    overlay.insert(overlayEntry);

    // Automatically remove the banner after 5 seconds if the user hasn't dismissed it.
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  /// Cleans up the realtime channels when the service is no longer needed.
  void dispose() {
    _disposed = true;
    for (final channel in _channels) {
      _supabase.removeChannel(channel);
    }
    _channels.clear();
  }
}