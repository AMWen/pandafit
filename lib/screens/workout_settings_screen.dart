import 'package:flutter/material.dart';
import '../data/constants.dart';
import '../data/models/custom_exercise_preferences.dart';
import '../data/models/exercise_model.dart';
import '../data/services/workout_preferences_service.dart';
import '../data/services/activity_preferences_service.dart';
import '../utils/ui_helpers.dart';

class WorkoutSettingsScreen extends StatefulWidget {
  final bool showActivitiesOnly;

  const WorkoutSettingsScreen({
    super.key,
    this.showActivitiesOnly = false,
  });

  @override
  State<WorkoutSettingsScreen> createState() => _WorkoutSettingsScreenState();
}

class _WorkoutSettingsScreenState extends State<WorkoutSettingsScreen> {
  WorkoutGenerationPreferences? _genPrefs;
  List<CustomExercisePreference> _customPrefs = [];
  List<UserCustomExercise> _userExercises = [];
  List<UserActivity> _userActivities = [];
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
    final userActivities = await ActivityPreferencesService.getAllActivities();

    setState(() {
      _genPrefs = genPrefs;
      _customPrefs = customPrefs;
      _userExercises = userExercises;
      _userActivities = userActivities..sort((a, b) => a.name.compareTo(b.name)); // Alphabetical
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
          (context) => _ExerciseDialog(
            mode: _ExerciseDialogMode.addCustom,
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
          (context) => _ExerciseDialog(
            mode: isUserCustom ? _ExerciseDialogMode.editCustom : _ExerciseDialogMode.editDefault,
            exerciseName: exerciseName,
            onSave: (exercise) {
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

  void _showAddActivityDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddActivityDialog(
        onSave: (activity) async {
          final success = await ActivityPreferencesService.addActivity(activity);
          if (success) {
            _showSnackbar('Activity added');
            _loadPreferences();
          } else {
            _showSnackbar('Activity already exists');
          }
        },
      ),
    );
  }

  void _showEditActivityDialog(UserActivity activity) {
    showDialog(
      context: context,
      builder: (context) => _EditActivityDialog(
        activity: activity,
        onSave: (updatedActivity) async {
          // If name changed, delete old entry and create new one
          if (updatedActivity.name != activity.name) {
            await ActivityPreferencesService.deleteActivity(activity.name);
          }
          await ActivityPreferencesService.updateActivity(updatedActivity);
          _showSnackbar('Activity updated');
          _loadPreferences();
        },
        onDelete: () async {
          await ActivityPreferencesService.deleteActivity(activity.name);
          _showSnackbar('Activity deleted');
          _loadPreferences();
        },
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
      appBar: AppBar(title: Text(widget.showActivitiesOnly ? 'Activity Settings' : 'Workout Settings')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Workout Generation Settings (hide if showActivitiesOnly)
          if (!widget.showActivitiesOnly) ...[
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
          ], // End of workout generation section

          // Custom Exercises (hide if showActivitiesOnly)
          if (!widget.showActivitiesOnly) ...[
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
                    style: TextStyle(color: exercise.neverInclude ? ActionColors.error : null),
                  ),
                  trailing: Icon(
                    exercise.neverInclude ? Icons.block : Icons.edit,
                    color: exercise.neverInclude ? ActionColors.error : null,
                  ),
                  onTap: () => _showEditExercisePreferenceDialog(exercise.name, isUserCustom: true),
                ),
              );
            }).toList()),

            SizedBox(height: 24),
          ], // End of custom exercises section

          // Saved Activities (only show if showActivitiesOnly)
          if (widget.showActivitiesOnly) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Activities',
                  style: TextStyles.titleText.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle),
                  onPressed: _showAddActivityDialog,
                  tooltip: 'Add activity',
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Activities auto-saved when you log them',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 8),

            if (_userActivities.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No saved activities yet. Activities will appear here after you log them!',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...(_userActivities.map((activity) {
                return Card(
                  child: ListTile(
                    title: Text(activity.name),
                    subtitle: Text('${activity.usualDurationMinutes} minutes'),
                    trailing: Icon(Icons.edit),
                    onTap: () => _showEditActivityDialog(activity),
                  ),
                );
              }).toList()),
          ],

          // Default Exercises (hide if showActivitiesOnly)
          if (!widget.showActivitiesOnly) ...[
            SizedBox(height: 24),

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
                  color: customPref?.neverInclude == true ? ActionColors.error : Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                hasCustomPref ? (customPref!.neverInclude ? Icons.block : Icons.star) : Icons.edit,
                color:
                    hasCustomPref ? (customPref!.neverInclude ? ActionColors.error : Colors.amber) : null,
              ),
              onTap: () => _showEditExercisePreferenceDialog(exercise.name),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              visualDensity: VisualDensity(horizontal: 0, vertical: -4),
            );
          }).toList(),
    );
  }
}

// Dialog modes for exercise editing/creation
enum _ExerciseDialogMode {
  addCustom, // Adding a new custom exercise
  editCustom, // Editing a custom exercise
  editDefault, // Editing a default exercise (limited fields)
}

// Unified dialog for adding/editing exercises
class _ExerciseDialog extends StatefulWidget {
  final _ExerciseDialogMode mode;
  final String? exerciseName; // null for addCustom mode
  final Function(UserCustomExercise) onSave;
  final VoidCallback? onDelete;

  const _ExerciseDialog({
    required this.mode,
    required this.onSave,
    this.exerciseName,
    this.onDelete,
  });

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _minRepsController = TextEditingController();
  final _maxRepsController = TextEditingController();
  final _notesController = TextEditingController();
  final _videoLinkController = TextEditingController();
  final _targetMusclesController = TextEditingController();
  late ExerciseCategory _selectedCategory;
  bool _alwaysInclude = false;
  bool _neverInclude = false;
  bool _isLoading = true;

  // Default values (for edit modes)
  String _defaultWeight = '';
  String _defaultReps = '';
  String _defaultNotes = '';
  String _defaultVideoLink = '';
  List<String> _defaultTargetMuscles = [];

  @override
  void initState() {
    super.initState();

    // Set default category
    _selectedCategory = ExerciseCategory.chest;

    if (widget.mode == _ExerciseDialogMode.addCustom) {
      // Adding new exercise - set defaults
      _minRepsController.text = '8';
      _maxRepsController.text = '12';
      _isLoading = false;
    } else {
      // Editing existing exercise - load data
      _loadExerciseData();
    }
  }

  Future<void> _loadExerciseData() async {
    final exerciseName = widget.exerciseName!;
    final pref = await WorkoutPreferencesService.getPreferenceForExercise(exerciseName);

    Exercise? defaultExercise;
    UserCustomExercise? userCustomExercise;

    if (widget.mode == _ExerciseDialogMode.editCustom) {
      final userExercises = await WorkoutPreferencesService.getUserCustomExercises();
      for (var ex in userExercises) {
        if (ex.name == exerciseName) {
          userCustomExercise = ex;
          break;
        }
      }
    } else {
      // editDefault - find in built-in exercises
      final allExercises = [
        ...ExerciseDatabase.chestExercises,
        ...ExerciseDatabase.backExercises,
        ...ExerciseDatabase.shoulderExercises,
        ...ExerciseDatabase.armExercises,
        ...ExerciseDatabase.legExercises,
      ];

      for (var ex in allExercises) {
        if (ex.name == exerciseName) {
          defaultExercise = ex;
          break;
        }
      }
    }

    setState(() {
      _nameController.text = exerciseName;

      if (userCustomExercise != null) {
        _defaultWeight = userCustomExercise.beginnerWeight?.toString() ?? '0';
        _defaultReps = userCustomExercise.reps;
        _defaultNotes = userCustomExercise.notes;
        _defaultVideoLink = userCustomExercise.videoLink;
        _defaultTargetMuscles = userCustomExercise.targetMuscles;
        _selectedCategory = userCustomExercise.category;
        _alwaysInclude = userCustomExercise.alwaysInclude;
        _neverInclude = userCustomExercise.neverInclude;
        _notesController.text = userCustomExercise.notes;
        _videoLinkController.text = userCustomExercise.videoLink;
        _targetMusclesController.text = userCustomExercise.targetMuscles.join(', ');
      } else {
        _selectedCategory = ExerciseCategory.chest;
        _defaultWeight = defaultExercise?.weight?.toString() ?? '0';
        _defaultReps = defaultExercise?.reps ?? '8-12';
        _defaultNotes = defaultExercise?.notes ?? '';
        _defaultVideoLink = defaultExercise?.videoLink ?? '';
        _defaultTargetMuscles = defaultExercise?.targetMuscles ?? [];
        _notesController.text = defaultExercise?.notes ?? '';
        _videoLinkController.text = defaultExercise?.videoLink ?? '';
        _targetMusclesController.text = (defaultExercise?.targetMuscles ?? []).join(', ');
      }

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
          _minRepsController.text = '8';
          _maxRepsController.text = '12';
        }

        _notesController.text = pref.customNotes ?? _defaultNotes;
        _videoLinkController.text = pref.customVideoLink ?? _defaultVideoLink;
      } else {
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
    _nameController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    _videoLinkController.dispose();
    _targetMusclesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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

    final weight =
        _weightController.text.isEmpty ? 0.0 : double.tryParse(_weightController.text) ?? 0.0;
    final reps = '$minReps-$maxReps';

    // Parse target muscles
    final targetMusclesText = _targetMusclesController.text.trim();
    final targetMuscles = targetMusclesText.isEmpty
        ? <String>[]
        : targetMusclesText.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (widget.mode == _ExerciseDialogMode.addCustom) {
      // Adding new custom exercise
      if (_nameController.text.trim().isEmpty) {
        if (!mounted) return;
        showSnackbar(context, 'Please enter exercise name');
        return;
      }

      final exercise = UserCustomExercise(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        targetMuscles: targetMuscles,
        reps: reps,
        beginnerWeight: weight,
        notes: _notesController.text.trim(),
        videoLink: _videoLinkController.text.trim(),
        alwaysInclude: _alwaysInclude,
        neverInclude: _neverInclude,
      );

      widget.onSave(exercise);
      Navigator.pop(context);
    } else if (widget.mode == _ExerciseDialogMode.editCustom) {
      // Editing custom exercise
      final userExercises = await WorkoutPreferencesService.getUserCustomExercises();
      final newName = _nameController.text.trim();

      if (newName.isEmpty) {
        if (!mounted) return;
        showSnackbar(context, 'Exercise name cannot be empty');
        return;
      }

      // Check for duplicate name (only if name changed)
      if (newName != widget.exerciseName) {
        final isDuplicate = userExercises.any((ex) => ex.name.toLowerCase() == newName.toLowerCase());
        if (isDuplicate) {
          if (!mounted) return;
          showSnackbar(context, 'An exercise with this name already exists');
          return;
        }
      }

      final updated = UserCustomExercise(
        name: newName,
        category: _selectedCategory,
        targetMuscles: targetMuscles,
        reps: reps,
        notes: _notesController.text.trim(),
        beginnerWeight: weight,
        videoLink: _videoLinkController.text.trim(),
        alwaysInclude: _alwaysInclude,
        neverInclude: _neverInclude,
      );

      // If name changed, delete old entry first
      if (newName != widget.exerciseName!) {
        await WorkoutPreferencesService.removeUserCustomExercise(widget.exerciseName!);
      }

      await WorkoutPreferencesService.updateUserCustomExercise(updated);
      if (!mounted) return;
      widget.onSave(updated);
      Navigator.pop(context);
    } else {
      // Editing default exercise - save as preference
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
        // All values match defaults, remove custom preference
        await WorkoutPreferencesService.removeCustomExercisePreference(widget.exerciseName!);
      } else {
        // Save as CustomExercisePreference
        final pref = CustomExercisePreference(
          exerciseName: widget.exerciseName!,
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

      // Create a UserCustomExercise object for the callback (even though it's stored as preference)
      final exercise = UserCustomExercise(
        name: widget.exerciseName!,
        category: _selectedCategory,
        targetMuscles: targetMuscles,
        reps: reps,
        beginnerWeight: weight,
        notes: _notesController.text.trim(),
        videoLink: _videoLinkController.text.trim(),
        alwaysInclude: _alwaysInclude,
        neverInclude: _neverInclude,
      );

      if (!mounted) return;
      widget.onSave(exercise);
      Navigator.pop(context);
    }
  }

  void _reset() {
    // Only for editing default exercises
    if (widget.mode != _ExerciseDialogMode.editDefault) return;

    setState(() {
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
      _targetMusclesController.text = _defaultTargetMuscles.join(', ');
      _alwaysInclude = false;
      _neverInclude = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Card(
          color: primaryColor,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: secondaryColor)),
          ),
        ),
      );
    }

    final selectedInclusionMode = _alwaysInclude ? 'always' : (_neverInclude ? 'never' : 'random');
    final isAddMode = widget.mode == _ExerciseDialogMode.addCustom;
    final isEditCustom = widget.mode == _ExerciseDialogMode.editCustom;
    final isEditDefault = widget.mode == _ExerciseDialogMode.editDefault;

    final String title = isAddMode
        ? 'Add Custom Exercise'
        : (isEditCustom ? 'Edit Custom Exercise' : widget.exerciseName!);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Card(
        color: primaryColor,
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyles.titleText.copyWith(color: secondaryColor)),
                SizedBox(height: 16),

                // Exercise name (editable for custom exercises only)
                if (isAddMode || isEditCustom) ...[
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: secondaryColor),
                    cursorColor: secondaryColor,
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
                  ),
                  SizedBox(height: 12),

                  // Category dropdown (only for custom exercises)
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
                    items: ExerciseCategory.values.map((category) {
                      return DropdownMenuItem<ExerciseCategory>(
                        value: category,
                        child: Text(exerciseCategoryToString(category)),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                  ),
                  SizedBox(height: 12),

                  // Target muscles (under muscle group for custom exercises)
                  TextFormField(
                    controller: _targetMusclesController,
                    style: TextStyle(color: secondaryColor),
                    cursorColor: secondaryColor,
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
                ],

                // Starting weight
                TextFormField(
                  controller: _weightController,
                  style: TextStyle(color: secondaryColor),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  cursorColor: secondaryColor,
                  decoration: InputDecoration(
                    labelText: 'Starting Weight (lbs)',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: isEditDefault ? 'Default: $_defaultWeight lbs' : 'e.g., 25',
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
                        cursorColor: secondaryColor,
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
                        cursorColor: secondaryColor,
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
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Include in Workouts (moved after rep range)
                Text(
                  'Include in Workouts',
                  style: TextStyle(color: secondaryColor.withValues(alpha: 0.7), fontSize: 16),
                ),
                RadioListTile<String>(
                  title: Text('Random (default)', style: TextStyle(color: secondaryColor)),
                  value: 'random',
                  groupValue: selectedInclusionMode,
                  onChanged: (value) => setState(() {
                    _alwaysInclude = false;
                    _neverInclude = false;
                  }),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity(horizontal: 0, vertical: -4),
                  activeColor: secondaryColor,
                  fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return secondaryColor;
                    }
                    return secondaryColor.withValues(alpha: 0.5);
                  }),
                ),
                RadioListTile<String>(
                  title: Text('Always include', style: TextStyle(color: secondaryColor)),
                  value: 'always',
                  groupValue: selectedInclusionMode,
                  onChanged: (value) => setState(() {
                    _alwaysInclude = true;
                    _neverInclude = false;
                  }),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity(horizontal: 0, vertical: -4),
                  activeColor: secondaryColor,
                  fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return secondaryColor;
                    }
                    return secondaryColor.withValues(alpha: 0.5);
                  }),
                ),
                RadioListTile<String>(
                  title: Text('Never include', style: TextStyle(color: secondaryColor)),
                  value: 'never',
                  groupValue: selectedInclusionMode,
                  onChanged: (value) => setState(() {
                    _alwaysInclude = false;
                    _neverInclude = true;
                  }),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity(horizontal: 0, vertical: -4),
                  activeColor: secondaryColor,
                  fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return secondaryColor;
                    }
                    return secondaryColor.withValues(alpha: 0.5);
                  }),
                ),
                SizedBox(height: 12),

                // Form notes
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: secondaryColor),
                  maxLines: 2,
                  cursorColor: secondaryColor,
                  decoration: InputDecoration(
                    labelText: 'Form Notes (optional)',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: isEditDefault && _defaultNotes.isNotEmpty
                        ? 'Default: $_defaultNotes'
                        : 'Add form cues or tips...',
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

                // Video URL
                TextFormField(
                  controller: _videoLinkController,
                  style: TextStyle(color: secondaryColor),
                  cursorColor: secondaryColor,
                  decoration: InputDecoration(
                    labelText: 'Video URL (optional)',
                    labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                    hintText: isEditDefault && _defaultVideoLink.isNotEmpty
                        ? 'Default: $_defaultVideoLink'
                        : 'Add a video link',
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

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.onDelete != null) ...[
                      OutlinedButton(
                        onPressed: () {
                          widget.onDelete!();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ActionColors.delete,
                          side: BorderSide(color: ActionColors.delete),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text('Delete', style: TextStyle(fontSize: 16)),
                      ),
                      SizedBox(width: 10),
                    ],
                    if (isEditDefault) ...[
                      OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: secondaryColor,
                          side: BorderSide(color: secondaryColor),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text('Reset', style: TextStyle(fontSize: 16)),
                      ),
                      SizedBox(width: 10),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: secondaryColor,
                        side: BorderSide(color: secondaryColor),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text('Cancel', style: TextStyle(fontSize: 16)),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        isAddMode ? 'Add Exercise' : 'Save',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog for adding new activities
class _AddActivityDialog extends StatefulWidget {
  final Function(UserActivity) onSave;

  const _AddActivityDialog({
    required this.onSave,
  });

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newActivity = UserActivity(
        name: _nameController.text.trim(),
        usualDurationMinutes: int.parse(_durationController.text),
      );
      widget.onSave(newActivity);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Activity'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Name', style: TextStyles.labelText),
            SizedBox(height: 4),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., Kayaking, Cycling',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an activity name';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Text('Usual Duration (minutes)', style: TextStyles.labelText),
            SizedBox(height: 4),
            TextFormField(
              controller: _durationController,
              decoration: InputDecoration(
                hintText: 'e.g., 45',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter duration';
                }
                final duration = int.tryParse(value);
                if (duration == null || duration <= 0) {
                  return 'Please enter a valid duration';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text('Add'),
        ),
      ],
    );
  }
}

// Dialog for editing saved activities
class _EditActivityDialog extends StatefulWidget {
  final UserActivity activity;
  final Function(UserActivity) onSave;
  final VoidCallback onDelete;

  const _EditActivityDialog({
    required this.activity,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<_EditActivityDialog> {
  late TextEditingController _nameController;
  late TextEditingController _durationController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activity.name);
    _durationController = TextEditingController(text: widget.activity.usualDurationMinutes.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final updatedActivity = UserActivity(
        name: _nameController.text.trim(),
        usualDurationMinutes: int.parse(_durationController.text),
      );
      widget.onSave(updatedActivity);
      Navigator.of(context).pop();
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Activity'),
        content: Text('Are you sure you want to delete "${widget.activity.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close confirmation dialog
              widget.onDelete();
              Navigator.of(context).pop(); // Close edit dialog
            },
            style: FilledButton.styleFrom(backgroundColor: ActionColors.delete),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Activity'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Name', style: TextStyles.labelText),
            SizedBox(height: 4),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., Kayaking, Cycling',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an activity name';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            Text('Usual Duration (minutes)', style: TextStyles.labelText),
            SizedBox(height: 4),
            TextFormField(
              controller: _durationController,
              decoration: InputDecoration(
                hintText: 'e.g., 45',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter duration';
                }
                final duration = int.tryParse(value);
                if (duration == null || duration <= 0) {
                  return 'Please enter a valid duration';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _confirmDelete,
          style: TextButton.styleFrom(foregroundColor: ActionColors.delete),
          child: Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text('Save'),
        ),
      ],
    );
  }
}
