import 'activity_attachment.dart';

class Activity {
  final String name;
  final int durationMinutes;
  final String? notes;
  final DateTime? date;
  final List<ActivityAttachment>? attachments;

  Activity({
    required this.name,
    required this.durationMinutes,
    this.notes,
    this.date,
    this.attachments,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'date': date?.toIso8601String(),
      'attachments': attachments?.map((a) => a.toMap()).toList(),
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      name: map['name'],
      durationMinutes: map['durationMinutes'],
      notes: map['notes'],
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      attachments: map['attachments'] != null
          ? (map['attachments'] as List)
              .map((a) => ActivityAttachment.fromMap(a as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Activity copyWith({
    String? name,
    int? durationMinutes,
    String? notes,
    DateTime? date,
    List<ActivityAttachment>? attachments,
  }) {
    return Activity(
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      attachments: attachments ?? this.attachments,
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
