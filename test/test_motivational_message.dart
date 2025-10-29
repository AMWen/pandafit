import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pandafit/data/services/localdb_service.dart';
import 'package:pandafit/data/models/exercise_model.dart';

/// Integration test for motivational messages in progressive overload feature
///
/// This test verifies that:
/// 1. After 3 workouts with same weight, user gets a "level up" message
/// 2. When hitting high reps, user gets a "crushing it" message
/// 3. No message when progression isn't warranted
///
/// To run this test:
/// 1. Run: flutter test test/test_motivational_message.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Motivational Message Integration Tests', () {
    test('Should show motivational message after 3 days of same weight', () async {
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

      // Insert 3 days of workouts
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
      expect(suggestion, isNotNull, reason: 'Should return a weight suggestion after 3 workouts');

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
        contains('Time to level up'),
        reason: 'Message should encourage leveling up',
      );

      // Print results for manual verification
      // ignore: avoid_print
      print('\n✓ Test passed: 3 days same weight');
      // ignore: avoid_print
      print('  Weight suggestion: ${suggestion.weight} lbs');
      // ignore: avoid_print
      print('  Motivational message: "${suggestion.motivationalMessage}"');
    });

    test('Should show motivational message when hitting high reps consistently', () async {
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
      expect(suggestion, isNotNull, reason: 'Should return a weight suggestion');

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

      // Print results for manual verification
      // ignore: avoid_print
      print('\n✓ Test passed: High reps progression');
      // ignore: avoid_print
      print('  Weight suggestion: ${suggestion.weight} lbs');
      // ignore: avoid_print
      print('  Motivational message: "${suggestion.motivationalMessage}"');
    });

    test('Should not show motivational message when no progression needed', () async {
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
      expect(suggestion, isNotNull, reason: 'Should return a weight suggestion');

      // Should suggest same weight (no progression)
      expect(suggestion!.weight, equals(testWeight), reason: 'Should suggest same weight when no progression criteria met');

      // Should NOT have motivational message
      expect(suggestion.motivationalMessage, isNull, reason: 'Should not have message when no progression needed');

      // Print results for manual verification
      // ignore: avoid_print
      print('\n✓ Test passed: No progression needed');
      // ignore: avoid_print
      print('  Weight suggestion: ${suggestion.weight} lbs (same weight)');
      // ignore: avoid_print
      print('  Motivational message: None (as expected)');
    });
  });

  // Note: Manual cleanup recommended - or clear database after testing
  tearDownAll(() async {
    // ignore: avoid_print
    print('\nTest cleanup note: Consider clearing test workout entries from database');
  });
}
