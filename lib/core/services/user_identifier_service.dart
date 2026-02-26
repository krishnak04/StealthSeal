import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class UserIdentifierService {
  static const String _boxName = 'userBox';
  static const String _userIdKey = 'userId';

  static Future<void> initialize() async {
    try {
      await Hive.openBox(_boxName);
      debugPrint('UserIdentifierService initialized');
    } catch (error) {
      debugPrint('Error initializing UserIdentifierService: $error');
    }
  }

  static Future<String> getUserId() async {
    try {
      final userBox = Hive.box(_boxName);

      var userId = userBox.get(_userIdKey) as String?;

      if (userId == null || userId.isEmpty) {

        userId = const Uuid().v4();
        await userBox.put(_userIdKey, userId);
        debugPrint('Generated new user ID: $userId');
      } else {
        debugPrint('Found existing user ID: $userId');
      }

      return userId;
    } catch (error) {
      debugPrint('Error getting user ID: $error');

      return const Uuid().v4();
    }
  }

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
