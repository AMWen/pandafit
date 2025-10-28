enum MuscleGroup {
  upperBody,
  lowerBody,
  core,
}

String muscleGroupToString(MuscleGroup group) {
  switch (group) {
    case MuscleGroup.upperBody:
      return 'Upper Body';
    case MuscleGroup.lowerBody:
      return 'Lower Body';
    case MuscleGroup.core:
      return 'Core';
  }
}

MuscleGroup stringToMuscleGroup(String str) {
  switch (str) {
    case 'Upper Body':
      return MuscleGroup.upperBody;
    case 'Lower Body':
      return MuscleGroup.lowerBody;
    case 'Core':
      return MuscleGroup.core;
    default:
      return MuscleGroup.upperBody;
  }
}

class Exercise {
  final String name;
  final MuscleGroup muscleGroup;
  final List<String> targetMuscles;
  final int sets;
  final String reps; // e.g., "8-12" or "10-15"
  final String videoLink;
  final String notes;

  // Tracking fields (filled in during workout)
  double? weight; // in lbs
  List<int> completedSets; // actual reps completed for each set

  Exercise({
    required this.name,
    required this.muscleGroup,
    this.targetMuscles = const [],
    this.sets = 3,
    this.reps = "8-12",
    this.videoLink = '',
    this.notes = '',
    this.weight,
    List<int>? completedSets,
  }) : completedSets = completedSets ?? [];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'muscleGroup': muscleGroupToString(muscleGroup),
      'targetMuscles': targetMuscles,
      'sets': sets,
      'reps': reps,
      'videoLink': videoLink,
      'notes': notes,
      'weight': weight,
      'completedSets': completedSets,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'],
      muscleGroup: stringToMuscleGroup(json['muscleGroup']),
      targetMuscles: List<String>.from(json['targetMuscles'] ?? []),
      sets: json['sets'] ?? 3,
      reps: json['reps'] ?? "8-12",
      videoLink: json['videoLink'] ?? '',
      notes: json['notes'] ?? '',
      weight: json['weight']?.toDouble(),
      completedSets: List<int>.from(json['completedSets'] ?? []),
    );
  }

  // Create a copy with updated tracking data
  Exercise copyWith({
    String? name,
    MuscleGroup? muscleGroup,
    List<String>? targetMuscles,
    int? sets,
    String? reps,
    String? videoLink,
    String? notes,
    double? weight,
    List<int>? completedSets,
  }) {
    return Exercise(
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      targetMuscles: targetMuscles ?? this.targetMuscles,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      videoLink: videoLink ?? this.videoLink,
      notes: notes ?? this.notes,
      weight: weight ?? this.weight,
      completedSets: completedSets ?? this.completedSets,
    );
  }

  String formatSummary() {
    if (weight == null || completedSets.isEmpty) {
      return '$name: $sets sets of $reps reps';
    }
    final setsStr = completedSets.map((r) => '$sets×$r').join(', ');
    return '$name: $weight lbs → $setsStr';
  }
}

class WorkoutRoutine {
  final MuscleGroup targetArea;
  final List<Exercise> exercises;

  WorkoutRoutine({
    required this.targetArea,
    required this.exercises,
  });

  Map<String, dynamic> toJson() {
    return {
      'targetArea': muscleGroupToString(targetArea),
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) {
    return WorkoutRoutine(
      targetArea: stringToMuscleGroup(json['targetArea']),
      exercises: (json['exercises'] as List).map((e) => Exercise.fromJson(e)).toList(),
    );
  }
}
