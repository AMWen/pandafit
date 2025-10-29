import 'package:hive/hive.dart';
import '../models/custom_exercise_preferences.dart';

/// Service for managing workout preferences using Hive
class WorkoutPreferencesService {
  static const String _customExercisePrefsBox = 'customExercisePreferences';
  static const String _userCustomExercisesBox = 'userCustomExercises';
  static const String _workoutGenPrefsBox = 'workoutGenerationPreferences';
  static const String _workoutGenPrefsKey = 'preferences';

  // Get all custom exercise preferences
  static Future<List<CustomExercisePreference>> getCustomExercisePreferences() async {
    final box = await Hive.openBox<CustomExercisePreference>(_customExercisePrefsBox);
    return box.values.toList();
  }

  // Add or update a custom exercise preference
  static Future<void> setCustomExercisePreference(CustomExercisePreference preference) async {
    final box = await Hive.openBox<CustomExercisePreference>(_customExercisePrefsBox);
    // Use exercise name as key for easy lookups and updates
    await box.put(preference.exerciseName, preference);
  }

  // Remove a custom exercise preference (reset to default)
  static Future<void> removeCustomExercisePreference(String exerciseName) async {
    final box = await Hive.openBox<CustomExercisePreference>(_customExercisePrefsBox);
    await box.delete(exerciseName);
  }

  // Get preference for a specific exercise
  static Future<CustomExercisePreference?> getPreferenceForExercise(String exerciseName) async {
    final box = await Hive.openBox<CustomExercisePreference>(_customExercisePrefsBox);
    return box.get(exerciseName);
  }

  // Get all exercises marked as "always include"
  static Future<List<String>> getAlwaysIncludeExercises() async {
    final customPrefs = await getCustomExercisePreferences();
    final customExercises = await getUserCustomExercises();

    final alwaysIncludeNames = <String>[];

    // From custom preferences
    alwaysIncludeNames.addAll(
      customPrefs
          .where((p) => p.alwaysInclude)
          .map((p) => p.exerciseName)
    );

    // From user custom exercises
    alwaysIncludeNames.addAll(
      customExercises
          .where((ex) => ex.alwaysInclude)
          .map((ex) => ex.name)
    );

    return alwaysIncludeNames;
  }

  // Get all exercises marked as "never include"
  static Future<List<String>> getNeverIncludeExercises() async {
    final customPrefs = await getCustomExercisePreferences();

    final neverIncludeNames = <String>[];

    // From custom preferences
    neverIncludeNames.addAll(
      customPrefs
          .where((p) => p.neverInclude)
          .map((p) => p.exerciseName)
    );

    return neverIncludeNames;
  }

  // User-added custom exercises (not in default database)
  static Future<List<UserCustomExercise>> getUserCustomExercises() async {
    final box = await Hive.openBox<UserCustomExercise>(_userCustomExercisesBox);
    return box.values.toList();
  }

  // Add a user custom exercise (with duplicate check)
  static Future<bool> addUserCustomExercise(UserCustomExercise exercise) async {
    final box = await Hive.openBox<UserCustomExercise>(_userCustomExercisesBox);

    // Check for duplicates (case-insensitive)
    final isDuplicate = box.values.any(
      (ex) => ex.name.toLowerCase() == exercise.name.toLowerCase()
    );

    if (isDuplicate) {
      return false; // Duplicate found, don't add
    }

    // Use name as key for easy lookups
    await box.put(exercise.name, exercise);
    return true; // Successfully added
  }

  // Update an existing user custom exercise
  static Future<void> updateUserCustomExercise(UserCustomExercise exercise) async {
    final box = await Hive.openBox<UserCustomExercise>(_userCustomExercisesBox);
    await box.put(exercise.name, exercise);
  }

  // Remove a user custom exercise
  static Future<void> removeUserCustomExercise(String exerciseName) async {
    final box = await Hive.openBox<UserCustomExercise>(_userCustomExercisesBox);
    await box.delete(exerciseName);
  }

  // Get workout generation preferences
  static Future<WorkoutGenerationPreferences> getWorkoutGenerationPreferences() async {
    final box = await Hive.openBox<WorkoutGenerationPreferences>(_workoutGenPrefsBox);
    final prefs = box.get(_workoutGenPrefsKey);

    if (prefs == null) {
      // Return defaults if not set
      final defaultPrefs = WorkoutGenerationPreferences();
      await box.put(_workoutGenPrefsKey, defaultPrefs);
      return defaultPrefs;
    }

    return prefs;
  }

  // Save workout generation preferences
  static Future<void> saveWorkoutGenerationPreferences(WorkoutGenerationPreferences preferences) async {
    final box = await Hive.openBox<WorkoutGenerationPreferences>(_workoutGenPrefsBox);
    await box.put(_workoutGenPrefsKey, preferences);
  }

  // Utility: Clear all workout preferences (useful for testing/reset)
  static Future<void> clearAllPreferences() async {
    await Hive.deleteBoxFromDisk(_customExercisePrefsBox);
    await Hive.deleteBoxFromDisk(_userCustomExercisesBox);
    await Hive.deleteBoxFromDisk(_workoutGenPrefsBox);
  }
}
