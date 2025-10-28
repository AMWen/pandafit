class CoreExercise {
  final String name;
  final int amount;
  final bool isTimed;
  final int increment;
  final String videoLink;

  CoreExercise({
    required this.name,
    required this.amount,
    this.isTimed = false,
    this.increment = 1,
    this.videoLink = '',
  });

  String formatText() {
    return isTimed ? '${amount}s $name' : '$amount $name';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'isTimed': isTimed,
      'increment': increment,
      'videoLink': videoLink,
    };
  }

  factory CoreExercise.fromJson(Map<String, dynamic> json) {
    return CoreExercise(
      name: json['name'],
      amount: json['amount'],
      isTimed: json['isTimed'] ?? false,
      increment: json['increment'] ?? 1,
      videoLink: json['videoLink'] ?? '',
    );
  }

  CoreExercise copyWith({
    String? name,
    int? amount,
    bool? isTimed,
    int? increment,
    String? videoLink,
  }) {
    return CoreExercise(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isTimed: isTimed ?? this.isTimed,
      increment: increment ?? this.increment,
      videoLink: videoLink ?? this.videoLink,
    );
  }
}

class CoreWorkoutRoutine {
  final int sets;
  final int exercisesPerSet;
  final List<CoreExercise> exercises;
  final DateTime? date;

  CoreWorkoutRoutine({
    required this.sets,
    required this.exercisesPerSet,
    required this.exercises,
    this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'sets': sets,
      'exercisesPerSet': exercisesPerSet,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'date': date?.toIso8601String(),
    };
  }

  factory CoreWorkoutRoutine.fromJson(Map<String, dynamic> json) {
    return CoreWorkoutRoutine(
      sets: json['sets'],
      exercisesPerSet: json['exercisesPerSet'],
      exercises: (json['exercises'] as List).map((e) => CoreExercise.fromJson(e)).toList(),
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
    );
  }
}
