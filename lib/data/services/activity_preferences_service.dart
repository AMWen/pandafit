import 'package:hive/hive.dart';
import '../constants.dart';
import '../models/custom_exercise_preferences.dart';

/// Service for managing user activities using Hive
class ActivityPreferencesService {
  static const String _userActivitiesBox = HiveBoxNames.userActivities;

  // Get all saved user activities
  static Future<List<UserActivity>> getAllActivities() async {
    final box = await Hive.openBox<UserActivity>(_userActivitiesBox);
    return box.values.toList();
  }

  // Get a specific activity by name
  static Future<UserActivity?> getActivity(String name) async {
    final box = await Hive.openBox<UserActivity>(_userActivitiesBox);
    return box.get(name);
  }

  // Save or update an activity (used when logging activities)
  // If activity exists, updates the duration only if different
  static Future<void> saveOrUpdateActivity(String name, int duration) async {
    final box = await Hive.openBox<UserActivity>(_userActivitiesBox);

    // Check if activity already exists
    final existing = box.get(name);

    if (existing == null) {
      // New activity - save it
      final newActivity = UserActivity(
        name: name,
        usualDurationMinutes: duration,
      );
      await box.put(name, newActivity);
    } else {
      // Activity exists - optionally update duration
      // For now, we keep the original duration to maintain consistency
      // User can manually update in settings if needed
    }
  }

  // Update an existing activity (for manual edits in settings)
  static Future<void> updateActivity(UserActivity activity) async {
    final box = await Hive.openBox<UserActivity>(_userActivitiesBox);
    await box.put(activity.name, activity);
  }

  // Add a new activity (with duplicate check)
  static Future<bool> addActivity(UserActivity activity) async {
    final box = await Hive.openBox<UserActivity>(_userActivitiesBox);

    // Check for duplicates (case-insensitive)
    final isDuplicate = box.values.any(
      (a) => a.name.toLowerCase() == activity.name.toLowerCase()
    );

    if (isDuplicate) {
      return false; // Duplicate found, don't add
    }

    // Use name as key for easy lookups
    await box.put(activity.name, activity);
    return true; // Successfully added
  }

  // Delete an activity
  static Future<void> deleteActivity(String name) async {
    final box = await Hive.openBox<UserActivity>(_userActivitiesBox);
    await box.delete(name);
  }

  // Get all activity names (for autocomplete)
  static Future<List<String>> getActivityNames() async {
    final activities = await getAllActivities();
    return activities.map((a) => a.name).toList();
  }

  // Utility: Clear all activities (useful for testing/reset)
  static Future<void> clearAllActivities() async {
    await Hive.deleteBoxFromDisk(_userActivitiesBox);
  }
}
