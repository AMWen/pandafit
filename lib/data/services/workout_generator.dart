import 'dart:math';

import '../constants.dart';
import '../models/exercise_model.dart';
import 'localdb_service.dart';

class WorkoutGenerator {
  // Generate a workout for the selected target area with smart suggestions
  static Future<WorkoutRoutine> generateWorkout(MuscleGroup targetArea) async {
    // Get randomly selected exercises from database
    final exercises = _getRandomExercises(targetArea);

    // Apply smart suggestions to each exercise
    final exercisesWithSuggestions = await Future.wait(
      exercises.map((exercise) async {
        // Get smart weight suggestion based on history, passing the exercise's rep range
        final suggestedWeight = await LocalDB.getSmartWeightSuggestion(
          exercise.name,
          repRange: exercise.reps,
        );

        // Use suggested weight from history, or keep exercise's beginner weight
        return exercise.copyWith(weight: suggestedWeight ?? exercise.weight);
      }),
    );

    return WorkoutRoutine(
      targetArea: targetArea,
      exercises: exercisesWithSuggestions,
    );
  }

  // Randomly select exercises from each category for the target area
  // Uses deterministic seeding based on date to ensure same workout for same day
  static List<Exercise> _getRandomExercises(MuscleGroup targetArea) {
    // Create deterministic seed based on current date
    final now = DateTime.now();
    final seed = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final random = Random(seed);

    final selectedExercises = <Exercise>[];

    if (targetArea == MuscleGroup.upperBody) {
      // For upper body: select 1 from each category (chest, back, shoulders, arms)

      // Pick 1 random chest exercise
      if (ExerciseDatabase.chestExercises.isNotEmpty) {
        selectedExercises.add(
          ExerciseDatabase.chestExercises[random.nextInt(ExerciseDatabase.chestExercises.length)]
        );
      }

      // Pick 1 random back exercise
      if (ExerciseDatabase.backExercises.isNotEmpty) {
        selectedExercises.add(
          ExerciseDatabase.backExercises[random.nextInt(ExerciseDatabase.backExercises.length)]
        );
      }

      // Pick 1 random shoulder exercise
      if (ExerciseDatabase.shoulderExercises.isNotEmpty) {
        selectedExercises.add(
          ExerciseDatabase.shoulderExercises[random.nextInt(ExerciseDatabase.shoulderExercises.length)]
        );
      }

      // Pick 2 random arm exercises
      if (ExerciseDatabase.armExercises.length >= 2) {
        final shuffledArms = List<Exercise>.from(ExerciseDatabase.armExercises)..shuffle(random);
        selectedExercises.addAll(shuffledArms.take(2));
      } else if (ExerciseDatabase.armExercises.isNotEmpty) {
        selectedExercises.add(
          ExerciseDatabase.armExercises[random.nextInt(ExerciseDatabase.armExercises.length)]
        );
      }
    } else {
      // For lower body: select 3-4 random leg exercises
      if (ExerciseDatabase.legExercises.length >= 4) {
        final shuffledLegs = List<Exercise>.from(ExerciseDatabase.legExercises)..shuffle(random);
        selectedExercises.addAll(shuffledLegs.take(4));
      } else {
        // If we don't have enough exercises, just return all of them
        selectedExercises.addAll(ExerciseDatabase.legExercises);
      }
    }

    return selectedExercises;
  }

}
