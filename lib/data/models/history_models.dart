/// Helper class to store exercise history
class ExerciseHistory {
  final String date;
  final double? weight;
  final List<int> completedSets;

  ExerciseHistory({
    required this.date,
    this.weight,
    required this.completedSets,
  });
}

/// Helper class to store activity history
class ActivityHistory {
  final String date;
  final int durationMinutes;
  final String? notes;

  ActivityHistory({
    required this.date,
    required this.durationMinutes,
    this.notes,
  });
}
