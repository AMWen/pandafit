class Activity {
  final String name;
  final int durationMinutes;
  final String? notes;
  final DateTime? date;

  Activity({
    required this.name,
    required this.durationMinutes,
    this.notes,
    this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'date': date?.toIso8601String(),
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      name: map['name'],
      durationMinutes: map['durationMinutes'],
      notes: map['notes'],
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
    );
  }

  Activity copyWith({
    String? name,
    int? durationMinutes,
    String? notes,
    DateTime? date,
  }) {
    return Activity(
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      date: date ?? this.date,
    );
  }
}

class ActivityRoutine {
  final List<Activity> activities;

  ActivityRoutine({required this.activities});

  Map<String, dynamic> toMap() {
    return {
      'activities': activities.map((a) => a.toMap()).toList(),
    };
  }

  factory ActivityRoutine.fromMap(Map<String, dynamic> map) {
    return ActivityRoutine(
      activities: (map['activities'] as List)
          .map((a) => Activity.fromMap(a))
          .toList(),
    );
  }
}
