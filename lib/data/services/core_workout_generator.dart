import 'dart:math';
import '../constants.dart';
import '../models/core_exercise_model.dart';

class CoreWorkoutGenerator {
  static CoreWorkoutRoutine generateDailyCoreRoutine([int? seed]) {
    if (seed == null) {
      final now = DateTime.now();
      seed = DateTime(now.year, now.month, now.day, now.hour).millisecondsSinceEpoch;
    }

    final random = Random(seed);
    final option = coreRoutineOptions[random.nextInt(coreRoutineOptions.length)];
    final sets = option[0];
    final exercisesPerSet = option[1];
    final totalExercises = sets * exercisesPerSet;

    final List<CoreExercise> chosen = List.of(coreExercisePool)..shuffle(random);
    final List<CoreExercise> selected = chosen.take(exercisesPerSet).toList();

    final factor = _calculateScalingFactor(totalExercises);
    final List<CoreExercise> setsList =
        selected.map((ex) {
          final amount = _scaleAmount(ex, factor, random);
          return CoreExercise(name: ex.name, amount: amount, isTimed: ex.isTimed, videoLink: ex.videoLink, increment: ex.increment);
        }).toList();

    return CoreWorkoutRoutine(sets: sets, exercisesPerSet: exercisesPerSet, exercises: setsList);
  }

  static double _calculateScalingFactor(int totalExercises) {
    const baseVolume = 10.0;
    return baseVolume / totalExercises;
  }

  static int _scaleAmount(CoreExercise exercise, double factor, Random random) {
    final raw = (exercise.amount * factor).round();
    int base = raw ~/ exercise.increment; // for rounding

    // 5% chance to adjust by +/- 1
    if (random.nextDouble() < 0.05) {
      int adjustment = random.nextBool() ? 1 : -1;
      base = max(base + adjustment, 1);
    }

    return base * exercise.increment;
  }
}
