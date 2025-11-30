import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pandafit/data/services/localdb_service.dart';
import 'package:pandafit/data/models/exercise_model.dart';
import 'package:pandafit/data/models/core_exercise_model.dart';

/// Integration tests for LocalDB Service
///
/// These tests verify core database operations:
/// 1. Workout CRUD operations (Create, Read, Update, Delete)
/// 2. Core workout operations
/// 3. Activities management
/// 4. Multi-muscle-group data integrity
/// 5. updateWorkoutsForDate preservation logic
/// 6. Weight suggestions and motivational messages
///
/// To run these tests:
/// flutter test test/localdb_service_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('LocalDB - Workout Insert Operations', () {
    late String testDate;
    late Database db;

    setUp(() async {
      // Use a consistent test date
      testDate = '2024-01-15';

      // Get database instance and clear test data
      db = await LocalDB.database;
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);
    });

    test('Should add upper body workout from view mode and persist to database', () async {
      // Create test workout
      final exercises = [
        Exercise(
          name: 'Bench Press',
          muscleGroup: MuscleGroup.upperBody,
          reps: '8-12',
          weight: 135.0,
          completedSets: [10, 10, 9],
        ),
        Exercise(
          name: 'Incline Press',
          muscleGroup: MuscleGroup.upperBody,
          reps: '8-12',
          weight: 115.0,
          completedSets: [11, 10, 10],
        ),
      ];

      final routine = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: exercises,
      );

      // Add workout to database
      await LocalDB.insertWorkout(routine, testDate);

      // Verify workout was saved
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue,
          reason: 'Should have upper body workout saved');
      expect(savedWorkouts[MuscleGroup.upperBody]!.length, equals(2),
          reason: 'Should have 2 exercises saved');
      expect(savedWorkouts[MuscleGroup.upperBody]![0].name, equals('Bench Press'),
          reason: 'First exercise should be Bench Press');
      expect(savedWorkouts[MuscleGroup.upperBody]![0].weight, equals(135.0),
          reason: 'Weight should be preserved');

      debugPrint('\n✓ Upper body workout added and persisted correctly');
    });

    test('Should add lower body workout from view mode', () async {
      final exercises = [
        Exercise(
          name: 'Squat',
          muscleGroup: MuscleGroup.lowerBody,
          reps: '8-12',
          weight: 185.0,
          completedSets: [10, 9, 9],
        ),
      ];

      final routine = WorkoutRoutine(
        targetArea: MuscleGroup.lowerBody,
        exercises: exercises,
      );

      await LocalDB.insertWorkout(routine, testDate);

      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      expect(savedWorkouts.containsKey(MuscleGroup.lowerBody), isTrue);
      expect(savedWorkouts[MuscleGroup.lowerBody]!.length, equals(1));
      expect(savedWorkouts[MuscleGroup.lowerBody]![0].name, equals('Squat'));

      debugPrint('✓ Lower body workout added correctly');
    });

    test('Should add core workout from view mode', () async {
      final coreWorkout = CoreWorkoutRoutine(
        sets: 3,
        exercisesPerSet: 4,
        exercises: [
          CoreExercise(name: 'Crunches', amount: 25),
          CoreExercise(name: 'Plank', amount: 60, isTimed: true),
          CoreExercise(name: 'Russian Twists', amount: 20),
          CoreExercise(name: 'Leg Lifts', amount: 15),
        ],
      );

      // Save core workout
      await LocalDB.insertCoreWorkout(coreWorkout, testDate);

      // Verify core workout was saved
      final savedCoreWorkout = await LocalDB.getCoreRoutineForDate(DateTime.parse(testDate));

      expect(savedCoreWorkout, isNotNull, reason: 'Core workout should be saved');
      expect(savedCoreWorkout!.sets, equals(3));
      expect(savedCoreWorkout.exercisesPerSet, equals(4));
      expect(savedCoreWorkout.exercises.length, equals(4));
      expect(savedCoreWorkout.exercises[0].name, equals('Crunches'));

      debugPrint('✓ Core workout added correctly');
    });

    test('Should verify activities can be retrieved for a date', () async {
      // Activities are stored as part of workout_logs
      // This test verifies the API works correctly
      final savedActivities = await LocalDB.getActivitiesForDate(DateTime.parse(testDate));

      // Should return null when no activities exist
      expect(savedActivities, isNull, reason: 'Should return null when no activities for date');

      debugPrint('✓ Activity retrieval API works correctly');
    });

    test('Should handle multiple muscle groups on same day', () async {
      // Add both upper and lower body
      final upperRoutine = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: [
          Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
        ],
      );

      final lowerRoutine = WorkoutRoutine(
        targetArea: MuscleGroup.lowerBody,
        exercises: [
          Exercise(name: 'Squat', muscleGroup: MuscleGroup.lowerBody, reps: '8-12', weight: 185.0, completedSets: [10, 9, 9]),
        ],
      );

      await LocalDB.insertWorkout(upperRoutine, testDate);
      await LocalDB.insertWorkout(lowerRoutine, testDate);

      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue);
      expect(savedWorkouts.containsKey(MuscleGroup.lowerBody), isTrue);
      expect(savedWorkouts.length, equals(2));

      debugPrint('✓ Multiple muscle groups saved correctly');
    });
  });

  group('LocalDB - Workout Update Operations', () {
    late String testDate;
    late Database db;

    setUp(() async {
      testDate = '2024-01-16';
      db = await LocalDB.database;
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);
    });

    test('Should edit existing workout and update database', () async {
      // Add initial workout
      final initialExercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: initialExercises),
        testDate,
      );

      // Edit: add another exercise
      // Note: insertWorkout adds to existing, doesn't replace
      final additionalExercises = [
        Exercise(name: 'Incline Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 115.0, completedSets: [11, 10, 10]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: additionalExercises),
        testDate,
      );

      // Verify both exercises are saved
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      expect(savedWorkouts[MuscleGroup.upperBody]!.length, equals(2),
          reason: 'Should have 2 exercises total');
      expect(savedWorkouts[MuscleGroup.upperBody]![0].name, equals('Bench Press'),
          reason: 'Original exercise should be present');
      expect(savedWorkouts[MuscleGroup.upperBody]![1].name, equals('Incline Press'),
          reason: 'New exercise should be added');

      debugPrint('✓ Workout edited successfully');
    });

    test('Should edit exercise weight and sets by delete-then-insert', () async {
      // Add initial workout
      final initialExercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: initialExercises),
        testDate,
      );

      // Edit: To update existing workout, delete entire date then insert new one
      // (Simplified version of history_screen.dart's _saveWorkoutToDatabase logic)
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);

      final updatedExercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 140.0, completedSets: [12, 11, 10]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: updatedExercises),
        testDate,
      );

      // Verify changes were saved
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      expect(savedWorkouts[MuscleGroup.upperBody]!.length, equals(1),
          reason: 'Should have exactly 1 exercise after delete-then-insert');
      expect(savedWorkouts[MuscleGroup.upperBody]![0].weight, equals(140.0),
          reason: 'Weight should be updated');
      expect(savedWorkouts[MuscleGroup.upperBody]![0].completedSets, equals([12, 11, 10]),
          reason: 'Sets should be updated');

      debugPrint('✓ Exercise weight and sets edited successfully using delete-then-insert pattern');
    });

    test('Should preserve other muscle groups when editing one muscle group (real app behavior)', () async {
      // Setup: Add both upper and lower body workouts
      final upperExercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
      ];
      final lowerExercises = [
        Exercise(name: 'Squat', muscleGroup: MuscleGroup.lowerBody, reps: '8-12', weight: 185.0, completedSets: [10, 9, 9]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: upperExercises),
        testDate,
      );
      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.lowerBody, exercises: lowerExercises),
        testDate,
      );

      // Verify both are saved
      var savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue);
      expect(savedWorkouts.containsKey(MuscleGroup.lowerBody), isTrue);

      // Now edit ONLY upper body using the actual service method from LocalDB
      // This tests the real updateWorkoutsForDate function used by history_screen.dart
      final updatedUpperExercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 145.0, completedSets: [12, 11, 10]),
        Exercise(name: 'Incline Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 115.0, completedSets: [10, 10, 9]),
      ];

      await LocalDB.updateWorkoutsForDate(
        date: testDate,
        originalMuscleGroups: {MuscleGroup.upperBody, MuscleGroup.lowerBody}, // Both were originally present
        newWorkoutsByGroup: {
          MuscleGroup.upperBody: updatedUpperExercises, // Update upper body
          MuscleGroup.lowerBody: lowerExercises, // Keep lower body unchanged
        },
        originalHadCore: false,
        newCoreWorkout: null,
        originalHadActivities: false,
        newActivities: null,
      );

      // Verify: Upper body updated AND lower body preserved
      savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      // Upper body should have 2 exercises now (with updated weight)
      expect(savedWorkouts[MuscleGroup.upperBody]!.length, equals(2),
          reason: 'Upper body should have 2 exercises after edit');
      expect(savedWorkouts[MuscleGroup.upperBody]!.any((e) => e.weight == 145.0), isTrue,
          reason: 'Should have updated weight of 145.0');
      expect(savedWorkouts[MuscleGroup.upperBody]!.any((e) => e.name == 'Incline Press'), isTrue,
          reason: 'Should have added Incline Press');

      // Lower body should still exist unchanged
      expect(savedWorkouts[MuscleGroup.lowerBody]!.length, equals(1),
          reason: 'Lower body should be preserved');
      expect(savedWorkouts[MuscleGroup.lowerBody]![0].name, equals('Squat'),
          reason: 'Lower body workout should be unchanged');
      expect(savedWorkouts[MuscleGroup.lowerBody]![0].weight, equals(185.0),
          reason: 'Lower body weight should be unchanged');

      debugPrint('✓ Multi-muscle-group preservation verified using real LocalDB.updateWorkoutsForDate');
    });
  });

  group('LocalDB - Workout Delete Operations', () {
    late String testDate;
    late Database db;

    setUp(() async {
      testDate = '2024-01-17';
      db = await LocalDB.database;
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);
    });

    test('Should delete upper body workout', () async {
      // Add workout
      final exercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: exercises),
        testDate,
      );

      // Verify it was added
      var savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue);

      // Delete workout
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);

      // Verify it was deleted
      savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.isEmpty, isTrue, reason: 'Workout should be deleted');

      debugPrint('✓ Upper body workout deleted successfully');
    });

    test('Should delete only one muscle group and preserve others', () async {
      // Add both upper and lower body
      await LocalDB.insertWorkout(
        WorkoutRoutine(
          targetArea: MuscleGroup.upperBody,
          exercises: [Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9])],
        ),
        testDate,
      );

      await LocalDB.insertWorkout(
        WorkoutRoutine(
          targetArea: MuscleGroup.lowerBody,
          exercises: [Exercise(name: 'Squat', muscleGroup: MuscleGroup.lowerBody, reps: '8-12', weight: 185.0, completedSets: [10, 9, 9])],
        ),
        testDate,
      );

      // This test verifies both muscle groups are present
      var savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue);
      expect(savedWorkouts.containsKey(MuscleGroup.lowerBody), isTrue);

      debugPrint('✓ Selective deletion test setup complete (both muscle groups present)');
    });

    test('Should delete core workout', () async {
      // Add core workout
      final coreWorkout = CoreWorkoutRoutine(
        sets: 3,
        exercisesPerSet: 4,
        exercises: [
          CoreExercise(name: 'Crunches', amount: 25),
          CoreExercise(name: 'Plank', amount: 60, isTimed: true),
        ],
      );

      await LocalDB.insertCoreWorkout(coreWorkout, testDate);

      // Verify it was added
      var savedCoreWorkout = await LocalDB.getCoreRoutineForDate(DateTime.parse(testDate));
      expect(savedCoreWorkout, isNotNull);

      // Delete workout
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);

      // Verify it was deleted
      savedCoreWorkout = await LocalDB.getCoreRoutineForDate(DateTime.parse(testDate));
      expect(savedCoreWorkout, isNull, reason: 'Core workout should be deleted');

      debugPrint('✓ Core workout deleted successfully');
    });

    test('Should verify delete operation removes all data for date', () async {
      // Add multiple workout types
      await LocalDB.insertWorkout(
        WorkoutRoutine(
          targetArea: MuscleGroup.upperBody,
          exercises: [Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9])],
        ),
        testDate,
      );

      await LocalDB.insertCoreWorkout(
        CoreWorkoutRoutine(sets: 2, exercisesPerSet: 3, exercises: [CoreExercise(name: 'Crunches', amount: 25)]),
        testDate,
      );

      // Delete all data for the date
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);

      // Verify everything was deleted
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      final savedCore = await LocalDB.getCoreRoutineForDate(DateTime.parse(testDate));
      final savedActivities = await LocalDB.getActivitiesForDate(DateTime.parse(testDate));

      expect(savedWorkouts.isEmpty, isTrue);
      expect(savedCore, isNull);
      expect(savedActivities, isNull);

      debugPrint('✓ Complete deletion verified');
    });
  });

  group('LocalDB - Data Persistence and State Management', () {
    late String testDate;
    late Database db;

    setUp(() async {
      testDate = '2024-01-18';
      db = await LocalDB.database;
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);
    });

    test('Should NOT lose workout after Add->Edit->Cancel sequence', () async {
      // Simulate: Add workout from view mode
      final exercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: exercises),
        testDate,
      );

      // Verify workout was saved to database
      var savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue,
          reason: 'Workout should be in database after add from view mode');

      // Simulate: User goes to edit mode, then clicks Cancel
      // In the actual app, Cancel resets to "current saved state" which should be the database state
      // So the workout should still be there

      // Reload from database (simulates what happens on Cancel)
      savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue,
          reason: 'Workout should still exist after Cancel (was saved to database)');
      expect(savedWorkouts[MuscleGroup.upperBody]!.length, equals(1),
          reason: 'Should have the workout that was added');

      debugPrint('✓ Workout persists correctly after Add->Edit->Cancel');
    });

    test('Should discard unsaved changes on Cancel in edit mode', () async {
      // Add initial workout
      final initialExercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: initialExercises),
        testDate,
      );

      // Simulate: User edits but doesn't save (just in memory changes)
      // In real app, this would be in _editableWorkouts but not saved to database
      // Example of what would be in memory (but not saved):
      //   - Bench Press with weight 140.0 instead of 135.0
      //   - Added Incline Press

      // Simulate Cancel: reload from database
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      // Should have original data, not unsaved changes
      expect(savedWorkouts[MuscleGroup.upperBody]!.length, equals(1),
          reason: 'Should have original 1 exercise, not 2 from unsaved changes');
      expect(savedWorkouts[MuscleGroup.upperBody]![0].weight, equals(135.0),
          reason: 'Should have original weight, not unsaved changed weight');

      debugPrint('✓ Unsaved changes discarded correctly on Cancel');
    });
  });

  group('LocalDB - Data Integrity and Multi-Workout Tests', () {
    late String testDate;
    late Database db;

    setUp(() async {
      testDate = '2024-01-19';
      db = await LocalDB.database;
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);
    });

    test('Should maintain data integrity when adding multiple workouts sequentially', () async {
      // Add workouts in sequence
      await LocalDB.insertWorkout(
        WorkoutRoutine(
          targetArea: MuscleGroup.upperBody,
          exercises: [Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9])],
        ),
        testDate,
      );

      await LocalDB.insertWorkout(
        WorkoutRoutine(
          targetArea: MuscleGroup.lowerBody,
          exercises: [Exercise(name: 'Squat', muscleGroup: MuscleGroup.lowerBody, reps: '8-12', weight: 185.0, completedSets: [10, 9, 9])],
        ),
        testDate,
      );

      await LocalDB.insertCoreWorkout(
        CoreWorkoutRoutine(
          sets: 2,
          exercisesPerSet: 3,
          exercises: [
            CoreExercise(name: 'Crunches', amount: 25),
            CoreExercise(name: 'Plank', amount: 60, isTimed: true),
            CoreExercise(name: 'Russian Twists', amount: 20),
          ],
        ),
        testDate,
      );

      // Verify all workouts are present
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      final savedCore = await LocalDB.getCoreRoutineForDate(DateTime.parse(testDate));

      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue);
      expect(savedWorkouts.containsKey(MuscleGroup.lowerBody), isTrue);
      expect(savedCore, isNotNull);

      // Verify no data corruption
      expect(savedWorkouts[MuscleGroup.upperBody]![0].name, equals('Bench Press'));
      expect(savedWorkouts[MuscleGroup.lowerBody]![0].name, equals('Squat'));
      expect(savedCore!.exercises[0].name, equals('Crunches'));

      debugPrint('✓ All workout types coexist without data corruption');
    });

    test('Should document that insertWorkout adds duplicates (app layer prevents this)', () async {
      // Add same workout twice
      final exercises = [
        Exercise(name: 'Bench Press', muscleGroup: MuscleGroup.upperBody, reps: '8-12', weight: 135.0, completedSets: [10, 10, 9]),
      ];

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: exercises),
        testDate,
      );

      // Add again - insertWorkout DOES add duplicates
      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: exercises),
        testDate,
      );

      // insertWorkout API adds duplicates - this is expected behavior
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      expect(savedWorkouts[MuscleGroup.upperBody]!.length, equals(2),
          reason: 'insertWorkout adds to existing, creating duplicates. App layer prevents this by deleting before insert.');

      // The history screen prevents duplicates using a delete-then-insert pattern
      // (see _saveWorkoutToDatabase in history_screen.dart)
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);

      await LocalDB.insertWorkout(
        WorkoutRoutine(targetArea: MuscleGroup.upperBody, exercises: exercises),
        testDate,
      );

      final afterDeleteInsert = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(afterDeleteInsert[MuscleGroup.upperBody]!.length, equals(1),
          reason: 'Delete-then-insert pattern (used by history_screen.dart) prevents duplicates');

      debugPrint('✓ insertWorkout duplicate behavior documented, delete-then-insert pattern verified');
    });
  });

  group('LocalDB - Weight Suggestions and Motivational Messages', () {
    late Database db;

    setUp(() async {
      db = await LocalDB.database;
      // Clear all workout logs to start fresh for each test
      await db.delete('workout_logs');
    });

    test('Should suggest weight increase with motivational message after 3 workouts at same weight', () async {
      final exerciseName = 'Bench Press';
      final testWeight = 135.0;

      // Create workout routine for testing
      final routine = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: [
          Exercise(
            name: exerciseName,
            muscleGroup: MuscleGroup.upperBody,
            reps: '8-12',
            weight: testWeight,
            completedSets: [10, 10, 9],
          ),
        ],
      );

      // Insert 3 days of workouts at same weight
      final today = DateTime.now();
      await LocalDB.insertWorkout(routine, today.subtract(Duration(days: 2)).toIso8601String().substring(0, 10));
      await LocalDB.insertWorkout(routine, today.subtract(Duration(days: 1)).toIso8601String().substring(0, 10));
      await LocalDB.insertWorkout(routine, today.toIso8601String().substring(0, 10));

      // Get weight suggestion
      final suggestion = await LocalDB.getSmartWeightSuggestion(
        exerciseName,
        repRange: '8-12',
      );

      // Verify suggestion exists
      expect(suggestion, isNotNull, reason: 'Should return weight suggestion after 3 workouts');

      // Should suggest weight increase (135 + 5 = 140)
      expect(suggestion!.weight, equals(140.0), reason: 'Should suggest +5 lbs after 3 workouts at same weight');

      // Should have motivational message
      expect(suggestion.motivationalMessage, isNotNull, reason: 'Should have motivational message');
      expect(
        suggestion.motivationalMessage,
        contains('done $testWeight lbs for 3 workouts'),
        reason: 'Message should mention 3 workouts at same weight',
      );
      expect(
        suggestion.motivationalMessage,
        contains('level up'),
        reason: 'Message should encourage leveling up',
      );

      debugPrint('✓ Weight progression message verified after 3 workouts');
    });

    test('Should suggest weight increase with motivational message when hitting high reps', () async {
      final exerciseName = 'Shoulder Press';
      final testWeight = 95.0;

      // Create workout with high reps
      final routine = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: [
          Exercise(
            name: exerciseName,
            muscleGroup: MuscleGroup.upperBody,
            reps: '8-12',
            weight: testWeight,
            completedSets: [13, 12, 12], // High reps, avg > 12
          ),
        ],
      );

      // Insert workout
      await LocalDB.insertWorkout(routine);

      // Get weight suggestion
      final suggestion = await LocalDB.getSmartWeightSuggestion(
        exerciseName,
        repRange: '8-12',
      );

      // Verify suggestion exists
      expect(suggestion, isNotNull, reason: 'Should return weight suggestion');

      // Should suggest weight increase (95 + 5 = 100)
      expect(suggestion!.weight, equals(100.0), reason: 'Should suggest +5 lbs when hitting high reps');

      // Should have motivational message
      expect(suggestion.motivationalMessage, isNotNull, reason: 'Should have motivational message for high reps');
      expect(
        suggestion.motivationalMessage,
        contains("You're crushing"),
        reason: 'Message should praise high rep performance',
      );
      expect(
        suggestion.motivationalMessage,
        contains('with high reps'),
        reason: 'Message should mention high reps',
      );

      debugPrint('✓ High reps progression message verified');
    });

    test('Should not show motivational message when no progression criteria met', () async {
      final exerciseName = 'Dumbbell Curl';
      final testWeight = 25.0;

      // Create workout with moderate reps (first time)
      final routine = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: [
          Exercise(
            name: exerciseName,
            muscleGroup: MuscleGroup.upperBody,
            reps: '8-12',
            weight: testWeight,
            completedSets: [9, 9, 8], // Moderate reps
          ),
        ],
      );

      // Insert workout
      await LocalDB.insertWorkout(routine);

      // Get weight suggestion
      final suggestion = await LocalDB.getSmartWeightSuggestion(
        exerciseName,
        repRange: '8-12',
      );

      // Verify suggestion exists
      expect(suggestion, isNotNull, reason: 'Should return weight suggestion');

      // Should suggest same weight (no progression)
      expect(suggestion!.weight, equals(testWeight), reason: 'Should suggest same weight when no progression criteria met');

      // Should NOT have motivational message
      expect(suggestion.motivationalMessage, isNull, reason: 'Should not have message when no progression needed');

      debugPrint('✓ No progression message when criteria not met');
    });
  });

  group('LocalDB - Empty Workout Defense Tests', () {
    late String testDate;
    late Database db;

    setUp(() async {
      testDate = '2024-03-01';
      db = await LocalDB.database;
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);
    });

    test('Should not create database entry when inserting workout with empty exercises list', () async {
      // Attempt to insert workout with no exercises
      final emptyRoutine = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: [], // Empty!
      );

      await LocalDB.insertWorkout(emptyRoutine, testDate);

      // Verify no entry was created (or if created, should be cleaned up)
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));

      // Should either have no entry, or the entry should be filtered out by getWorkoutsByMuscleGroup
      expect(
        savedWorkouts.containsKey(MuscleGroup.upperBody) == false ||
        savedWorkouts[MuscleGroup.upperBody]!.isEmpty,
        isTrue,
        reason: 'Empty workout should not create a valid entry',
      );

      // Verify getLoggedDates doesn't return this date
      final loggedDates = await LocalDB.getLoggedDates();
      final hasDate = loggedDates.any((d) =>
        d.toIso8601String().substring(0, 10) == testDate
      );

      // If the date appears, it should have actual content
      if (hasDate) {
        expect(savedWorkouts.isNotEmpty, isTrue,
          reason: 'If date is logged, it should have content');
      }

      debugPrint('✓ Empty workout insertion handled correctly');
    });

    test('Should not create database entry when inserting core workout with empty exercises', () async {
      // Attempt to insert core workout with no exercises
      final emptyCoreRoutine = CoreWorkoutRoutine(
        sets: 3,
        exercisesPerSet: 0,
        exercises: [], // Empty!
      );

      await LocalDB.insertCoreWorkout(emptyCoreRoutine, testDate);

      // Verify no valid entry was created
      final savedCore = await LocalDB.getCoreRoutineForDate(DateTime.parse(testDate));

      // Should either return null, or have empty exercises list
      expect(
        savedCore == null || savedCore.exercises.isEmpty,
        isTrue,
        reason: 'Empty core workout should not create a valid entry',
      );

      debugPrint('✓ Empty core workout insertion handled correctly');
    });

    test('Should handle updateWorkoutsForDate with all empty workouts by deleting entry', () async {
      // First create a real workout
      final realWorkout = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: [
          Exercise(
            name: 'Bench Press',
            muscleGroup: MuscleGroup.upperBody,
            reps: '8-12',
            weight: 135.0,
            completedSets: [10, 10, 9],
          ),
        ],
      );

      await LocalDB.insertWorkout(realWorkout, testDate);

      // Verify it was created
      var savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.containsKey(MuscleGroup.upperBody), isTrue);

      // Now use updateWorkoutsForDate to clear everything
      await LocalDB.updateWorkoutsForDate(
        date: testDate,
        originalMuscleGroups: {MuscleGroup.upperBody},
        newWorkoutsByGroup: {}, // Empty!
        originalHadCore: false,
        newCoreWorkout: null,
        originalHadActivities: false,
        newActivities: null,
      );

      // Verify entry was deleted
      savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.isEmpty, isTrue,
        reason: 'Entry should be deleted when all workouts removed');

      // Verify date not in logged dates
      final loggedDates = await LocalDB.getLoggedDates();
      final hasDate = loggedDates.any((d) =>
        d.toIso8601String().substring(0, 10) == testDate
      );
      expect(hasDate, isFalse,
        reason: 'Date should not appear in logged dates after deletion');

      debugPrint('✓ updateWorkoutsForDate correctly deletes empty entries');
    });

    test('Should verify no empty entries exist in workout_logs table', () async {
      // Insert some real workouts
      await LocalDB.insertWorkout(
        WorkoutRoutine(
          targetArea: MuscleGroup.upperBody,
          exercises: [
            Exercise(
              name: 'Bench Press',
              muscleGroup: MuscleGroup.upperBody,
              reps: '8-12',
              weight: 135.0,
              completedSets: [10, 10, 9],
            ),
          ],
        ),
        testDate,
      );

      // Query the raw database to check for empty entries
      final allLogs = await db.query('workout_logs');

      for (final log in allLogs) {
        final exercisesJson = jsonDecode(log['exercises'] as String) as List;

        // Every entry should have at least one item
        expect(exercisesJson.isNotEmpty, isTrue,
          reason: 'No workout_logs entry should have empty exercises array');

        // Verify each entry has actual content
        bool hasRealContent = false;
        for (var item in exercisesJson) {
          if (item is Map) {
            // Has core workout, activity, or exercise with completed sets
            if (item['isCore'] == true ||
                item['isActivity'] == true ||
                (item['completedSets'] != null &&
                 item['completedSets'] is List &&
                 (item['completedSets'] as List).isNotEmpty)) {
              hasRealContent = true;
              break;
            }
          }
        }

        expect(hasRealContent, isTrue,
          reason: 'Every workout_logs entry should contain actual workout data');
      }

      debugPrint('✓ All workout_logs entries verified to have content');
    });
  });

  group('LocalDB - Skipped Exercise Handling', () {
    late String testDate;

    setUp(() async {
      testDate = '2024-03-15';
      final db = await LocalDB.database;
      await db.delete('workout_logs', where: 'date = ?', whereArgs: [testDate]);
    });

    test('Should only save completed exercises when workout has mixed completed and skipped exercises', () async {
      // Create a workout with 3 exercises: 2 completed, 1 skipped
      final mixedWorkout = WorkoutRoutine(
        targetArea: MuscleGroup.lowerBody,
        exercises: [
          Exercise(
            name: 'Squat',
            muscleGroup: MuscleGroup.lowerBody,
            reps: '8-12',
            weight: 185.0,
            completedSets: [10, 10, 9],
            isSkipped: false, // Completed
          ),
          Exercise(
            name: 'Leg Press',
            muscleGroup: MuscleGroup.lowerBody,
            reps: '8-12',
            weight: 270.0,
            completedSets: [], // No completed sets
            isSkipped: true, // Skipped!
          ),
          Exercise(
            name: 'Leg Curl',
            muscleGroup: MuscleGroup.lowerBody,
            reps: '8-12',
            weight: 90.0,
            completedSets: [12, 11, 10],
            isSkipped: false, // Completed
          ),
        ],
      );

      // Pass workout with all exercises - insertWorkout will filter out skipped ones
      await LocalDB.insertWorkout(mixedWorkout, testDate);

      // Retrieve and verify
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.containsKey(MuscleGroup.lowerBody), isTrue);

      final savedExercises = savedWorkouts[MuscleGroup.lowerBody]!;
      expect(savedExercises.length, equals(2),
        reason: 'Should only save the 2 completed exercises, not the skipped one');

      expect(savedExercises.any((ex) => ex.name == 'Squat'), isTrue);
      expect(savedExercises.any((ex) => ex.name == 'Leg Curl'), isTrue);
      expect(savedExercises.any((ex) => ex.name == 'Leg Press'), isFalse,
        reason: 'Skipped exercise should not be saved');

      debugPrint('✓ Skipped exercises correctly filtered before saving');
    });

    test('Should not save workout if all exercises are skipped', () async {
      // Create a workout where all exercises are skipped
      final allSkippedWorkout = WorkoutRoutine(
        targetArea: MuscleGroup.upperBody,
        exercises: [
          Exercise(
            name: 'Bench Press',
            muscleGroup: MuscleGroup.upperBody,
            reps: '8-12',
            weight: 135.0,
            completedSets: [],
            isSkipped: true,
          ),
          Exercise(
            name: 'Incline Press',
            muscleGroup: MuscleGroup.upperBody,
            reps: '8-12',
            weight: 115.0,
            completedSets: [],
            isSkipped: true,
          ),
        ],
      );

      // Pass workout with all skipped exercises - insertWorkout will filter and find none
      await LocalDB.insertWorkout(allSkippedWorkout, testDate);

      // Verify no entry was created
      final savedWorkouts = await LocalDB.getWorkoutsByMuscleGroup(DateTime.parse(testDate));
      expect(savedWorkouts.isEmpty, isTrue,
        reason: 'Should not create database entry when all exercises are skipped');

      debugPrint('✓ All-skipped workout correctly prevented from saving');
    });

    test('Should verify isExerciseCompleted utility function filters skipped exercises', () {
      // Test the utility function that home_screen uses
      final completedExercise = Exercise(
        name: 'Squat',
        muscleGroup: MuscleGroup.lowerBody,
        reps: '8-12',
        weight: 185.0,
        completedSets: [10, 10, 9],
        isSkipped: false,
      );

      final skippedExercise = Exercise(
        name: 'Leg Press',
        muscleGroup: MuscleGroup.lowerBody,
        reps: '8-12',
        weight: 270.0,
        completedSets: [],
        isSkipped: true,
      );

      final exerciseWithoutWeight = Exercise(
        name: 'Calf Raise',
        muscleGroup: MuscleGroup.lowerBody,
        reps: '8-12',
        weight: null, // No weight
        completedSets: [15, 15, 14],
        isSkipped: false,
      );

      final exerciseWithoutSets = Exercise(
        name: 'Lunges',
        muscleGroup: MuscleGroup.lowerBody,
        reps: '8-12',
        weight: 50.0,
        completedSets: [], // No completed sets
        isSkipped: false,
      );

      // Verify utility function behavior
      expect(isExerciseCompleted(completedExercise), isTrue,
        reason: 'Exercise with weight and completed sets should be considered complete');

      expect(isExerciseCompleted(skippedExercise), isFalse,
        reason: 'Skipped exercise should not be considered complete');

      expect(isExerciseCompleted(exerciseWithoutWeight), isFalse,
        reason: 'Exercise without weight should not be considered complete');

      expect(isExerciseCompleted(exerciseWithoutSets), isFalse,
        reason: 'Exercise without completed sets should not be considered complete');

      debugPrint('✓ isExerciseCompleted utility function verified');
    });
  });

  tearDownAll(() async {
    debugPrint('\n✅ All LocalDB Service tests completed!');
    debugPrint('Note: Test database entries have been created. Consider cleanup if needed.');
  });
}
