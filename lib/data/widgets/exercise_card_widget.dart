import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models/exercise_model.dart';

class ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final Function(Exercise) onUpdate;
  final VoidCallback onLaunchVideo;
  final bool isReadOnly;
  final VoidCallback? onSkip;
  final VoidCallback? onRestore;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onUpdate,
    required this.onLaunchVideo,
    this.isReadOnly = false,
    this.onSkip,
    this.onRestore,
  });

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  late TextEditingController _weightController;
  late List<TextEditingController> _setControllers;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.exercise.weight?.toString() ?? '',
    );

    // Parse the suggested rep range (e.g., "8-12" -> 8, or "10-15" -> 10)
    final lowEndReps = _getLowEndReps(widget.exercise.reps);

    // Initialize controllers for each set
    _setControllers = List.generate(
      widget.exercise.sets,
      (index) {
        // If completedSets exist, use them; otherwise auto-fill with low end of suggested reps
        final reps = index < widget.exercise.completedSets.length
            ? widget.exercise.completedSets[index].toString()
            : lowEndReps;
        return TextEditingController(text: reps);
      },
    );

    _weightController.addListener(_onWeightChanged);
    for (var controller in _setControllers) {
      controller.addListener(_onSetsChanged);
    }

    // Trigger initial updates to capture pre-filled values
    _onWeightChanged();
    _onSetsChanged();
  }

  // Parse the low end of the rep range (e.g., "8-12" -> "8", "10-15" -> "10")
  String _getLowEndReps(String repsRange) {
    final match = RegExp(r'(\d+)').firstMatch(repsRange);
    return match?.group(1) ?? '';
  }

  @override
  void dispose() {
    _weightController.dispose();
    for (var controller in _setControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onWeightChanged() {
    _updateExercise();
  }

  void _onSetsChanged() {
    _updateExercise();
  }

  void _updateExercise() {
    final weight = double.tryParse(_weightController.text);
    final completedSets = _setControllers
        .map((c) => int.tryParse(c.text) ?? 0)
        .where((reps) => reps > 0)
        .toList();

    final updated = widget.exercise.copyWith(
      weight: weight,
      completedSets: completedSets,
    );
    widget.onUpdate(updated);
  }

  bool get _isCompleted => widget.isReadOnly;

  String _getWorkoutSummary() {
    // If exercise has weight and completed sets, show actual results
    if (_isCompleted) {
      final weight = widget.exercise.weight!;
      final weightStr = formatWeight(weight);
      final setsStr = widget.exercise.completedSets
          .map((reps) => '${weightStr}lb x $reps')
          .join(', ');
      return 'Completed: $setsStr';
    }
    // Otherwise show suggested with weight recommendation if available
    if (widget.exercise.weight != null) {
      final weightStr = formatWeight(widget.exercise.weight!);
      return 'Suggested: ${widget.exercise.sets} sets of ${widget.exercise.reps} reps @ ${weightStr}lbs';
    }
    return 'Suggested: ${widget.exercise.sets} sets of ${widget.exercise.reps} reps';
  }

  @override
  Widget build(BuildContext context) {
    final isSkipped = widget.exercise.isSkipped;

    return Opacity(
      opacity: isSkipped ? 0.4 : 1.0,
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        color: isSkipped ? Colors.grey[300] : primaryColor,
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exercise.name,
                          style: TextStyles.mediumText.copyWith(
                            color: isSkipped ? Colors.grey[600] : secondaryColor,
                            decoration: isSkipped ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (widget.exercise.targetMuscles.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              widget.exercise.targetMuscles.join(', '),
                              style: TextStyle(
                                color: isSkipped ? Colors.grey[500] : secondaryColor.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                decoration: isSkipped ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        if (isSkipped)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Skipped for today',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Icons
                  Transform.translate(
                    offset: Offset(14, -8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Video link icon
                        if (!isSkipped)
                          Transform.translate(
                            offset: Offset(8, 0),
                            child: IconButton(
                              icon: Icon(Icons.play_circle_outline, color: Colors.red),
                              onPressed: widget.onLaunchVideo,
                              tooltip: 'Watch video',
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(),
                            ),
                          ),
                        // Info icon
                        if (!isSkipped)
                          Transform.translate(
                            offset: Offset(4, 0),
                            child: IconButton(
                              icon: Icon(Icons.info_outline, color: secondaryColor),
                              onPressed: () {
                                setState(() {
                                  _expanded = !_expanded;
                                });
                              },
                              tooltip: 'Form notes',
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(),
                            ),
                          ),
                        // Skip/Restore icon
                        if (!_isCompleted)
                          Transform.translate(
                            offset: Offset(0, 0),
                            child: IconButton(
                              icon: Icon(
                                isSkipped ? Icons.undo : Icons.remove_circle_outline,
                                color: isSkipped ? Colors.green[700] : Colors.orange[700],
                              ),
                              onPressed: isSkipped ? widget.onRestore : widget.onSkip,
                              tooltip: isSkipped ? 'Restore' : 'Skip',
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Suggested sets and reps OR actual completed sets
          if (!isSkipped)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _getWorkoutSummary(),
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: secondaryColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          if (!isSkipped)
            SizedBox(height: 8),

          // Weight input
          if (!isSkipped)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Weight: ', style: TextStyles.normalText.copyWith(color: secondaryColor)),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _weightController,
                      enabled: !_isCompleted,
                      style: TextStyle(color: secondaryColor),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                        suffixText: 'lbs',
                        suffixStyle: TextStyle(color: secondaryColor),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (!isSkipped)
            SizedBox(height: 12),

          // Sets tracking
          if (!isSkipped)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(widget.exercise.sets, (index) {
                  return SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _setControllers[index],
                      enabled: !_isCompleted,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: secondaryColor),
                      decoration: InputDecoration(
                        labelText: 'Set ${index + 1}',
                        labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                        floatingLabelStyle: TextStyle(color: secondaryColor),
                        hintText: 'reps',
                        hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: secondaryColor, width: 2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Form notes (expandable)
          if (_expanded && widget.exercise.notes.isNotEmpty && !isSkipped)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                      SizedBox(width: 4),
                      Text(
                        'Form Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.exercise.notes,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),

          SizedBox(height: 8),
        ],
      ),
    ),
    );
  }
}
