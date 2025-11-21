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
