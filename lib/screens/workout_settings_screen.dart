import 'package:flutter/material.dart';
import '../data/constants.dart';
import '../data/models/custom_exercise_preferences.dart';
import '../data/models/exercise_model.dart';
import '../data/services/workout_preferences_service.dart';
import '../utils/ui_helpers.dart';

class WorkoutSettingsScreen extends StatefulWidget {
  const WorkoutSettingsScreen({super.key}); //

  @override
  State<WorkoutSettingsScreen> createState() => _WorkoutSettingsScreenState();
}

class _WorkoutSettingsScreenState extends State<WorkoutSettingsScreen> {
  WorkoutGenerationPreferences? _genPrefs;
  List<CustomExercisePreference> _customPrefs = [];
  List<UserCustomExercise> _userExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final genPrefs = await WorkoutPreferencesService.getWorkoutGenerationPreferences();
    final customPrefs = await WorkoutPreferencesService.getCustomExercisePreferences();
    final userExercises = await WorkoutPreferencesService.getUserCustomExercises();

    setState(() {
      _genPrefs = genPrefs;
      _customPrefs = customPrefs;
      _userExercises = userExercises;
      _isLoading = false;
    });
  }

  Future<void> _saveGenerationPreferences() async {
    if (_genPrefs != null) {
      await WorkoutPreferencesService.saveWorkoutGenerationPreferences(_genPrefs!);
      _showSnackbar('Workout generation preferences saved');
    }
  }

  Future<void> _resetGenerationPreferences() async {
    final defaultPrefs = WorkoutGenerationPreferences();
    setState(() {
      _genPrefs = defaultPrefs;
    });
    await WorkoutPreferencesService.saveWorkoutGenerationPreferences(defaultPrefs);
    _showSnackbar('Reset to default settings');
  }

  void _showSnackbar(String message) {
    showSnackbar(context, message);
  }

  void _showAddCustomExerciseDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _AddCustomExerciseDialog(
            onSave: (exercise) async {
              final success = await WorkoutPreferencesService.addUserCustomExercise(exercise);
              if (success) {
                _showSnackbar('Custom exercise added');
                _loadPreferences();
              } else {
                _showSnackbar('Exercise already exists');
              }
            },
          ),
    );
  }

  void _showEditExercisePreferenceDialog(String exerciseName, {bool isUserCustom = false}) {
    showDialog(
      context: context,
      builder:
          (context) => _EditExercisePreferenceDialog(
            exerciseName: exerciseName,
            isUserCustom: isUserCustom,
            onSave: () {
              _showSnackbar('Exercise preferences saved');
              _loadPreferences();
            },
            onDelete:
                isUserCustom
                    ? () async {
                      await WorkoutPreferencesService.removeUserCustomExercise(exerciseName);
                      _showSnackbar('Custom exercise removed');
                      _loadPreferences();
                    }
                    : null,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _genPrefs == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Workout Settings')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Workout Settings')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Workout Generation Settings
          Text(
            'Workout Generation',
            style: TextStyles.titleText.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Number of random exercises per day (in addition to always included)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 8),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upper Body', style: TextStyles.mediumText),
                  SizedBox(height: 8),
                  _buildCounterRow(
                    'Chest exercises',
                    _genPrefs!.upperBodyChestCount,
                    (value) => setState(() {
                      _genPrefs = _genPrefs!.copyWith(upperBodyChestCount: value);
                    }),
                  ),
                  _buildCounterRow(
                    'Back exercises',
                    _genPrefs!.upperBodyBackCount,
                    (value) => setState(() {
                      _genPrefs = _genPrefs!.copyWith(upperBodyBackCount: value);
                    }),
                  ),
                  _buildCounterRow(
                    'Shoulder exercises',
                    _genPrefs!.upperBodyShoulderCount,
                    (value) => setState(() {
                      _genPrefs = _genPrefs!.copyWith(upperBodyShoulderCount: value);
                    }),
                  ),
                  _buildCounterRow(
                    'Arm exercises',
                    _genPrefs!.upperBodyArmCount,
                    (value) => setState(() {
                      _genPrefs = _genPrefs!.copyWith(upperBodyArmCount: value);
                    }),
                  ),
                  SizedBox(height: 16),
                  Text('Lower Body', style: TextStyles.mediumText),
                  SizedBox(height: 8),
                  _buildCounterRow(
                    'Leg exercises',
                    _genPrefs!.lowerBodyCount,
                    (value) => setState(() {
                      _genPrefs = _genPrefs!.copyWith(lowerBodyCount: value);
                    }),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(onPressed: _resetGenerationPreferences, child: Text('Reset')),
                      SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saveGenerationPreferences,
                        child: Text('Save Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Custom Exercises
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom Exercises',
                style: TextStyles.titleText.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.add_circle),
                onPressed: _showAddCustomExerciseDialog,
                tooltip: 'Add custom exercise',
              ),
            ],
          ),
          Text(
            'Add your own custom exercises',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 8),

          if (_userExercises.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No custom exercises yet. Tap + to add one!',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...(_userExercises.map((exercise) {
              final weightStr =
                  exercise.beginnerWeight != null
                      ? '${formatWeight(exercise.beginnerWeight!)}lbs'
                      : 'No weight';
              final includeStatus =
                  exercise.alwaysInclude
                      ? 'Always included'
                      : exercise.neverInclude
                      ? 'Never included'
                      : '';

              return Card(
                child: ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(
                    [
                      exerciseCategoryToString(exercise.category),
                      weightStr,
                      '${exercise.reps} reps',
                      if (includeStatus.isNotEmpty) includeStatus,
                    ].join(' - '),
                    style: TextStyle(color: exercise.neverInclude ? Colors.red[700] : null),
                  ),
                  trailing: Icon(
                    exercise.neverInclude ? Icons.block : Icons.edit,
                    color: exercise.neverInclude ? Colors.red : null,
                  ),
                  onTap: () => _showEditExercisePreferenceDialog(exercise.name, isUserCustom: true),
                ),
              );
            }).toList()),

          SizedBox(height: 24),

          // Default Exercises
          Text(
            'Default Exercises',
            style: TextStyles.titleText.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Customize default exercises',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 8),

          _buildExerciseCategorySection('Chest', ExerciseDatabase.chestExercises),
          _buildExerciseCategorySection('Back', ExerciseDatabase.backExercises),
          _buildExerciseCategorySection('Shoulders', ExerciseDatabase.shoulderExercises),
          _buildExerciseCategorySection('Arms', ExerciseDatabase.armExercises),
          _buildExerciseCategorySection('Legs', ExerciseDatabase.legExercises),
        ],
      ),
    );
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle_outline),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center)),
            IconButton(
              icon: Icon(Icons.add_circle_outline),
              onPressed: value < 10 ? () => onChanged(value + 1) : null,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseCategorySection(String category, List<Exercise> exercises) {
    return ExpansionTile(
      title: Text(category, style: TextStyles.mediumText),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      childrenPadding: EdgeInsets.zero,
      visualDensity: VisualDensity(horizontal: 0, vertical: -4),
      children:
          exercises.map((exercise) {
            final hasCustomPref = _customPrefs.any((p) => p.exerciseName == exercise.name);
            final customPref =
                hasCustomPref
                    ? _customPrefs.firstWhere((p) => p.exerciseName == exercise.name)
                    : null;

            // Build formatted subtitle with defaults or custom values
            final weight = customPref?.customStartingWeight ?? exercise.weight ?? 0;
            final weightStr = '${formatWeight(weight)}lbs';
            final reps = customPref?.customRepRange ?? exercise.reps;
            final includeStatus =
                customPref?.alwaysInclude == true
                    ? 'Always included'
                    : customPref?.neverInclude == true
                    ? 'Never included'
                    : '';

            return ListTile(
              title: Text(exercise.name),
              subtitle: Text(
                [weightStr, '$reps reps', if (includeStatus.isNotEmpty) includeStatus].join(' - '),
                style: TextStyle(
                  color: customPref?.neverInclude == true ? Colors.red[700] : Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                hasCustomPref ? (customPref!.neverInclude ? Icons.block : Icons.star) : Icons.edit,
                color:
                    hasCustomPref ? (customPref!.neverInclude ? Colors.red : Colors.amber) : null,
              ),
              onTap: () => _showEditExercisePreferenceDialog(exercise.name),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              visualDensity: VisualDensity(horizontal: 0, vertical: -4),
            );
          }).toList(),
    );
  }
}

class _AddCustomExerciseDialog extends StatefulWidget {
  final Function(UserCustomExercise) onSave;

  const _AddCustomExerciseDialog({required this.onSave});

  @override
  State<_AddCustomExerciseDialog> createState() => _AddCustomExerciseDialogState();
}

class _AddCustomExerciseDialogState extends State<_AddCustomExerciseDialog> {
  final _nameController = TextEditingController();
  final _minRepsController = TextEditingController(text: '8');
  final _maxRepsController = TextEditingController(text: '12');
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final _videoLinkController = TextEditingController();
  ExerciseCategory _selectedCategory = ExerciseCategory.chest;
  bool _alwaysInclude = false;

  @override
  void dispose() {
    _nameController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    _videoLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Custom Exercise', style: TextStyles.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise Name*', style: TextStyles.labelText),
            settingsTextInput(
              controller: _nameController,
              hintText: 'Enter exercise name',
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: 10),
            Text('Category*', style: TextStyles.labelText),
            DropdownButtonFormField<ExerciseCategory>(
              value: _selectedCategory,
              decoration: InputDecoration(border: InputBorder.none),
              items:
                  ExerciseCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(
                            exerciseCategoryToString(category),
                            style: TextStyles.inputText,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            SizedBox(height: 10),
            Text('Starting Weight (lbs)', style: TextStyles.labelText),
            settingsTextInput(
              controller: _weightController,
              hintText: 'Default: 0',
              isNumeric: true,
              allowDecimal: true,
            ),
            SizedBox(height: 10),
            Text('Rep Range*', style: TextStyles.labelText),
            Row(
              children: [
                Expanded(
                  child: settingsTextInput(
                    controller: _minRepsController,
                    labelText: 'Min',
                    isNumeric: true,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: settingsTextInput(
                    controller: _maxRepsController,
                    labelText: 'Max',
                    isNumeric: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            SwitchListTile(
              title: Text('Always Include', style: TextStyles.labelText),
              value: _alwaysInclude,
              onChanged: (value) => setState(() => _alwaysInclude = value),
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(height: 10),
            Text('Form Notes (optional)', style: TextStyles.labelText),
            settingsTextInput(
              controller: _notesController,
              hintText: 'Add form cues or tips',
              maxLines: 3,
            ),
            SizedBox(height: 10),
            Text('Video Link (optional)', style: TextStyles.labelText),
            settingsTextInput(controller: _videoLinkController, hintText: 'Add a video URL'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        FilledButton(
          onPressed: () {
            // Validate name
            if (_nameController.text.trim().isEmpty) {
              if (!context.mounted) return;
              showSnackbar(context, 'Please enter exercise name');
              return;
            }

            // Validate reps
            final minReps = int.tryParse(_minRepsController.text);
            final maxReps = int.tryParse(_maxRepsController.text);

            if (minReps == null || maxReps == null) {
              if (!context.mounted) return;
              showSnackbar(context, 'Please enter valid min and max reps');
              return;
            }

            if (maxReps < minReps) {
              if (!context.mounted) return;
              showSnackbar(context, 'Max reps must be >= min reps');
              return;
            }

            // Default to 0 if no starting weight is entered
            final weight =
                _weightController.text.isEmpty
                    ? 0.0
                    : double.tryParse(_weightController.text) ?? 0.0;

            final exercise = UserCustomExercise(
              name: _nameController.text.trim(),
              category: _selectedCategory,
              reps: '$minReps-$maxReps',
              beginnerWeight: weight,
              notes: _notesController.text.trim(),
              videoLink: _videoLinkController.text.trim(),
              alwaysInclude: _alwaysInclude,
            );

            widget.onSave(exercise);
            Navigator.pop(context);
          },
          child: Text('Add'),
        ),
      ],
    );
  }
}

class _EditExercisePreferenceDialog extends StatefulWidget {
  final String exerciseName;
  final bool isUserCustom;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  const _EditExercisePreferenceDialog({
    required this.exerciseName,
    required this.isUserCustom,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_EditExercisePreferenceDialog> createState() => _EditExercisePreferenceDialogState();
}

class _EditExercisePreferenceDialogState extends State<_EditExercisePreferenceDialog> {
  final _weightController = TextEditingController();
  final _minRepsController = TextEditingController();
  final _maxRepsController = TextEditingController();
  final _notesController = TextEditingController();
  final _videoLinkController = TextEditingController();
  bool _alwaysInclude = false;
  bool _neverInclude = false;
  bool _isLoading = true;
  String _defaultWeight = '';
  String _defaultReps = '';
  String _defaultNotes = '';
  String _defaultVideoLink = '';

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final pref = await WorkoutPreferencesService.getPreferenceForExercise(widget.exerciseName);

    // Find the default exercise to get default values
    Exercise? defaultExercise;
    UserCustomExercise? userCustomExercise;

    // Check if this is a user custom exercise
    if (widget.isUserCustom) {
      final userExercises = await WorkoutPreferencesService.getUserCustomExercises();
      for (var ex in userExercises) {
        if (ex.name == widget.exerciseName) {
          userCustomExercise = ex;
          break;
        }
      }
    } else {
      // Check built-in exercises
      final allExercises = [
        ...ExerciseDatabase.chestExercises,
        ...ExerciseDatabase.backExercises,
        ...ExerciseDatabase.shoulderExercises,
        ...ExerciseDatabase.armExercises,
        ...ExerciseDatabase.legExercises,
      ];

      for (var ex in allExercises) {
        if (ex.name == widget.exerciseName) {
          defaultExercise = ex;
          break;
        }
      }
    }

    setState(() {
      // Set default values based on exercise type
      if (userCustomExercise != null) {
        _defaultWeight = userCustomExercise.beginnerWeight?.toString() ?? '0';
        _defaultReps = userCustomExercise.reps;
        _defaultNotes = userCustomExercise.notes;
        _defaultVideoLink = userCustomExercise.videoLink;
        _alwaysInclude = userCustomExercise.alwaysInclude;
        _neverInclude = userCustomExercise.neverInclude;
        _notesController.text = userCustomExercise.notes;
        _videoLinkController.text = userCustomExercise.videoLink;
      } else {
        _defaultWeight = defaultExercise?.weight?.toString() ?? '0';
        _defaultReps = defaultExercise?.reps ?? '8-12';
        _defaultNotes = defaultExercise?.notes ?? '';
        _defaultVideoLink = defaultExercise?.videoLink ?? '';
        _notesController.text = defaultExercise?.notes ?? '';
        _videoLinkController.text = defaultExercise?.videoLink ?? '';
      }

      // Pre-fill with custom preferences if they exist, otherwise use defaults
      if (pref != null) {
        _alwaysInclude = pref.alwaysInclude;
        _neverInclude = pref.neverInclude;
        _weightController.text = pref.customStartingWeight?.toString() ?? _defaultWeight;

        final repsRange = pref.customRepRange ?? _defaultReps;
        final repsParts = repsRange.split('-');
        if (repsParts.length == 2) {
          _minRepsController.text = repsParts[0];
          _maxRepsController.text = repsParts[1];
        } else {
          // Fallback for unexpected format
          _minRepsController.text = '8';
          _maxRepsController.text = '12';
        }

        // Load custom notes and video link if they exist
        _notesController.text = pref.customNotes ?? _defaultNotes;
        _videoLinkController.text = pref.customVideoLink ?? _defaultVideoLink;
      } else {
        // Use defaults
        _weightController.text = _defaultWeight;
        final repsParts = _defaultReps.split('-');
        if (repsParts.length == 2) {
          _minRepsController.text = repsParts[0];
          _maxRepsController.text = repsParts[1];
        } else {
          _minRepsController.text = '8';
          _maxRepsController.text = '12';
        }
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    _notesController.dispose();
    _videoLinkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validate reps
    final minReps = int.tryParse(_minRepsController.text);
    final maxReps = int.tryParse(_maxRepsController.text);

    if (minReps == null || maxReps == null) {
      if (!mounted) return;
      showSnackbar(context, 'Please enter valid min and max reps');
      return;
    }

    if (maxReps < minReps) {
      if (!mounted) return;
      showSnackbar(context, 'Max reps must be >= min reps');
      return;
    }

    // Use default weight if field is empty
    final weight =
        _weightController.text.isEmpty
            ? double.tryParse(_defaultWeight)
            : double.tryParse(_weightController.text);
    final reps = '$minReps-$maxReps';

    // For user custom exercises, update the UserCustomExercise itself
    if (widget.isUserCustom) {
      final userExercises = await WorkoutPreferencesService.getUserCustomExercises();
      final existing = userExercises.firstWhere((ex) => ex.name == widget.exerciseName);

      final updated = UserCustomExercise(
        name: existing.name,
        category: existing.category,
        targetMuscles: existing.targetMuscles,
        reps: reps,
        notes: _notesController.text.trim(),
        beginnerWeight: weight,
        videoLink: _videoLinkController.text.trim(),
        alwaysInclude: _alwaysInclude,
        neverInclude: _neverInclude,
      );

      await WorkoutPreferencesService.updateUserCustomExercise(updated);
    } else {
      // For default exercises, check if values match defaults
      final defaultWeightValue = double.tryParse(_defaultWeight);
      final isDefaultWeight = weight == defaultWeightValue;
      final isDefaultReps = reps == _defaultReps;
      final isDefaultInclusion = !_alwaysInclude && !_neverInclude;
      final isDefaultNotes = _notesController.text.trim() == _defaultNotes;
      final isDefaultVideoLink = _videoLinkController.text.trim() == _defaultVideoLink;

      if (isDefaultWeight &&
          isDefaultReps &&
          isDefaultInclusion &&
          isDefaultNotes &&
          isDefaultVideoLink) {
        // All values match defaults, remove custom preference instead of saving
        await WorkoutPreferencesService.removeCustomExercisePreference(widget.exerciseName);
      } else {
        // Save as CustomExercisePreference only if values differ from defaults
        final pref = CustomExercisePreference(
          exerciseName: widget.exerciseName,
          alwaysInclude: _alwaysInclude,
          neverInclude: _neverInclude,
          customStartingWeight: weight,
          customRepRange: reps,
          customNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          customVideoLink:
              _videoLinkController.text.trim().isEmpty ? null : _videoLinkController.text.trim(),
        );

        await WorkoutPreferencesService.setCustomExercisePreference(pref);
      }
    }

    if (!mounted) return;
    widget.onSave();
    Navigator.pop(context);
  }

  void _reset() {
    // Only reset for default exercises (not user custom exercises)
    if (!widget.isUserCustom) {
      setState(() {
        // Reset to default values
        _weightController.text = _defaultWeight;
        final repsParts = _defaultReps.split('-');
        if (repsParts.length == 2) {
          _minRepsController.text = repsParts[0];
          _maxRepsController.text = repsParts[1];
        } else {
          _minRepsController.text = '8';
          _maxRepsController.text = '12';
        }
        _notesController.text = _defaultNotes;
        _videoLinkController.text = _defaultVideoLink;
        _alwaysInclude = false;
        _neverInclude = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AlertDialog(content: Center(child: CircularProgressIndicator()));
    }

    final selectedInclusionMode = _alwaysInclude ? 'always' : (_neverInclude ? 'never' : 'random');

    return AlertDialog(
      title: Text(widget.exerciseName, style: TextStyles.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Include in Workouts', style: TextStyles.labelText),
            RadioListTile<String>(
              title: Text('Random (default)', style: TextStyles.inputText),
              value: 'random',
              groupValue: selectedInclusionMode,
              onChanged:
                  (value) => setState(() {
                    _alwaysInclude = false;
                    _neverInclude = false;
                  }),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity(horizontal: 0, vertical: -4),
            ),
            RadioListTile<String>(
              title: Text('Always include', style: TextStyles.inputText),
              value: 'always',
              groupValue: selectedInclusionMode,
              onChanged:
                  (value) => setState(() {
                    _alwaysInclude = true;
                    _neverInclude = false;
                  }),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity(horizontal: 0, vertical: -4),
            ),
            RadioListTile<String>(
              title: Text('Never include', style: TextStyles.inputText),
              value: 'never',
              groupValue: selectedInclusionMode,
              onChanged:
                  (value) => setState(() {
                    _alwaysInclude = false;
                    _neverInclude = true;
                  }),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity(horizontal: 0, vertical: -4),
            ),
            SizedBox(height: 8),
            Text('Starting Weight (lbs)', style: TextStyles.labelText),
            settingsTextInput(
              controller: _weightController,
              hintText: 'Default: $_defaultWeight lbs',
              isNumeric: true,
              allowDecimal: true,
            ),
            SizedBox(height: 10),
            Text('Rep Range', style: TextStyles.labelText),
            Row(
              children: [
                Expanded(
                  child: settingsTextInput(
                    controller: _minRepsController,
                    labelText: 'Min Reps',
                    isNumeric: true,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: settingsTextInput(
                    controller: _maxRepsController,
                    labelText: 'Max Reps',
                    isNumeric: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text('Form Notes (optional)', style: TextStyles.labelText),
            settingsTextInput(
              controller: _notesController,
              hintText: _defaultNotes.isEmpty ? 'Add form cues or tips' : 'Default: $_defaultNotes',
              maxLines: 3,
            ),
            SizedBox(height: 10),
            Text('Video Link (optional)', style: TextStyles.labelText),
            settingsTextInput(
              controller: _videoLinkController,
              hintText:
                  _defaultVideoLink.isEmpty ? 'Add a video URL' : 'Default: $_defaultVideoLink',
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              widget.onDelete!();
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        if (!widget.isUserCustom) TextButton(onPressed: _reset, child: Text('Reset')),
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        FilledButton(onPressed: _save, child: Text('Save')),
      ],
    );
  }
}
