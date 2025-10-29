import 'package:hive/hive.dart';
import 'exercise_model.dart';

part 'custom_exercise_preferences.g.dart';

/// Exercise categories for better organization
@HiveType(typeId: 0)
enum ExerciseCategory {
  @HiveField(0)
  chest,
  @HiveField(1)
  back,
  @HiveField(2)
  shoulders,
  @HiveField(3)
  arms,
  @HiveField(4)
  legs,
}

String exerciseCategoryToString(ExerciseCategory category) {
  switch (category) {
    case ExerciseCategory.chest:
      return 'Chest';
    case ExerciseCategory.back:
      return 'Back';
    case ExerciseCategory.shoulders:
      return 'Shoulders';
    case ExerciseCategory.arms:
      return 'Arms';
    case ExerciseCategory.legs:
      return 'Legs';
  }
}

ExerciseCategory stringToExerciseCategory(String str) {
  switch (str) {
    case 'Chest':
      return ExerciseCategory.chest;
    case 'Back':
      return ExerciseCategory.back;
    case 'Shoulders':
      return ExerciseCategory.shoulders;
    case 'Arms':
      return ExerciseCategory.arms;
    case 'Legs':
      return ExerciseCategory.legs;
    default:
      return ExerciseCategory.chest;
  }
}

/// Model for custom exercise preferences
/// Allows users to customize exercises with their own settings
@HiveType(typeId: 1)
class CustomExercisePreference extends HiveObject {
  @HiveField(0)
  final String exerciseName; // The exercise name (must match one in ExerciseDatabase)

  @HiveField(1)
  final bool alwaysInclude; // Whether to always include this exercise in workouts

  @HiveField(2)
  final double? customStartingWeight; // Custom starting weight (overrides default)

  @HiveField(3)
  final String? customRepRange; // Custom rep range (overrides default)

  @HiveField(4)
  final bool neverInclude; // Whether to never include this exercise in workouts

  @HiveField(5)
  final String? customNotes; // Custom form notes (overrides default)

  @HiveField(6)
  final String? customVideoLink; // Custom video link (overrides default)

  CustomExercisePreference({
    required this.exerciseName,
    this.alwaysInclude = false,
    this.customStartingWeight,
    this.customRepRange,
    this.neverInclude = false,
    this.customNotes,
    this.customVideoLink,
  });
}

/// Model for user-added custom exercises that aren't in the default database
@HiveType(typeId: 2)
class UserCustomExercise extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final ExerciseCategory category;

  @HiveField(2)
  final List<String> targetMuscles;

  @HiveField(3)
  final String reps; // Format: "min-max" e.g. "8-12"

  @HiveField(4)
  final String notes;

  @HiveField(5)
  final double? beginnerWeight;

  @HiveField(6)
  final String videoLink;

  @HiveField(7)
  final bool alwaysInclude;

  @HiveField(8)
  final bool neverInclude;

  UserCustomExercise({
    required this.name,
    required this.category,
    this.targetMuscles = const [],
    this.reps = "8-12",
    this.notes = '',
    this.beginnerWeight,
    this.videoLink = '',
    this.alwaysInclude = false,
    this.neverInclude = false,
  });

  // Sets is always 3 for all exercises
  int get sets => 3;

  // Helper to get muscle group for workout generation
  MuscleGroup get muscleGroup {
    switch (category) {
      case ExerciseCategory.legs:
        return MuscleGroup.lowerBody;
      default:
        return MuscleGroup.upperBody;
    }
  }
}

/// Workout generation preferences
@HiveType(typeId: 3)
class WorkoutGenerationPreferences extends HiveObject {
  @HiveField(0)
  final int upperBodyChestCount;

  @HiveField(1)
  final int upperBodyBackCount;

  @HiveField(2)
  final int upperBodyShoulderCount;

  @HiveField(3)
  final int upperBodyArmCount;

  @HiveField(4)
  final int lowerBodyCount;

  WorkoutGenerationPreferences({
    this.upperBodyChestCount = 1,
    this.upperBodyBackCount = 1,
    this.upperBodyShoulderCount = 1,
    this.upperBodyArmCount = 2,
    this.lowerBodyCount = 4,
  });

  WorkoutGenerationPreferences copyWith({
    int? upperBodyChestCount,
    int? upperBodyBackCount,
    int? upperBodyShoulderCount,
    int? upperBodyArmCount,
    int? lowerBodyCount,
  }) {
    return WorkoutGenerationPreferences(
      upperBodyChestCount: upperBodyChestCount ?? this.upperBodyChestCount,
      upperBodyBackCount: upperBodyBackCount ?? this.upperBodyBackCount,
      upperBodyShoulderCount: upperBodyShoulderCount ?? this.upperBodyShoulderCount,
      upperBodyArmCount: upperBodyArmCount ?? this.upperBodyArmCount,
      lowerBodyCount: lowerBodyCount ?? this.lowerBodyCount,
    );
  }
}
