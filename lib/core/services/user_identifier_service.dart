import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Service to manage unique user identification
/// Each device/user gets a unique ID stored locally
class UserIdentifierService {
  static const String _boxName = 'userBox';
  static const String _userIdKey = 'userId';

  static Future<void> initialize() async {
    try {
      await Hive.openBox(_boxName);
      debugPrint('✅ UserIdentifierService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing UserIdentifierService: $e');
    }
  }

  /// Get or create a unique user ID for this device
  static Future<String> getUserId() async {
    try {
      final box = Hive.box(_boxName);
      
      // Check if user already has an ID
      var userId = box.get(_userIdKey) as String?;
      
      if (userId == null || userId.isEmpty) {
        // Generate new UUID for this user
        userId = const Uuid().v4();
        await box.put(_userIdKey, userId);
        debugPrint('🆕 Generated new user ID: $userId');
      } else {
        debugPrint('✅ Found existing user ID: $userId');
      }
      
      return userId;
    } catch (e) {
      debugPrint('❌ Error getting user ID: $e');
      // Fallback: generate a one-time UUID if Hive fails
      return const Uuid().v4();
    }
  }

  /// Clear user ID (for logout/reset)
  static Future<void> clearUserId() async {
    try {
      final box = Hive.box(_boxName);
      await box.delete(_userIdKey);
      debugPrint('🗑️ User ID cleared');
    } catch (e) {
      debugPrint('❌ Error clearing user ID: $e');
    }
  }
}
