import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/exercise_model.dart';
import '../models/custom_exercise_preferences.dart';
import '../services/workout_preferences_service.dart';

class AddExerciseCard extends StatefulWidget {
  final MuscleGroup muscleGroup;
  final List<Exercise> currentExercises;
  final Function(Exercise) onAdd;
  final VoidCallback onCancel;

  const AddExerciseCard({
    super.key,
    required this.muscleGroup,
    required this.currentExercises,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<AddExerciseCard> createState() => _AddExerciseCardState();
}

class _AddExerciseCardState extends State<AddExerciseCard> {
  final _formKey = GlobalKey<FormState>();
  Exercise? _selectedExercise;
  bool _isCreatingNew = false;

  // Controllers for new exercise
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _minRepsController = TextEditingController(text: '8');
  final _maxRepsController = TextEditingController(text: '12');
  final _notesController = TextEditingController();
  final _videoLinkController = TextEditingController();
  final _targetMusclesController = TextEditingController();
  late ExerciseCategory _selectedCategory;

  List<Exercise> _availableExercises = [];
  List<UserCustomExercise> _customExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Set default category based on muscle group
    if (widget.muscleGroup == MuscleGroup.lowerBody) {
      _selectedCategory = ExerciseCategory.legs;
    } else {
      _selectedCategory = ExerciseCategory.chest;
    }
    _loadExercises();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    _notesController.dispose();
    _videoLinkController.dispose();
    _targetMusclesController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    List<Exercise> allExercises = [];

    if (widget.muscleGroup == MuscleGroup.upperBody) {
      allExercises.addAll(ExerciseDatabase.chestExercises);
      allExercises.addAll(ExerciseDatabase.backExercises);
      allExercises.addAll(ExerciseDatabase.shoulderExercises);
      allExercises.addAll(ExerciseDatabase.armExercises);
    } else if (widget.muscleGroup == MuscleGroup.lowerBody) {
      allExercises.addAll(ExerciseDatabase.legExercises);
    }

    final customExercises = await WorkoutPreferencesService.getUserCustomExercises();
    final filteredCustom = customExercises
        .where((ex) => ex.muscleGroup == widget.muscleGroup)
        .toList();

    final currentExerciseNames = widget.currentExercises.map((e) => e.name).toSet();
    final availableExercises = allExercises
        .where((ex) => !currentExerciseNames.contains(ex.name))
        .toList();
    final availableCustom = filteredCustom
        .where((ex) => !currentExerciseNames.contains(ex.name))
        .toList();

    setState(() {
      _availableExercises = availableExercises;
      _customExercises = availableCustom;
      _isLoading = false;
    });
  }

  void _submitExercise() async {
    if (_isCreatingNew) {
      // Create new custom exercise
      if (_formKey.currentState!.validate()) {
        final name = _nameController.text.trim();
        final weight = double.tryParse(_weightController.text);
        final minReps = int.tryParse(_minRepsController.text);
        final maxReps = int.tryParse(_maxRepsController.text);
        final videoLink = _videoLinkController.text.trim();

        // Parse target muscles from comma-separated list
        final targetMusclesText = _targetMusclesController.text.trim();
        final targetMuscles = targetMusclesText.isEmpty
            ? <String>[]
            : targetMusclesText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

        if (minReps == null || maxReps == null || maxReps < minReps) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please enter valid rep range')),
          );
          return;
        }

        final newCustomExercise = UserCustomExercise(
          name: name,
          category: _selectedCategory,
          targetMuscles: targetMuscles,
          reps: '$minReps-$maxReps',
          notes: _notesController.text.trim(),
          beginnerWeight: weight,
          videoLink: videoLink,
          alwaysInclude: false,
          neverInclude: false,
        );

        final success = await WorkoutPreferencesService.addUserCustomExercise(newCustomExercise);

        if (!success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exercise already exists')),
          );
          return;
        }

        final exercise = Exercise(
          name: name,
          muscleGroup: widget.muscleGroup,
          targetMuscles: targetMuscles,
          reps: '$minReps-$maxReps',
          videoLink: videoLink,
          notes: _notesController.text.trim(),
          weight: weight,
        );

        widget.onAdd(exercise);

        // Clear form and reset to selection mode
        _nameController.clear();
        _weightController.clear();
        _minRepsController.text = '8';
        _maxRepsController.text = '12';
        _notesController.clear();
        _videoLinkController.clear();
        _targetMusclesController.clear();
        setState(() {
          _isCreatingNew = false;
          // Reset to appropriate default category
          if (widget.muscleGroup == MuscleGroup.lowerBody) {
            _selectedCategory = ExerciseCategory.legs;
          } else {
            _selectedCategory = ExerciseCategory.chest;
          }
        });
      }
    } else {
      // Add existing exercise
      if (_selectedExercise != null) {
        widget.onAdd(_selectedExercise!);
        setState(() {
          _selectedExercise = null;
        });
      }
    }
  }

  List<ExerciseCategory> _getAvailableCategories() {
    if (widget.muscleGroup == MuscleGroup.lowerBody) {
      return [ExerciseCategory.legs];
    } else {
      // Upper body
      return [
        ExerciseCategory.chest,
        ExerciseCategory.back,
        ExerciseCategory.shoulders,
        ExerciseCategory.arms,
      ];
    }
  }

  String _getCategoryDisplayName(ExerciseCategory category) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: EdgeInsets.all(16),
        color: primaryColor,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.all(16),
      color: primaryColor,
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Exercise',
                style: TextStyles.titleText.copyWith(color: secondaryColor),
              ),
              SizedBox(height: 16),

              // Unified dropdown
              DropdownButtonFormField<String>(
                value: _isCreatingNew ? 'create_new' : (_selectedExercise?.name),
                decoration: InputDecoration(
                  labelText: 'Choose Exercise',
                  labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: secondaryColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: secondaryColor, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: secondaryColor, width: 2.5),
                  ),
                ),
                dropdownColor: primaryColor,
                style: TextStyle(color: secondaryColor),
                menuMaxHeight: 400,
                items: [
                  // Create New option as first item
                  DropdownMenuItem<String>(
                    value: 'create_new',
                    child: Text(
                      'Create New Exercise',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  // Standard exercises (without header)
                  ..._availableExercises.map((exercise) => DropdownMenuItem<String>(
                    value: exercise.name,
                    child: Text(exercise.name),
                  )),
                  // Custom exercises with (Custom) suffix (without header)
                  ..._customExercises.map((customEx) {
                    return DropdownMenuItem<String>(
                      value: customEx.name,
                      child: Text('${customEx.name} (Custom)'),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value == 'create_new') {
                      _isCreatingNew = true;
                      _selectedExercise = null;
                    } else {
                      _isCreatingNew = false;
                      // Find the selected exercise
                      final standardEx = _availableExercises.where((ex) => ex.name == value).firstOrNull;
                      if (standardEx != null) {
                        _selectedExercise = standardEx;
                      } else {
                        final customEx = _customExercises.where((ex) => ex.name == value).firstOrNull;
                        if (customEx != null) {
                          _selectedExercise = Exercise(
                            name: customEx.name,
                            muscleGroup: customEx.muscleGroup,
                            targetMuscles: customEx.targetMuscles,
                            reps: customEx.reps,
                            videoLink: customEx.videoLink,
                            notes: customEx.notes,
                            weight: customEx.beginnerWeight,
                          );
                        }
                      }
                    }
                  });
                },
              ),

              SizedBox(height: 16),

              // Show additional fields when creating new
              if (_isCreatingNew) ...[
                // Exercise name
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: secondaryColor),
                  decoration: InputDecoration(
                    labelText: 'Exercise Name',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: 'e.g., Cable Flyes',
                    hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an exercise name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12),

                // Muscle group dropdown
                DropdownButtonFormField<ExerciseCategory>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Muscle Group',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                  ),
                  dropdownColor: primaryColor,
                  style: TextStyle(color: secondaryColor),
                  items: _getAvailableCategories().map((category) {
                    return DropdownMenuItem<ExerciseCategory>(
                      value: category,
                      child: Text(_getCategoryDisplayName(category)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                SizedBox(height: 12),

                // Target muscles (optional)
                TextFormField(
                  controller: _targetMusclesController,
                  style: TextStyle(color: secondaryColor),
                  decoration: InputDecoration(
                    labelText: 'Target Muscles (optional)',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: 'e.g., Upper chest, Lats',
                    hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Starting weight
                TextFormField(
                  controller: _weightController,
                  style: TextStyle(color: secondaryColor),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Starting Weight (lbs, optional)',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: 'e.g., 25',
                    hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Rep range
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minRepsController,
                        style: TextStyle(color: secondaryColor),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Min Reps',
                          labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: secondaryColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('-', style: TextStyle(fontSize: 18, color: secondaryColor)),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _maxRepsController,
                        style: TextStyle(color: secondaryColor),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Max Reps',
                          labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: secondaryColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Form notes (optional)
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: secondaryColor),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Form Notes (optional)',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: 'Add form cues or tips...',
                    hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Video URL (optional)
                TextFormField(
                  controller: _videoLinkController,
                  style: TextStyle(color: secondaryColor),
                  decoration: InputDecoration(
                    labelText: 'Video URL (optional)',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: 'Add a video link',
                    hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: secondaryColor,
                      side: BorderSide(color: secondaryColor),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: (!_isCreatingNew && _selectedExercise == null)
                        ? null
                        : _submitExercise,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'Add Exercise',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
