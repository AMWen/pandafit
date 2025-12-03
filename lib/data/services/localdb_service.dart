import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/exercise_model.dart';
import '../models/core_exercise_model.dart';
import '../models/activity_model.dart';
import '../models/history_models.dart';

class WeightSuggestion {
  final double weight;
  final String? motivationalMessage;

  WeightSuggestion({
    required this.weight,
    this.motivationalMessage,
  });
}

class LocalDB {
  static Database? _db;

  // Helper function to filter out core workouts and activities from exercise data
  static List<Exercise> _filterRegularExercises(List<dynamic> data) {
    return data
        .where((item) => item is! Map || (item['isCore'] != true && item['isActivity'] != true))
        .map((item) => Exercise.fromJson(item))
        .toList();
  }


  static const String _createIncompleteWorkoutsTable = '''
    CREATE TABLE incomplete_workouts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT,
      muscle_group TEXT,
      exercises TEXT,
      UNIQUE(date, muscle_group)
    )
  ''';

  // For activities, we need to track each activity separately to avoid 2MB limit
  // We'll use muscle_group format: 'Other Activities|{activityName}|{completedAt}'
  // Public so Excel import can use it
  static String getActivityMuscleGroupKey(Activity activity) {
    final baseName = 'Other Activities|${activity.name}';
    if (activity.completedAt != null) {
      return '$baseName|${activity.completedAt!.toIso8601String()}';
    }
    return baseName;
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'pandafit_workout.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        // New installations use the new schema (v3)
        await db.execute('''
        CREATE TABLE workout_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          muscle_group TEXT NOT NULL,
          exercises TEXT NOT NULL,
          UNIQUE(date, muscle_group)
        )
      ''');
        await db.execute(_createIncompleteWorkoutsTable);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_createIncompleteWorkoutsTable);
        }
        if (oldVersion < 3) {
          await _migrateFromV2ToV3(db);
        }
      },
    );

    return _db!;
  }

  // Migrate from v2 schema to v3 schema (called automatically during onUpgrade)
  static Future<void> _migrateFromV2ToV3(Database db) async {
    // Read all existing data from old schema
    final oldLogs = await db.query('workout_logs');

    if (oldLogs.isEmpty) {
      // No data to migrate, just update schema
      await _updateSchemaToNew(db);
      return;
    }

    // Create new table with updated schema
    await db.execute('''
      CREATE TABLE workout_logs_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        exercises TEXT NOT NULL,
        UNIQUE(date, muscle_group)
      )
    ''');

    // Transform and insert data
    for (var log in oldLogs) {
      final date = log['date'] as String;
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      // Group exercises by muscle group (for regular exercises and core)
      final Map<String, List<dynamic>> regularExercisesByGroup = {};
      // Store activities separately (one row per activity)
      final List<Map<String, dynamic>> separateActivityRows = [];

      for (var item in exercisesJson) {
        if (item is! Map) continue;

        if (item['isCore'] == true) {
          // Core workout
          final muscleGroup = muscleGroupToString(MuscleGroup.core);
          if (!regularExercisesByGroup.containsKey(muscleGroup)) {
            regularExercisesByGroup[muscleGroup] = [];
          }
          regularExercisesByGroup[muscleGroup]!.add(item);
        } else if (item['isActivity'] == true) {
          // Activities - split each activity into its own row to avoid 2MB limit
          final activities = (item['activities'] as List);
          for (var activityMap in activities) {
            final activity = Activity.fromMap(activityMap);
            final activityKey = getActivityMuscleGroupKey(activity);

            // Create separate row for each activity
            separateActivityRows.add({
              'date': date,
              'muscle_group': activityKey,
              'exercises': jsonEncode([{
                'isActivity': true,
                'activities': [activityMap],
              }]),
            });
          }
        } else {
          // Regular exercise
          final exerciseMuscleGroup = item['muscleGroup'] as String?;
          if (exerciseMuscleGroup != null) {
            if (!regularExercisesByGroup.containsKey(exerciseMuscleGroup)) {
              regularExercisesByGroup[exerciseMuscleGroup] = [];
            }
            regularExercisesByGroup[exerciseMuscleGroup]!.add(item);
          }
        }
      }

      // Insert regular exercises/core (grouped by muscle group)
      for (var entry in regularExercisesByGroup.entries) {
        await db.insert('workout_logs_new', {
          'date': date,
          'muscle_group': entry.key,
          'exercises': jsonEncode(entry.value),
        });
      }

      // Insert activity rows (one per activity)
      for (var activityRow in separateActivityRows) {
        await db.insert('workout_logs_new', activityRow);
      }
    }

    // Replace old table with new table
    await db.execute('DROP TABLE workout_logs');
    await db.execute('ALTER TABLE workout_logs_new RENAME TO workout_logs');
  }

  // Update schema without data migration (for empty databases)
  static Future<void> _updateSchemaToNew(Database db) async {
    await db.execute('DROP TABLE IF EXISTS workout_logs');
    await db.execute('''
      CREATE TABLE workout_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        exercises TEXT NOT NULL,
        UNIQUE(date, muscle_group)
      )
    ''');
  }

  // Insert a completed workout (appends if same day, different target area)
  static Future<void> insertWorkout(WorkoutRoutine routine, [String? date]) async {
    // Filter out skipped exercises - only save completed ones
    final completedExercises = routine.exercises
        .where((ex) => isExerciseCompleted(ex))
        .toList();

    // Don't insert empty workouts
    if (completedExercises.isEmpty) {
      return;
    }

    final db = await database;
    if (date == null) {
      final now = DateTime.now();
      date = now.toIso8601String().substring(0, 10);
    }

    final muscleGroup = muscleGroupToString(routine.targetArea);

    // Check if there's already a workout for this date and muscle group
    final existing = await db.query('workout_logs',
      where: 'date = ? AND muscle_group = ?',
      whereArgs: [date, muscleGroup]);

    if (existing.isNotEmpty) {
      // Append to existing muscle group workout
      final existingData = jsonDecode(existing.first['exercises'] as String) as List;
      final allData = [...existingData, ...completedExercises.map((e) => e.toJson())];

      await db.update('workout_logs', {
        'exercises': jsonEncode(allData),
      }, where: 'date = ? AND muscle_group = ?', whereArgs: [date, muscleGroup]);
    } else {
      // Insert new muscle group workout
      await db.insert('workout_logs', {
        'date': date,
        'muscle_group': muscleGroup,
        'exercises': jsonEncode(completedExercises.map((e) => e.toJson()).toList()),
      });
    }
  }

  // Get workout for a specific date (returns first regular muscle group workout found)
  // Note: With new schema, there can be multiple muscle groups per date.
  // For getting all workouts by muscle group, use getWorkoutsByMuscleGroup instead.
  static Future<WorkoutRoutine?> getRoutineForDate(DateTime date) async {
    final db = await LocalDB.database;
    final dateString = date.toIso8601String().substring(0, 10);

    final results = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateString]);

    if (results.isEmpty) {
      return null;
    }

    // Find the first row that's a regular workout (not Core or Other Activities)
    for (var row in results) {
      final muscleGroupStr = row['muscle_group'] as String;

      // Skip core and activities muscle groups
      if (muscleGroupStr == muscleGroupToString(MuscleGroup.core) ||
          muscleGroupStr.startsWith(muscleGroupToString(MuscleGroup.otherActivity))) {
        continue;
      }

      final exercisesJson = jsonDecode(row['exercises'] as String) as List;
      final exercises = exercisesJson.map((e) => Exercise.fromJson(e)).toList();

      if (exercises.isEmpty) {
        continue; // Skip empty workouts
      }

      final targetArea = exercises.first.muscleGroup; // Use first exercise's muscle group

      return WorkoutRoutine(
        targetArea: targetArea,
        exercises: exercises,
      );
    }

    return null; // No regular exercises found
  }

  // Get workouts for a specific date grouped by muscle group
  // Returns a map with Exercise lists for upper/lower body, and a special 'core' key for core workout
  static Future<Map<MuscleGroup, List<Exercise>>> getWorkoutsByMuscleGroup(DateTime date) async {
    final db = await LocalDB.database;
    final dateString = date.toIso8601String().substring(0, 10);

    final results = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateString]);

    final Map<MuscleGroup, List<Exercise>> groupedExercises = {};

    for (var row in results) {
      final muscleGroupStr = row['muscle_group'] as String;
      final exercisesJson = jsonDecode(row['exercises'] as String) as List;

      // Skip core and activities muscle groups (they're handled separately)
      if (muscleGroupStr == muscleGroupToString(MuscleGroup.core) ||
          muscleGroupStr.startsWith(muscleGroupToString(MuscleGroup.otherActivity))) {
        continue;
      }

      // Parse exercises for this muscle group
      for (var item in exercisesJson) {
        if (item is! Map) continue;

        final exercise = Exercise.fromJson(Map<String, dynamic>.from(item));
        if (!groupedExercises.containsKey(exercise.muscleGroup)) {
          groupedExercises[exercise.muscleGroup] = [];
        }
        groupedExercises[exercise.muscleGroup]!.add(exercise);
      }
    }

    return groupedExercises;
  }

  // Check if a core workout exists for a specific date
  static Future<bool> hasCoreWorkoutForDate(DateTime date) async {
    final routine = await getCoreRoutineForDate(date);
    return routine != null;
  }

  // Get exercise history for smart suggestions
  // Returns the last N instances of a specific exercise
  static Future<List<ExerciseHistory>> getExerciseHistory(String exerciseName, {int limit = 5}) async {
    final db = await database;
    final logs = await db.query('workout_logs', orderBy: 'date DESC', limit: 20);

    List<ExerciseHistory> history = [];

    for (var log in logs) {
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      // Filter out core workouts (they have isCore: true)
      final regularExercises = _filterRegularExercises(exercisesJson);

      // Find the specific exercise in this workout
      final exercise = regularExercises.firstWhere(
        (e) => e.name == exerciseName,
        orElse: () => Exercise(name: '', muscleGroup: MuscleGroup.upperBody), // dummy
      );

      // Only include exercises that were actually completed (not skipped)
      if (exercise.name == exerciseName && !exercise.isSkipped && exercise.weight != null) {
        history.add(ExerciseHistory(
          date: log['date'] as String,
          weight: exercise.weight,
          completedSets: exercise.completedSets,
        ));
      }

      if (history.length >= limit) break;
    }

    return history;
  }

  // Get smart weight suggestion based on history with progression hint
  static Future<WeightSuggestion?> getSmartWeightSuggestion(String exerciseName, {String repRange = "8-12"}) async {
    final history = await getExerciseHistory(exerciseName, limit: 3);

    if (history.isEmpty) {
      // No history - will use beginner weight from exercise constants
      return null;
    }

    // Get the most recent weight used
    final lastWeight = history.first.weight;
    final lastSets = history.first.completedSets;

    if (lastWeight == null || lastSets.isEmpty) {
      return null;
    }

    // Parse the high end of the rep range (e.g., "8-12" -> 12, "12-15" -> 15)
    final highEndReps = _getHighEndReps(repRange);

    // Check if user is ready for progression
    // If all sets were in the upper rep range (e.g., hitting high end consistently), suggest weight increase
    final avgReps = lastSets.reduce((a, b) => a + b) / lastSets.length;

    // Count how many times user has done this exercise at similar weight (within 2.5 lbs)
    int timesAtSimilarWeight = 0;
    for (var record in history) {
      if (record.weight != null && (record.weight! - lastWeight).abs() <= 2.5) {
        timesAtSimilarWeight++;
      }
    }

    // Progressive overload criteria:
    // 1. If average reps >= high end of range, suggest +5 lbs
    // 2. If done exercise 3+ times at similar weight, suggest +5 lbs
    String? motivationalMessage;
    double suggestedWeight;

    if (avgReps >= highEndReps) {
      suggestedWeight = lastWeight + 5.0;
      motivationalMessage = "You're crushing $lastWeight lbs with high reps! Try $suggestedWeight lbs today for progression.";
    } else if (timesAtSimilarWeight >= 3) {
      suggestedWeight = lastWeight + 5.0;
      motivationalMessage = "You've done $lastWeight lbs for $timesAtSimilarWeight workouts. Try some higher reps or level up to $suggestedWeight lbs!";
    } else {
      suggestedWeight = lastWeight;
    }

    return WeightSuggestion(weight: suggestedWeight, motivationalMessage: motivationalMessage);
  }

  // Parse the high end of the rep range (e.g., "8-12" -> 12, "12-15" -> 15)
  static int _getHighEndReps(String repsRange) {
    final matches = RegExp(r'\d+').allMatches(repsRange);
    if (matches.length >= 2) {
      return int.tryParse(matches.elementAt(1).group(0)!) ?? 10;
    }
    return int.tryParse(matches.first.group(0)!) ?? 10;
  }

  // Fetch all workout logs
  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    final db = await database;
    return db.query('workout_logs', orderBy: 'date DESC');
  }

  // Get all dates that have logged workouts (returns unique dates)
  static Future<List<DateTime>> getLoggedDates() async {
    final logs = await fetchLogs();
    // With new schema, multiple rows per date, so deduplicate
    final dateSet = logs.map((log) => log['date'] as String).toSet();
    return dateSet.map((dateStr) => DateTime.parse(dateStr)).toList()..sort((a, b) => b.compareTo(a));
  }

  // Delete workout for a specific date
  static Future<void> delete(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    await db.delete('workout_logs', where: 'date = ?', whereArgs: [dateStr]);
  }

  // Remove exercises for a specific muscle group from a date's workout
  static Future<void> removeWorkoutByMuscleGroup(DateTime date, MuscleGroup muscleGroup) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final muscleGroupStr = muscleGroupToString(muscleGroup);

    // Delete the row for this date and muscle group
    await db.delete('workout_logs',
        where: 'date = ? AND muscle_group = ?',
        whereArgs: [dateStr, muscleGroupStr]);
  }

  // Incomplete workout methods
  // Save an incomplete workout (in-progress)
  static Future<void> saveIncompleteWorkout(WorkoutRoutine routine, [String? date]) async {
    final db = await database;
    if (date == null) {
      final now = DateTime.now();
      date = now.toIso8601String().substring(0, 10);
    }

    final muscleGroupStr = muscleGroupToString(routine.targetArea);
    final exercisesJson = jsonEncode(routine.exercises.map((e) => e.toJson()).toList());

    await db.insert(
      'incomplete_workouts',
      {
        'date': date,
        'muscle_group': muscleGroupStr,
        'exercises': exercisesJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Replace if already exists
    );
  }

  // Get all incomplete workouts for a specific date
  static Future<Map<MuscleGroup, WorkoutRoutine>> getIncompleteWorkouts(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);

    final results = await db.query(
      'incomplete_workouts',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    final Map<MuscleGroup, WorkoutRoutine> incompleteWorkouts = {};

    for (var row in results) {
      final muscleGroupStr = row['muscle_group'] as String;

      // Skip activities - they're stored separately and loaded via getIncompleteActivities
      if (muscleGroupStr == 'activities') {
        continue;
      }

      final exercisesJson = jsonDecode(row['exercises'] as String) as List;
      final exercises = exercisesJson.map((e) => Exercise.fromJson(e)).toList();

      // Convert muscle group string back to enum
      MuscleGroup? muscleGroup;
      if (muscleGroupStr == muscleGroupToString(MuscleGroup.upperBody)) {
        muscleGroup = MuscleGroup.upperBody;
      } else if (muscleGroupStr == muscleGroupToString(MuscleGroup.lowerBody)) {
        muscleGroup = MuscleGroup.lowerBody;
      }

      if (muscleGroup != null) {
        incompleteWorkouts[muscleGroup] = WorkoutRoutine(
          targetArea: muscleGroup,
          exercises: exercises,
        );
      }
    }

    return incompleteWorkouts;
  }

  // Delete a specific incomplete workout
  static Future<void> deleteIncompleteWorkout(DateTime date, MuscleGroup muscleGroup) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final muscleGroupStr = muscleGroupToString(muscleGroup);

    await db.delete(
      'incomplete_workouts',
      where: 'date = ? AND muscle_group = ?',
      whereArgs: [dateStr, muscleGroupStr],
    );
  }

  // Incomplete activities methods
  // Save incomplete activities (in-progress) - each activity in separate row to avoid 2MB limit
  static Future<void> saveIncompleteActivities(List<Activity> activities, [String? date]) async {
    final db = await database;
    if (date == null) {
      final now = DateTime.now();
      date = now.toIso8601String().substring(0, 10);
    }

    // First, delete all existing incomplete activities for this date
    await deleteIncompleteActivities(DateTime.parse(date));

    if (activities.isEmpty) {
      return;
    }

    // Store each activity in its own row to avoid 2MB limit with attachments
    for (var activity in activities) {
      final muscleGroupKey = getActivityMuscleGroupKey(activity);
      final activityJson = jsonEncode([activity.toMap()]); // Wrap in array for consistency

      await db.insert(
        'incomplete_workouts',
        {
          'date': date,
          'muscle_group': muscleGroupKey,
          'exercises': activityJson,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Get incomplete activities for a specific date (from multiple rows)
  static Future<List<Activity>> getIncompleteActivities(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);

    // Query all rows for this date that are activities (muscle_group starts with 'Other Activities')
    final results = await db.query(
      'incomplete_workouts',
      where: 'date = ? AND muscle_group LIKE ?',
      whereArgs: [dateStr, 'Other Activities%'],
    );

    if (results.isEmpty) {
      return [];
    }

    final allActivities = <Activity>[];

    // Collect activities from all rows
    for (var row in results) {
      final activitiesJson = jsonDecode(row['exercises'] as String) as List;
      final activities = activitiesJson.map((a) {
        final activityMap = a is Map<String, dynamic> ? a : Map<String, dynamic>.from(a as Map);
        return Activity.fromMap(activityMap);
      }).toList();
      allActivities.addAll(activities);
    }

    return allActivities;
  }

  // Delete incomplete activities (all activity rows for this date)
  static Future<void> deleteIncompleteActivities(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);

    // Delete all activity rows for this date
    await db.delete(
      'incomplete_workouts',
      where: 'date = ? AND muscle_group LIKE ?',
      whereArgs: [dateStr, 'Other Activities%'],
    );
  }

  // Delete all incomplete workouts from previous days
  static Future<void> clearOldIncompleteWorkouts() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    await db.delete(
      'incomplete_workouts',
      where: 'date < ?',
      whereArgs: [today],
    );
  }

  // Core workout methods
  // Insert a completed core workout (stored as separate row with muscle_group = 'Core')
  static Future<void> insertCoreWorkout(CoreWorkoutRoutine routine, [String? date]) async {
    // Don't insert empty core workouts
    if (routine.exercises.isEmpty) {
      return;
    }

    final db = await database;
    if (date == null) {
      final now = DateTime.now();
      date = now.toIso8601String().substring(0, 10);
    }

    final muscleGroup = muscleGroupToString(MuscleGroup.core);

    // Check if there's already a core workout for this date and muscle group
    final existing = await db.query('workout_logs',
        where: 'date = ? AND muscle_group = ?',
        whereArgs: [date, muscleGroup]);

    final coreWorkoutData = {
      'isCore': true,
      'sets': routine.sets,
      'exercisesPerSet': routine.exercisesPerSet,
      'exercises': routine.exercises.map((e) => e.toJson()).toList(),
    };

    if (existing.isNotEmpty) {
      // Update existing core workout row
      await db.update('workout_logs', {
        'exercises': jsonEncode([coreWorkoutData]),
      }, where: 'date = ? AND muscle_group = ?', whereArgs: [date, muscleGroup]);
    } else {
      // Insert new core workout row
      await db.insert('workout_logs', {
        'date': date,
        'muscle_group': muscleGroup,
        'exercises': jsonEncode([coreWorkoutData]),
      });
    }
  }

  // Get core workout for a specific date
  static Future<CoreWorkoutRoutine?> getCoreRoutineForDate(DateTime date) async {
    final db = await database;
    final dateString = date.toIso8601String().substring(0, 10);
    final muscleGroup = muscleGroupToString(MuscleGroup.core);

    final results = await db.query('workout_logs',
        where: 'date = ? AND muscle_group = ?',
        whereArgs: [dateString, muscleGroup]);

    if (results.isEmpty) {
      return null;
    }

    final exercisesJson = jsonDecode(results.first['exercises'] as String) as List;

    // Find the core workout data
    for (var item in exercisesJson) {
      if (item is Map && item['isCore'] == true) {
        final coreExercises = (item['exercises'] as List).map((e) => CoreExercise.fromJson(e)).toList();
        return CoreWorkoutRoutine(
          sets: item['sets'] as int,
          exercisesPerSet: item['exercisesPerSet'] as int,
          exercises: coreExercises,
        );
      }
    }

    return null;
  }

  // Remove core workout from a specific date
  static Future<void> removeCoreWorkout(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final muscleGroup = muscleGroupToString(MuscleGroup.core);

    // Delete the core workout row
    await db.delete('workout_logs',
        where: 'date = ? AND muscle_group = ?',
        whereArgs: [dateStr, muscleGroup]);
  }

  // Clear all workout logs
  static Future<void> clearLogs() async {
    final db = await database;
    await db.delete('workout_logs');
  }

  // Activity methods
  // Insert activities for today (each activity stored in separate row to avoid 2MB limit)
  static Future<void> insertActivities(ActivityRoutine activityRoutine, [String? date]) async {
    final db = await database;
    if (date == null) {
      final now = DateTime.now();
      date = now.toIso8601String().substring(0, 10);
    }

    // Store each activity in its own row to avoid 2MB cursor window limit
    for (final activity in activityRoutine.activities) {
      final muscleGroupKey = getActivityMuscleGroupKey(activity);

      final activitiesData = {
        'isActivity': true,
        'activities': [activity.toMap()], // Single activity per row
      };

      // Insert or replace this specific activity
      await db.insert('workout_logs', {
        'date': date,
        'muscle_group': muscleGroupKey,
        'exercises': jsonEncode([activitiesData]),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Updates workouts for a specific date while preserving workout types that aren't being managed.
  ///
  /// This method implements a load-modify-update pattern that:
  /// 1. Updates/deletes rows for muscle groups that were originally present
  /// 2. Inserts/updates rows for new workout data
  /// 3. Preserves any muscle group rows that weren't originally present
  ///
  /// This ensures that editing one muscle group doesn't accidentally delete other muscle groups.
  ///
  /// Example: If you had Upper Body + Core, and you edit Upper Body to add an exercise:
  /// - originalMuscleGroups: {MuscleGroup.upperBody}
  /// - newWorkoutsByGroup: {MuscleGroup.upperBody: [updated exercises]}
  /// - originalHadCore: true
  /// - newCoreWorkout: the existing core workout
  /// Result: Upper Body (updated) + Core (preserved)
  static Future<void> updateWorkoutsForDate({
    required String date,
    required Set<MuscleGroup> originalMuscleGroups,
    required Map<MuscleGroup, List<Exercise>> newWorkoutsByGroup,
    required bool originalHadCore,
    CoreWorkoutRoutine? newCoreWorkout,
    required bool originalHadActivities,
    List<Activity>? newActivities,
  }) async {
    final db = await database;

    // 1. Delete rows for muscle groups that were originally present but are no longer in new data
    for (final muscleGroup in originalMuscleGroups) {
      if (!newWorkoutsByGroup.containsKey(muscleGroup)) {
        // This muscle group was removed, delete its row
        await db.delete('workout_logs',
            where: 'date = ? AND muscle_group = ?',
            whereArgs: [date, muscleGroupToString(muscleGroup)]);
      }
    }

    // 2. Update or insert rows for new muscle group workouts
    for (final entry in newWorkoutsByGroup.entries) {
      final muscleGroupStr = muscleGroupToString(entry.key);
      final exercises = entry.value;

      if (exercises.isEmpty) {
        // Delete if empty
        await db.delete('workout_logs',
            where: 'date = ? AND muscle_group = ?',
            whereArgs: [date, muscleGroupStr]);
      } else {
        // Insert or replace
        await db.insert('workout_logs', {
          'date': date,
          'muscle_group': muscleGroupStr,
          'exercises': jsonEncode(exercises.map((e) => e.toJson()).toList()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    // 3. Handle core workout
    final coreGroup = muscleGroupToString(MuscleGroup.core);
    if (originalHadCore && newCoreWorkout == null) {
      // Core was removed, delete its row
      await db.delete('workout_logs',
          where: 'date = ? AND muscle_group = ?',
          whereArgs: [date, coreGroup]);
    } else if (newCoreWorkout != null) {
      // Insert or update core workout
      final coreWorkoutData = {
        'isCore': true,
        'sets': newCoreWorkout.sets,
        'exercisesPerSet': newCoreWorkout.exercisesPerSet,
        'exercises': newCoreWorkout.exercises.map((e) => e.toJson()).toList(),
      };
      await db.insert('workout_logs', {
        'date': date,
        'muscle_group': coreGroup,
        'exercises': jsonEncode([coreWorkoutData]),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // 4. Handle activities (each activity in its own row)
    if (originalHadActivities && (newActivities == null || newActivities.isEmpty)) {
      // Activities were removed, delete all activity rows
      await db.delete('workout_logs',
          where: 'date = ? AND muscle_group LIKE ?',
          whereArgs: [date, 'Other Activities%']);
    } else if (newActivities != null && newActivities.isNotEmpty) {
      // Delete old activity rows first
      await db.delete('workout_logs',
          where: 'date = ? AND muscle_group LIKE ?',
          whereArgs: [date, 'Other Activities%']);

      // Insert each activity in its own row
      for (final activity in newActivities) {
        final muscleGroupKey = getActivityMuscleGroupKey(activity);
        final activitiesData = {
          'isActivity': true,
          'activities': [activity.toMap()],
        };
        await db.insert('workout_logs', {
          'date': date,
          'muscle_group': muscleGroupKey,
          'exercises': jsonEncode([activitiesData]),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  // Get activities for a specific date (from multiple rows)
  static Future<ActivityRoutine?> getActivitiesForDate(DateTime date) async {
    final db = await database;
    final dateString = date.toIso8601String().substring(0, 10);

    // Query all rows for this date that are activities (muscle_group starts with 'Other Activities')
    final results = await db.query('workout_logs',
        where: 'date = ? AND muscle_group LIKE ?',
        whereArgs: [dateString, 'Other Activities%']);

    if (results.isEmpty) {
      return null;
    }

    final allActivities = <Activity>[];

    // Collect activities from all rows
    for (var row in results) {
      final exercisesJson = jsonDecode(row['exercises'] as String) as List;

      for (var item in exercisesJson) {
        if (item is Map && item['isActivity'] == true) {
          final activities = (item['activities'] as List).map((a) {
            final activityMap = a is Map<String, dynamic> ? a : Map<String, dynamic>.from(a as Map);
            final activity = Activity.fromMap(activityMap);
            // If the activity doesn't have a date, set it from the workout log date
            return activity.date == null ? activity.copyWith(date: date) : activity;
          }).toList();
          allActivities.addAll(activities);
        }
      }
    }

    return allActivities.isNotEmpty ? ActivityRoutine(activities: allActivities) : null;
  }

  // Get all unique activity names for autocomplete
  static Future<List<String>> getActivityNames() async {
    final db = await database;
    final logs = await db.query('workout_logs', orderBy: 'date DESC');

    Set<String> activityNames = {};

    for (var log in logs) {
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      // Find activities data
      for (var item in exercisesJson) {
        if (item is Map && item['isActivity'] == true) {
          final activities = (item['activities'] as List).map((a) => Activity.fromMap(a)).toList();
          for (var activity in activities) {
            activityNames.add(activity.name);
          }
        }
      }
    }

    return activityNames.toList()..sort();
  }

  // Remove activities from a specific date (delete all activity rows)
  static Future<void> removeActivities(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);

    // Delete all activity rows for this date
    await db.delete('workout_logs',
        where: 'date = ? AND muscle_group LIKE ?',
        whereArgs: [dateStr, 'Other Activities%']);
  }
}
