import 'package:flutter/material.dart';
import '../models/exercise_model.dart';

/// Shows a dialog to select an exercise from a list of available exercises.
/// Returns the selected exercise or null if cancelled.
Future<Exercise?> showExerciseSelectionDialog({
  required BuildContext context,
  required List<Exercise> availableExercises,
  String title = 'Add Exercise',
}) async {
  if (availableExercises.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No exercises available to add')),
    );
    return null;
  }

  Exercise? selectedExercise;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Exercise>(
              value: selectedExercise,
              decoration: const InputDecoration(
                labelText: 'Choose Exercise',
                border: OutlineInputBorder(),
              ),
              items: availableExercises.map((exercise) {
                return DropdownMenuItem<Exercise>(
                  value: exercise,
                  child: Text(exercise.name),
                );
              }).toList(),
              onChanged: (value) {
                setDialogState(() {
                  selectedExercise = value;
                });
              },
            ),
            if (selectedExercise != null) ...[
              const SizedBox(height: 16),
              Text(
                'Target: ${selectedExercise!.targetMuscles.join(', ')}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: selectedExercise == null
                ? null
                : () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );

  return (confirmed == true) ? selectedExercise : null;
}
