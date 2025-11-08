import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/constants.dart';
import '../data/models/exercise_model.dart';
import '../data/models/custom_exercise_preferences.dart';
import '../data/services/workout_preferences_service.dart';
import '../utils/ui_helpers.dart';

class CreateCustomExerciseScreen extends StatefulWidget {
  final MuscleGroup muscleGroup;

  const CreateCustomExerciseScreen({
    super.key,
    required this.muscleGroup,
  });

  @override
  State<CreateCustomExerciseScreen> createState() => _CreateCustomExerciseScreenState();
}

class _CreateCustomExerciseScreenState extends State<CreateCustomExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _minRepsController = TextEditingController(text: '8');
  final _maxRepsController = TextEditingController(text: '12');
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createExercise() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final weight = double.tryParse(_weightController.text);
      final minReps = int.tryParse(_minRepsController.text);
      final maxReps = int.tryParse(_maxRepsController.text);

      if (minReps == null || maxReps == null) {
        showSnackbar(context, 'Please enter valid rep range');
        return;
      }

      if (maxReps < minReps) {
        showSnackbar(context, 'Max reps must be >= min reps');
        return;
      }

      // Determine category based on muscle group
      ExerciseCategory category;
      if (widget.muscleGroup == MuscleGroup.lowerBody) {
        category = ExerciseCategory.legs;
      } else {
        // Default to chest for upper body, user can change in settings later
        category = ExerciseCategory.chest;
      }

      final newCustomExercise = UserCustomExercise(
        name: name,
        category: category,
        targetMuscles: [],
        reps: '$minReps-$maxReps',
        notes: _notesController.text.trim(),
        beginnerWeight: weight,
        videoLink: '',
        alwaysInclude: false,
        neverInclude: false,
      );

      // Save to Hive
      final success = await WorkoutPreferencesService.addUserCustomExercise(newCustomExercise);

      if (!success) {
        if (!mounted) return;
        showSnackbar(context, 'Exercise already exists');
        return;
      }

      // Create Exercise object to return
      final exercise = Exercise(
        name: name,
        muscleGroup: widget.muscleGroup,
        targetMuscles: [],
        reps: '$minReps-$maxReps',
        videoLink: '',
        notes: _notesController.text.trim(),
        weight: weight,
      );

      if (!mounted) return;
      Navigator.pop(context, exercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Custom Exercise'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  color: primaryColor,
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exercise Details',
                          style: TextStyles.titleText.copyWith(color: secondaryColor),
                        ),
                        SizedBox(height: 16),

                        // Exercise name
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(color: secondaryColor),
                          decoration: InputDecoration(
                            labelText: 'Exercise Name',
                            labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                            hintText: 'e.g., Cable Flyes, Decline Bench Press',
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

                        SizedBox(height: 16),

                        // Starting weight
                        TextFormField(
                          controller: _weightController,
                          style: TextStyle(color: secondaryColor),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Starting Weight (lbs)',
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

                        SizedBox(height: 16),

                        // Rep range
                        Text(
                          'Rep Range',
                          style: TextStyle(
                            color: secondaryColor.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minRepsController,
                                style: TextStyle(color: secondaryColor),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'Min',
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
                                  final val = int.tryParse(value);
                                  if (val == null || val <= 0) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('-', style: TextStyle(fontSize: 24, color: secondaryColor)),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _maxRepsController,
                                style: TextStyle(color: secondaryColor),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: 'Max',
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
                                  final val = int.tryParse(value);
                                  if (val == null || val <= 0) {
                                    return 'Invalid';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Form notes
                        TextFormField(
                          controller: _notesController,
                          style: TextStyle(color: secondaryColor),
                          maxLines: 3,
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

                        SizedBox(height: 16),

                        // Create button
                        Center(
                          child: ElevatedButton(
                            onPressed: _createExercise,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: Text(
                              'Create Exercise',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
