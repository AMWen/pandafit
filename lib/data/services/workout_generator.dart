import 'dart:math';

import '../constants.dart';
import '../models/exercise_model.dart';
import '../models/custom_exercise_preferences.dart';
import 'localdb_service.dart';
import 'workout_preferences_service.dart';

class WorkoutGenerator {
  // Generate a workout for the selected target area with smart suggestions
  static Future<WorkoutRoutine> generateWorkout(MuscleGroup targetArea) async {
    // Get randomly selected exercises from database
    final exercises = await _getRandomExercises(targetArea);

    // Apply smart suggestions and custom preferences to each exercise
    final exercisesWithSuggestions = await Future.wait(
      exercises.map((exercise) async {
        // Check for custom preferences
        final customPref = await WorkoutPreferencesService.getPreferenceForExercise(exercise.name);

        // Get smart weight suggestion based on history, passing the exercise's rep range
        final suggestion = await LocalDB.getSmartWeightSuggestion(
          exercise.name,
          repRange: customPref?.customRepRange ?? exercise.reps,
        );

        // Apply custom preferences if they exist
        var updatedExercise = exercise;
        if (customPref != null) {
          updatedExercise = exercise.copyWith(
            reps: customPref.customRepRange ?? exercise.reps,
            weight: suggestion?.weight ?? customPref.customStartingWeight ?? exercise.weight,
            motivationalMessage: suggestion?.motivationalMessage,
          );
        } else {
          updatedExercise = exercise.copyWith(
            weight: suggestion?.weight ?? exercise.weight,
            motivationalMessage: suggestion?.motivationalMessage,
          );
        }

        return updatedExercise;
      }),
    );

    return WorkoutRoutine(
      targetArea: targetArea,
      exercises: exercisesWithSuggestions,
    );
  }

  // Randomly select exercises from each category for the target area
  // Uses deterministic seeding based on date to ensure same workout for same day
  // Now supports custom exercise preferences and user-added exercises
  static Future<List<Exercise>> _getRandomExercises(MuscleGroup targetArea) async {
    // Create deterministic seed based on current date
    final now = DateTime.now();
    final seed = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final random = Random(seed);

    // Get workout generation preferences
    final genPrefs = await WorkoutPreferencesService.getWorkoutGenerationPreferences();

    // Get exercises marked as "always include"
    final alwaysIncludeNames = await WorkoutPreferencesService.getAlwaysIncludeExercises();

    // Get exercises marked as "never include"
    final neverIncludeNames = await WorkoutPreferencesService.getNeverIncludeExercises();

    // Get user custom exercises
    final userCustomExercises = await WorkoutPreferencesService.getUserCustomExercises();

    final selectedExercises = <Exercise>[];
    final alwaysIncludedExercises = <Exercise>[];

    // Helper function to check if exercise should be always included
    bool shouldAlwaysInclude(String exerciseName) {
      return alwaysIncludeNames.contains(exerciseName);
    }

    // Helper function to check if exercise should be never included
    bool shouldNeverInclude(String exerciseName) {
      return neverIncludeNames.contains(exerciseName);
    }

    // Helper function to convert UserCustomExercise to Exercise
    Exercise convertUserCustomExercise(UserCustomExercise custom) {
      return Exercise(
        name: custom.name,
        muscleGroup: custom.muscleGroup, // Use the getter from UserCustomExercise
        targetMuscles: custom.targetMuscles,
        reps: custom.reps,
        videoLink: custom.videoLink,
        notes: custom.notes,
        weight: custom.beginnerWeight,
      );
    }

    // Helper function to process exercise pool for a category
    void processExercisePool({
      required List<Exercise> pool,
      required int randomCount,
      required Random random,
    }) {
      // Filter out never-include exercises
      final filteredPool = pool.where((ex) => !shouldNeverInclude(ex.name)).toList();

      // Separate always-include from regular pool
      final alwaysInclude = filteredPool.where((ex) => shouldAlwaysInclude(ex.name)).toList();
      final regular = filteredPool.where((ex) => !shouldAlwaysInclude(ex.name)).toList();

      // Add always-included exercises
      alwaysIncludedExercises.addAll(alwaysInclude);

      // Pick random exercises IN ADDITION TO always-included
      if (randomCount > 0 && regular.isNotEmpty) {
        final shuffled = List<Exercise>.from(regular)..shuffle(random);
        selectedExercises.addAll(shuffled.take(randomCount.clamp(0, regular.length)));
      }
    }

    if (targetArea == MuscleGroup.upperBody) {
      // For upper body: select from each category based on preferences

      // Chest exercises
      final chestPool = List<Exercise>.from(ExerciseDatabase.chestExercises);
      chestPool.addAll(
        userCustomExercises
            .where((ex) => ex.category == ExerciseCategory.chest)
            .map(convertUserCustomExercise)
      );
      processExercisePool(
        pool: chestPool,
        randomCount: genPrefs.upperBodyChestCount,
        random: random,
      );

      // Back exercises
      final backPool = List<Exercise>.from(ExerciseDatabase.backExercises);
      backPool.addAll(
        userCustomExercises
            .where((ex) => ex.category == ExerciseCategory.back)
            .map(convertUserCustomExercise)
      );
      processExercisePool(
        pool: backPool,
        randomCount: genPrefs.upperBodyBackCount,
        random: random,
      );

      // Shoulder exercises
      final shoulderPool = List<Exercise>.from(ExerciseDatabase.shoulderExercises);
      shoulderPool.addAll(
        userCustomExercises
            .where((ex) => ex.category == ExerciseCategory.shoulders)
            .map(convertUserCustomExercise)
      );
      processExercisePool(
        pool: shoulderPool,
        randomCount: genPrefs.upperBodyShoulderCount,
        random: random,
      );

      // Arm exercises
      final armPool = List<Exercise>.from(ExerciseDatabase.armExercises);
      armPool.addAll(
        userCustomExercises
            .where((ex) => ex.category == ExerciseCategory.arms)
            .map(convertUserCustomExercise)
      );
      processExercisePool(
        pool: armPool,
        randomCount: genPrefs.upperBodyArmCount,
        random: random,
      );
    } else if (targetArea == MuscleGroup.lowerBody) {
      // For lower body: select from leg exercises
      final legPool = List<Exercise>.from(ExerciseDatabase.legExercises);
      legPool.addAll(
        userCustomExercises
            .where((ex) => ex.category == ExerciseCategory.legs)
            .map(convertUserCustomExercise)
      );
      processExercisePool(
        pool: legPool,
        randomCount: genPrefs.lowerBodyCount,
        random: random,
      );
    }

    // Combine always-included exercises first, then regular selections
    return [...alwaysIncludedExercises, ...selectedExercises];
  }

}
