import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Manages a unique per-device user identifier stored in Hive.
///
/// On first launch a UUID is generated and persisted locally.
/// Subsequent calls return the same ID until it is explicitly cleared.
class UserIdentifierService {
  static const String _boxName = 'userBox';
  static const String _userIdKey = 'userId';

  /// Opens the Hive box used for user identification.
  static Future<void> initialize() async {
    try {
      await Hive.openBox(_boxName);
      debugPrint('UserIdentifierService initialized');
    } catch (error) {
      debugPrint('Error initializing UserIdentifierService: $error');
    }
  }

  /// Returns the existing user ID, or generates and persists a new one.
  static Future<String> getUserId() async {
    try {
      final userBox = Hive.box(_boxName);

      // Check if user already has an ID
      var userId = userBox.get(_userIdKey) as String?;

      if (userId == null || userId.isEmpty) {
        // Generate new UUID for this user
        userId = const Uuid().v4();
        await userBox.put(_userIdKey, userId);
        debugPrint('Generated new user ID: $userId');
      } else {
        debugPrint('Found existing user ID: $userId');
      }

      return userId;
    } catch (error) {
      debugPrint('Error getting user ID: $error');
      // Fallback: generate a one-time UUID if Hive fails
      return const Uuid().v4();
    }
  }

  /// Deletes the stored user ID (e.g., on logout or factory reset).
  static Future<void> clearUserId() async {
    try {
      final userBox = Hive.box(_boxName);
      await userBox.delete(_userIdKey);
      debugPrint('User ID cleared');
    } catch (error) {
      debugPrint('Error clearing user ID: $error');
    }
  }
}
