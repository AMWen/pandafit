import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/exercise_model.dart';
import '../models/core_exercise_model.dart';
import '../../utils/file_utils.dart';

class ExerciseHistory {
  final String date;
  final double? weight;
  final List<int> completedSets;

  ExerciseHistory({
    required this.date,
    this.weight,
    required this.completedSets,
  });
}

class LocalDB {
  static Database? _db;

  // Helper function to filter out core workouts from exercise data
  static List<Exercise> _filterRegularExercises(List<dynamic> data) {
    return data
        .where((item) => item is! Map || item['isCore'] != true)
        .map((item) => Exercise.fromJson(item))
        .toList();
  }

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'pandafit_workout.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE workout_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT UNIQUE,
          target_area TEXT,
          exercises TEXT
        )
      ''');
      },
    );
    return _db!;
  }

  // Insert a completed workout (appends if same day, different target area)
  static Future<void> insertWorkout(WorkoutRoutine routine, [String? date]) async {
    final db = await database;
    if (date == null) {
      final now = DateTime.now();
      date = now.toIso8601String().substring(0, 10);
    }

    // Check if there's already a workout for this date
    final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [date]);

    if (existing.isNotEmpty) {
      // Append exercises to existing workout
      final existingData = jsonDecode(existing.first['exercises'] as String) as List;
      final existingTargetArea = existing.first['target_area'] as String;

      // Combine target areas
      final newTargetArea = existingTargetArea.contains(muscleGroupToString(routine.targetArea))
          ? existingTargetArea
          : '$existingTargetArea + ${muscleGroupToString(routine.targetArea)}';

      // Separate regular exercises from core workouts
      final List<dynamic> regularExercises = [];
      final List<dynamic> coreWorkouts = [];

      for (var item in existingData) {
        if (item is Map && item['isCore'] == true) {
          coreWorkouts.add(item);
        } else {
          regularExercises.add(item);
        }
      }

      // Combine all data: existing regular exercises + new exercises + existing core workouts
      final allData = [
        ...regularExercises,
        ...routine.exercises.map((e) => e.toJson()),
        ...coreWorkouts,
      ];

      await db.update('workout_logs', {
        'target_area': newTargetArea,
        'exercises': jsonEncode(allData),
      }, where: 'date = ?', whereArgs: [date]);
    } else {
      // Insert new workout
      await db.insert('workout_logs', {
        'date': date,
        'target_area': muscleGroupToString(routine.targetArea),
        'exercises': jsonEncode(routine.exercises.map((e) => e.toJson()).toList()),
      });
    }
  }

  // Get workout for a specific date
  static Future<WorkoutRoutine?> getRoutineForDate(DateTime date) async {
    final db = await LocalDB.database;
    final dateString = date.toIso8601String().substring(0, 10);

    final results = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateString]);

    if (results.isEmpty) {
      return null;
    }

    final exercisesJson = jsonDecode(results.first['exercises'] as String) as List;

    // Filter out core workouts (they have isCore: true)
    final exercises = _filterRegularExercises(exercisesJson);

    if (exercises.isEmpty) {
      return null; // No regular exercises, only core workouts
    }

    final targetArea = exercises.first.muscleGroup; // Use first exercise's muscle group

    return WorkoutRoutine(
      targetArea: targetArea,
      exercises: exercises,
    );
  }

  // Get workouts for a specific date grouped by muscle group
  // Returns a map with Exercise lists for upper/lower body, and a special 'core' key for core workout
  static Future<Map<MuscleGroup, List<Exercise>>> getWorkoutsByMuscleGroup(DateTime date) async {
    final db = await LocalDB.database;
    final dateString = date.toIso8601String().substring(0, 10);

    final results = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateString]);

    if (results.isEmpty) {
      return {};
    }

    final exercisesJson = jsonDecode(results.first['exercises'] as String) as List;

    // Group exercises by muscle group
    final Map<MuscleGroup, List<Exercise>> groupedExercises = {};

    for (var item in exercisesJson) {
      // Check if this is a core workout (special format)
      if (item is Map && item['isCore'] == true) {
        // Core workouts are handled separately - skip them here
        continue;
      }

      // Regular exercises
      final exercise = Exercise.fromJson(item);
      if (!groupedExercises.containsKey(exercise.muscleGroup)) {
        groupedExercises[exercise.muscleGroup] = [];
      }
      groupedExercises[exercise.muscleGroup]!.add(exercise);
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

      if (exercise.name == exerciseName && exercise.weight != null) {
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
  static Future<double?> getSmartWeightSuggestion(String exerciseName, {String repRange = "8-12"}) async {
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
    if (avgReps >= highEndReps || timesAtSimilarWeight >= 3) {
      return lastWeight + 5.0;
    }

    return lastWeight;
  }

  // Parse the high end of the rep range (e.g., "8-12" -> 12, "12-15" -> 15)
  static int _getHighEndReps(String repsRange) {
    final matches = RegExp(r'\d+').allMatches(repsRange);
    if (matches.length >= 2) {
      return int.tryParse(matches.elementAt(1).group(0)!) ?? 10;
    }
    return int.tryParse(matches.first.group(0)!) ?? 10;
  }

  // Get progression hint message for uisforser feedback
  static Future<String?> getProgressionHint(String exerciseName) async {
    final history = await getExerciseHistory(exerciseName, limit: 3);

    if (history.isEmpty) return null;

    final lastWeight = history.first.weight;
    final lastSets = history.first.completedSets;

    if (lastWeight == null || lastSets.isEmpty) return null;

    final avgReps = lastSets.reduce((a, b) => a + b) / lastSets.length;

    // Count how many times at similar weight
    int timesAtSimilarWeight = 0;
    for (var record in history) {
      if (record.weight != null && (record.weight! - lastWeight).abs() <= 2.5) {
        timesAtSimilarWeight++;
      }
    }

    // Generate helpful hint message
    if (avgReps >= 10) {
      return "You're crushing $lastWeight lbs with high reps! Try ${lastWeight + 5.0} lbs today for progression.";
    } else if (timesAtSimilarWeight >= 3) {
      return "You've done $lastWeight lbs for $timesAtSimilarWeight workouts. Time to level up to ${lastWeight + 5.0} lbs!";
    }

    return null;
  }

  // Fetch all workout logs
  static Future<List<Map<String, dynamic>>> fetchLogs() async {
    final db = await database;
    return db.query('workout_logs', orderBy: 'date DESC');
  }

  // Get all dates that have logged workouts
  static Future<List<DateTime>> getLoggedDates() async {
    final logs = await fetchLogs();
    return logs.map((log) => DateTime.parse(log['date'] as String)).toList();
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

    // Get existing workout for the date
    final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateStr]);

    if (existing.isEmpty) return;

    final exercisesJson = jsonDecode(existing.first['exercises'] as String) as List;

    // Separate core workouts from regular exercises, then filter by muscle group
    final List<dynamic> remainingData = [];
    for (var item in exercisesJson) {
      // Keep core workouts as-is
      if (item is Map && item['isCore'] == true) {
        remainingData.add(item);
      } else {
        // Only keep regular exercises that don't match the muscle group
        final exercise = Exercise.fromJson(item);
        if (exercise.muscleGroup != muscleGroup) {
          remainingData.add(item);
        }
      }
    }

    if (remainingData.isEmpty) {
      // If no data left, delete the entire workout entry
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [dateStr]);
    } else {
      // Update with remaining data
      // Calculate target areas from remaining exercises (skip core workouts for target area calculation)
      final regularExercises = _filterRegularExercises(remainingData);

      String targetAreas;
      if (regularExercises.isEmpty) {
        // Only core workouts remain
        targetAreas = 'Core';
      } else {
        targetAreas = regularExercises.map((e) => muscleGroupToString(e.muscleGroup)).toSet().join(' + ');
        // Add Core if there are core workouts
        if (remainingData.any((item) => item is Map && item['isCore'] == true)) {
          targetAreas = '$targetAreas + Core';
        }
      }

      await db.update('workout_logs', {
        'target_area': targetAreas,
        'exercises': jsonEncode(remainingData),
      }, where: 'date = ?', whereArgs: [dateStr]);
    }
  }

  // Core workout methods
  // Insert a completed core workout (stored separately in same table with special marker)
  static Future<void> insertCoreWorkout(CoreWorkoutRoutine routine, [String? date]) async {
    final db = await database;
    if (date == null) {
      final now = DateTime.now();
      date = now.toIso8601String().substring(0, 10);
    }

    // Check if there's already a workout for this date
    final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [date]);

    if (existing.isNotEmpty) {
      // Append core workout to existing exercises (stored as separate JSON entry)
      final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;
      final existingTargetArea = existing.first['target_area'] as String;

      // Add core marker to target area
      final newTargetArea = existingTargetArea.contains('Core')
          ? existingTargetArea
          : '$existingTargetArea + Core';

      // Add core workout to exercises (we'll store it as JSON with special 'core' flag)
      final coreWorkoutData = {
        'isCore': true,
        'sets': routine.sets,
        'exercisesPerSet': routine.exercisesPerSet,
        'exercises': routine.exercises.map((e) => e.toJson()).toList(),
      };

      await db.update('workout_logs', {
        'target_area': newTargetArea,
        'exercises': jsonEncode([...existingExercises, coreWorkoutData]),
      }, where: 'date = ?', whereArgs: [date]);
    } else {
      // Insert new core workout
      final coreWorkoutData = {
        'isCore': true,
        'sets': routine.sets,
        'exercisesPerSet': routine.exercisesPerSet,
        'exercises': routine.exercises.map((e) => e.toJson()).toList(),
      };

      await db.insert('workout_logs', {
        'date': date,
        'target_area': 'Core',
        'exercises': jsonEncode([coreWorkoutData]),
      });
    }
  }

  // Get core workout for a specific date
  static Future<CoreWorkoutRoutine?> getCoreRoutineForDate(DateTime date) async {
    final db = await database;
    final dateString = date.toIso8601String().substring(0, 10);

    final results = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateString]);

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

    final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateStr]);

    if (existing.isEmpty) return;

    final exercisesJson = jsonDecode(existing.first['exercises'] as String) as List;

    // Filter out core workout
    final remainingData = exercisesJson.where((item) {
      if (item is Map && item['isCore'] == true) {
        return false;
      }
      return true;
    }).toList();

    if (remainingData.isEmpty) {
      // If no data left, delete the entire workout entry
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [dateStr]);
    } else {
      // Update target area to remove 'Core'
      final targetArea = existing.first['target_area'] as String;
      final newTargetArea = targetArea.replaceAll('+ Core', '').replaceAll('Core +', '').replaceAll('Core', '').trim();

      await db.update('workout_logs', {
        'target_area': newTargetArea.isNotEmpty ? newTargetArea : 'Unknown',
        'exercises': jsonEncode(remainingData),
      }, where: 'date = ?', whereArgs: [dateStr]);
    }
  }

  // Clear all workout logs
  static Future<void> clearLogs() async {
    final db = await database;
    await db.delete('workout_logs');
  }

  // Export workout history as CSV
  static Future<String> exportProgress() async {
    final logs = await fetchLogs();

    final rows = <List<String>>[
      ['Date', 'Target Area', 'Exercises'],
      ...logs.map((log) => [
        log['date'] as String,
        log['target_area'] as String,
        log['exercises'] as String,
      ]),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    String message = await saveWorkoutAsCsv('pandafit_history.csv', csvData);
    return message;
  }

  // Import workout history from CSV
  static Future<String> importProgress() async {
    final filePath = await pickLocation(['csv']);
    try {
      if (filePath != null) {
        final file = File(filePath);
        final csvString = await file.readAsString();
        final rows = const CsvToListConverter(eol: '\r\n').convert(csvString);

        final db = await database;

        for (int i = 1; i < rows.length; i++) {
          final date = rows[i][0] as String;
          final targetArea = rows[i][1] as String;
          final exercisesJson = rows[i][2] as String;

          await db.insert('workout_logs', {
            'date': date,
            'target_area': targetArea,
            'exercises': exercisesJson,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        return 'Data imported successfully';
      } else {
        return 'Error: no file path provided';
      }
    } catch (e) {
      return 'Error importing workout history: $e';
    }
  }
}
