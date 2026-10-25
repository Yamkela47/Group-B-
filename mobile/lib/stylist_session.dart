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

import 'package:supabase_flutter/supabase_flutter.dart';

/// A utility class used to manage the current Stylist's session data.
/// Its primary purpose is to fetch the `stylist_id` associated with the 
/// currently logged-in user and cache it.
class StylistSession {
  static dynamic _cachedId;
  static String? _cachedUserId;
  static String? lastError;

  /// Resolves the `stylist_id` for the currently authenticated user.
  static Future<dynamic> resolve({bool forceRefresh = false}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    if (!forceRefresh && _cachedUserId == user.id) return _cachedId;

    try {
      final row = await Supabase.instance.client
          .from('stylists')
          .select('stylist_id')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (row == null) {
        lastError = 'No row found in "stylists" table for user ${user.id}.';
      }

      _cachedId = row?['stylist_id'];
      _cachedUserId = user.id;
      return _cachedId;
    } catch (e) {
      lastError = 'Database error: $e';
      return null;
    }
  }

  /// Clears the cached data.
  static void clear() {
    _cachedId = null;
    _cachedUserId = null;
    lastError = null;
  }
}