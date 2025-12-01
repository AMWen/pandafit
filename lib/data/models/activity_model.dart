import 'activity_attachment.dart';

class Activity {
  final String name;
  final int durationMinutes;
  final String? notes;
  final DateTime? date;
  final List<ActivityAttachment>? attachments;
  final DateTime? completedAt; // Timestamp for unique identification

  Activity({
    required this.name,
    required this.durationMinutes,
    this.notes,
    this.date,
    this.attachments,
    this.completedAt,
  });

  /// Factory constructor for creating new activities with auto-generated timestamp
  factory Activity.create({
    required String name,
    required int durationMinutes,
    String? notes,
    DateTime? date,
    List<ActivityAttachment>? attachments,
  }) {
    return Activity(
      name: name,
      durationMinutes: durationMinutes,
      notes: notes,
      date: date,
      attachments: attachments,
      completedAt: DateTime.now(), // Auto-generated for new activities
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'durationMinutes': durationMinutes,
      'notes': notes,
      'date': date?.toIso8601String(),
      'attachments': attachments?.map((a) => a.toMap()).toList(),
      'completedAt': completedAt?.toIso8601String(),
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
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
    );
  }

  /// Standard copyWith - can't set fields to null (use replaceAttachments for that)
  Activity copyWith({
    String? name,
    int? durationMinutes,
    String? notes,
    DateTime? date,
    List<ActivityAttachment>? attachments,
    DateTime? completedAt,
  }) {
    return Activity(
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      attachments: attachments ?? this.attachments,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Explicitly replace attachments (supports setting to null or empty list)
  Activity replaceAttachments(List<ActivityAttachment>? newAttachments) {
    return Activity(
      name: name,
      durationMinutes: durationMinutes,
      notes: notes,
      date: date,
      attachments: newAttachments,
      completedAt: completedAt,
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
