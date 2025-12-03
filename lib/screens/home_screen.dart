import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/constants.dart';
import '../data/models/exercise_model.dart';
import '../data/models/core_exercise_model.dart';
import '../data/models/activity_model.dart';
import '../data/models/activity_attachment.dart';
import '../data/services/localdb_service.dart';
import '../data/services/workout_generator.dart';
import '../data/services/core_workout_generator.dart';
import '../data/services/activity_preferences_service.dart';
import '../data/services/attachment_service.dart';
import '../data/widgets/exercise_card_widget.dart';
import '../data/widgets/core_workout_card_widget.dart';
import '../data/widgets/activity_card_widget.dart';
import '../data/widgets/add_exercise_card_widget.dart';
import '../data/widgets/inline_youtube_player.dart';
import '../data/widgets/attachment_options_dialog.dart';
import '../utils/ui_helpers.dart';
import 'history_screen.dart';
import 'workout_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WorkoutRoutine? currentWorkout;
  CoreWorkoutRoutine? currentCoreWorkout;
  CoreWorkoutRoutine? yesterdayCoreWorkout;
  MuscleGroup? selectedTarget;
  bool isLoading = false;
  bool isCoreCompleted = false;
  bool isYesterdayCoreCompleted = false;
  bool isActivityCompleted = false;
  bool _showActivityReminder = false;
  bool _isActivityFormActive = false;
  final GlobalKey _activityFormKey = GlobalKey();
  String? _currentCoreVideoUrl; // Track currently playing core video
  String? _currentExerciseVideoUrl; // Track currently playing exercise video
  String? _currentExerciseVideoName; // Track which exercise's video is playing
  final Map<MuscleGroup, ScrollController> _scrollControllers = {
    MuscleGroup.upperBody: ScrollController(),
    MuscleGroup.lowerBody: ScrollController(),
  };
  final Map<String, GlobalKey> _exerciseKeys = {}; // Keys for exercises
  CoreWorkoutRoutine? completedCoreWorkoutToday;
  CoreWorkoutRoutine? completedCoreWorkoutYesterday;
  ActivityRoutine? completedActivitiesToday;
  List<Activity> currentActivities = [];
  List<String> previousActivityNames = [];
  DateTime today = DateTime.now();
  DateTime yesterday = DateTime.now().subtract(Duration(days: 1));
  Map<String, Exercise> exerciseUpdates = {}; // Track exercise updates by name
  Map<MuscleGroup, List<Exercise>> completedWorkoutsToday = {}; // Track completed workouts with exercises
  Map<MuscleGroup, WorkoutRoutine> cachedWorkouts = {}; // Cache in-progress workouts by muscle group
  bool _showAddExerciseCard = false; // Track if add exercise card is visible

  late PageController _pageController;
  int _currentIndex = 0;
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadTodaysWorkout();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      // Save current workout to cache and database before switching
      if (selectedTarget != null) {
        final workoutToSave = _saveIncompleteWorkoutProgress();
        if (workoutToSave != null) {
          cachedWorkouts[selectedTarget!] = workoutToSave;
        }
      }

      _currentIndex = index;
      if (index == 0 || index == 1) { // Upper Body (0) or Lower Body (1)
        selectedTarget = index == 0 ? MuscleGroup.upperBody : MuscleGroup.lowerBody;

        // Check if workout is already completed for this target
        if (completedWorkoutsToday.containsKey(selectedTarget!)) {
          currentWorkout = null;
        }
        // Check if we have a cached workout for this target
        else if (cachedWorkouts.containsKey(selectedTarget!)) {
          currentWorkout = cachedWorkouts[selectedTarget!];
        }
        // Otherwise generate a new workout
        else {
          _generateWorkout(selectedTarget!);
        }
      } else if (index == 2) { // Core tab
        if (currentCoreWorkout == null && !isCoreCompleted) {
          _generateCoreWorkout();
        }
      } else if (index == 4) { // History tab
        // Refresh history when switching to it
        _historyKey.currentState?.refreshData();
      }
    });
  }

  void _onItemTapped(int index) {
    _pageController.jumpToPage(index); // Instant jump, no animation
  }

  Future<void> _loadTodaysWorkout() async {
    // Clear old incomplete workouts from previous days
    await LocalDB.clearOldIncompleteWorkouts();

    // Clear all state before reloading to ensure fresh data
    setState(() {
      completedWorkoutsToday.clear();
      cachedWorkouts.clear();
      currentWorkout = null;
      exerciseUpdates.clear();
      isCoreCompleted = false;
      isYesterdayCoreCompleted = false;
      isActivityCompleted = false;
      completedCoreWorkoutToday = null;
      completedCoreWorkoutYesterday = null;
      completedActivitiesToday = null;
    });

    final routine = await LocalDB.getRoutineForDate(today);
    final coreRoutine = await LocalDB.getCoreRoutineForDate(today);
    final yesterdayCoreRoutine = await LocalDB.getCoreRoutineForDate(yesterday);
    final activityRoutine = await LocalDB.getActivitiesForDate(today);
    final activityNames = await ActivityPreferencesService.getActivityNames();
    final incompleteWorkouts = await LocalDB.getIncompleteWorkouts(today);
    final incompleteActivities = await LocalDB.getIncompleteActivities(today);

    // Load incomplete workouts into cache and restore exercise updates
    cachedWorkouts = incompleteWorkouts;

    // Populate exerciseUpdates from incomplete workouts to restore progress
    for (var workout in incompleteWorkouts.values) {
      for (var exercise in workout.exercises) {
        exerciseUpdates[exercise.name] = exercise;
      }
    }

    // Load completed workouts and set default selection to Upper Body
    if (routine != null) {
      setState(() {
        // Group exercises by their muscle group
        for (var exercise in routine.exercises) {
          if (!completedWorkoutsToday.containsKey(exercise.muscleGroup)) {
            completedWorkoutsToday[exercise.muscleGroup] = [];
          }
          completedWorkoutsToday[exercise.muscleGroup]!.add(exercise);
        }
      });
    }

    // Load completed core workout for today
    if (coreRoutine != null) {
      setState(() {
        isCoreCompleted = true;
        completedCoreWorkoutToday = coreRoutine;
      });
    }

    // Load completed core workout for yesterday
    if (yesterdayCoreRoutine != null) {
      setState(() {
        isYesterdayCoreCompleted = true;
        completedCoreWorkoutYesterday = yesterdayCoreRoutine;
      });
    } else {
      // Generate yesterday's workout for catchup
      _generateYesterdayCoreWorkout();
    }

    // Load completed activities for today
    if (activityRoutine != null) {
      setState(() {
        isActivityCompleted = true;
        completedActivitiesToday = activityRoutine;
      });
    }

    // Load previous activity names for autocomplete
    setState(() {
      previousActivityNames = activityNames;
    });

    // Load incomplete activities if they exist
    if (incompleteActivities.isNotEmpty && activityRoutine == null) {
      setState(() {
        currentActivities = incompleteActivities;
        _showActivityReminder = true;
      });
    }

    // Initialize Upper Body tab (index 0) - uses same logic as tab switching
    _onPageChanged(0);
  }

  Future<void> _generateWorkout(MuscleGroup target) async {
    setState(() {
      selectedTarget = target;
      _showAddExerciseCard = false; // Hide add card when switching workouts
    });

    // Check if this target has already been completed today
    if (completedWorkoutsToday.containsKey(target)) {
      // Don't generate new workout, just show the completed one
      setState(() {
        currentWorkout = null; // Clear active workout
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final workout = await WorkoutGenerator.generateWorkout(target);

      // Pre-populate exerciseUpdates with all exercises including default completedSets
      exerciseUpdates.clear();
      for (var exercise in workout.exercises) {
        // Parse the low end of rep range for auto-fill (e.g., "8-12" -> 8, "10-12" -> 10)
        final lowEndReps = _getLowEndReps(exercise.reps);
        final defaultCompletedSets = List.generate(numSets, (_) => lowEndReps);

        exerciseUpdates[exercise.name] = exercise.copyWith(
          completedSets: defaultCompletedSets,
        );
      }

      setState(() {
        currentWorkout = workout;
        isLoading = false;
      });

      // Save incomplete workout to database
      await LocalDB.saveIncompleteWorkout(workout);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackbar('Error generating workout: $e');
    }
  }

  // Parse the low end of the rep range (e.g., "8-12" -> 8, "10-15" -> 10)
  int _getLowEndReps(String repsRange) {
    final match = RegExp(r'(\d+)').firstMatch(repsRange);
    return int.tryParse(match?.group(1) ?? '') ?? 8;
  }

  // Save current workout progress with exercise updates applied
  // Returns the workout with updates applied for caching
  WorkoutRoutine? _saveIncompleteWorkoutProgress() {
    if (currentWorkout == null) return null;

    final updatedExercises = currentWorkout!.exercises
      .map((ex) => exerciseUpdates[ex.name] ?? ex)
      .toList();

    final workoutToSave = WorkoutRoutine(
      targetArea: currentWorkout!.targetArea,
      exercises: updatedExercises,
    );

    // ignore: unawaited_futures
    LocalDB.saveIncompleteWorkout(workoutToSave);

    return workoutToSave;
  }

  void _updateExercise(Exercise updated) {
    // Store exercise updates by name
    exerciseUpdates[updated.name] = updated;

    // Save incomplete workout to preserve progress
    _saveIncompleteWorkoutProgress();
  }

  void _skipExercise(Exercise exercise) {
    setState(() {
      final skipped = exercise.copyWith(isSkipped: true);
      exerciseUpdates[exercise.name] = skipped;
    });

    // Save incomplete workout to preserve skip state
    _saveIncompleteWorkoutProgress();
  }

  void _restoreExercise(Exercise exercise) {
    setState(() {
      final restored = exercise.copyWith(isSkipped: false);
      exerciseUpdates[exercise.name] = restored;
    });

    // Save incomplete workout to preserve restore state
    _saveIncompleteWorkoutProgress();
  }

  Future<void> _completeWorkout() async {
    if (currentWorkout == null) return;

    // Apply all exercise updates to the workout
    final updatedExercises = currentWorkout!.exercises
      .map((ex) => exerciseUpdates[ex.name] ?? ex)
      .toList();

    // Check if any exercises were completed (UI validation before calling service)
    final completedExercises = updatedExercises
      .where((ex) => isExerciseCompleted(ex))
      .toList();

    if (completedExercises.isEmpty) {
      _showSnackbar('No exercises completed. Please complete at least one exercise.');
      return;
    }

    final finalWorkout = WorkoutRoutine(
      targetArea: currentWorkout!.targetArea,
      exercises: updatedExercises, // Pass all exercises; service will filter
    );

    try {
      await LocalDB.insertWorkout(finalWorkout);
      // Delete from incomplete workouts
      await LocalDB.deleteIncompleteWorkout(today, currentWorkout!.targetArea);
      _showSnackbar('Workout saved! Great job!');

      // Mark this target as completed today (only completed exercises)
      setState(() {
        completedWorkoutsToday[currentWorkout!.targetArea] = completedExercises;
        cachedWorkouts.remove(currentWorkout!.targetArea); // Clear from cache
        currentWorkout = null;
        exerciseUpdates.clear();
      });
    } catch (e) {
      _showSnackbar('Error saving workout: $e');
    }
  }

  Future<void> _undoCompletion(MuscleGroup targetArea) async {
    try {
      // Remove the workout from the database
      await LocalDB.removeWorkoutByMuscleGroup(DateTime.now(), targetArea);

      // Get the completed exercises to restore them
      final completedExercises = completedWorkoutsToday[targetArea];

      if (completedExercises != null) {
        // Recreate the workout routine
        final restoredWorkout = WorkoutRoutine(
          targetArea: targetArea,
          exercises: completedExercises,
        );

        // Restore exercise updates
        for (var exercise in completedExercises) {
          exerciseUpdates[exercise.name] = exercise;
        }

        setState(() {
          currentWorkout = restoredWorkout;
          cachedWorkouts[targetArea] = restoredWorkout; // Add back to cache
          completedWorkoutsToday.remove(targetArea);
        });

        // Save back to incomplete workouts
        await LocalDB.saveIncompleteWorkout(restoredWorkout);

        _showSnackbar('Workout completion undone');
      }
    } catch (e) {
      _showSnackbar('Error undoing workout: $e');
    }
  }

  // Core workout methods
  Future<void> _generateCoreWorkout() async {
    setState(() {
      isLoading = true;
    });

    try {
      final todaySeed = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
      final workout = CoreWorkoutGenerator.generateDailyCoreRoutine(todaySeed);

      setState(() {
        currentCoreWorkout = workout;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackbar('Error generating core workout: $e');
    }
  }

  void _generateYesterdayCoreWorkout() {
    final yesterdaySeed = DateTime(yesterday.year, yesterday.month, yesterday.day).millisecondsSinceEpoch;
    setState(() {
      yesterdayCoreWorkout = CoreWorkoutGenerator.generateDailyCoreRoutine(yesterdaySeed);
    });
  }

  Future<void> _completeCoreWorkout() async {
    if (currentCoreWorkout == null) return;

    try {
      await LocalDB.insertCoreWorkout(currentCoreWorkout!);
      _showSnackbar('Core workout saved! Great job!');

      setState(() {
        completedCoreWorkoutToday = currentCoreWorkout;
        isCoreCompleted = true;
        currentCoreWorkout = null;
      });
    } catch (e) {
      _showSnackbar('Error saving core workout: $e');
    }
  }

  Future<void> _undoCoreCompletion() async {
    try {
      await LocalDB.removeCoreWorkout(today);

      setState(() {
        currentCoreWorkout = completedCoreWorkoutToday;
        isCoreCompleted = false;
        completedCoreWorkoutToday = null;
      });

      _showSnackbar('Core workout completion undone');
    } catch (e) {
      _showSnackbar('Error undoing core workout: $e');
    }
  }

  Future<void> _completeYesterdayCoreWorkout() async {
    if (yesterdayCoreWorkout == null) return;

    try {
      final yesterdayDate = yesterday.toIso8601String().substring(0, 10);
      await LocalDB.insertCoreWorkout(yesterdayCoreWorkout!, yesterdayDate);
      _showSnackbar('Yesterday\'s core workout saved! Great job!');

      setState(() {
        completedCoreWorkoutYesterday = yesterdayCoreWorkout;
        isYesterdayCoreCompleted = true;
        yesterdayCoreWorkout = null;
      });
    } catch (e) {
      _showSnackbar('Error saving yesterday\'s core workout: $e');
    }
  }

  Future<void> _undoYesterdayCoreCompletion() async {
    try {
      await LocalDB.removeCoreWorkout(yesterday);

      setState(() {
        yesterdayCoreWorkout = completedCoreWorkoutYesterday;
        isYesterdayCoreCompleted = false;
        completedCoreWorkoutYesterday = null;
      });

      _showSnackbar('Yesterday\'s core workout completion undone');
    } catch (e) {
      _showSnackbar('Error undoing yesterday\'s core workout: $e');
    }
  }

  // Activity methods
  void _addActivity(Activity activity) async {
    setState(() {
      currentActivities.add(activity);
      _showActivityReminder = true;
      _isActivityFormActive = false;
      // Add to previous names if not already there
      if (!previousActivityNames.contains(activity.name)) {
        previousActivityNames.add(activity.name);
        previousActivityNames.sort();
      }
    });

    // Auto-save to Hive for future autocomplete and duration pre-fill
    try {
      await ActivityPreferencesService.saveOrUpdateActivity(
        activity.name,
        activity.durationMinutes,
      );
    } catch (e) {
      // Activity still logged to daily workout, just not saved for autocomplete
    }

    // Auto-save incomplete activities to database
    await LocalDB.saveIncompleteActivities(currentActivities);
  }

  void _removeActivity(int index) async {
    final activityToRemove = currentActivities[index];

    setState(() {
      currentActivities.removeAt(index);
      if (currentActivities.isEmpty) {
        _showActivityReminder = false;
      }
    });

    // Check if this activity exists anywhere in the workout history
    final existsInHistory = await _activityExistsInHistory(activityToRemove.name);

    // If it doesn't exist in history, remove from autocomplete
    if (!existsInHistory) {
      await ActivityPreferencesService.deleteActivity(activityToRemove.name);
    }

    // Auto-save incomplete activities to database
    await LocalDB.saveIncompleteActivities(currentActivities);
  }

  Future<void> _editActivity(int index) async {
    final activity = currentActivities[index];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditActivityDialog(activity: activity),
    );

    if (result != null) {
      setState(() {
        currentActivities[index] = activity.copyWith(
          durationMinutes: result['duration'] as int,
          notes: (result['notes'] as String).isEmpty ? null : result['notes'] as String,
          attachments: result['attachments'] as List<ActivityAttachment>?,
        );
      });

      // Auto-save incomplete activities to database
      await LocalDB.saveIncompleteActivities(currentActivities);
    }
  }

  Future<bool> _activityExistsInHistory(String activityName) async {
    final db = await LocalDB.database;
    final logs = await db.query('workout_logs');

    for (var log in logs) {
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      for (var item in exercisesJson) {
        if (item is Map && item['isActivity'] == true) {
          final activities = (item['activities'] as List);
          for (var activity in activities) {
            if (activity['name'] == activityName) {
              return true; // Found in history
            }
          }
        }
      }
    }

    return false; // Not found in history
  }

  Future<void> _completeActivities() async {
    if (currentActivities.isEmpty) {
      _showSnackbar('Please add at least one activity');
      return;
    }

    final activityRoutine = ActivityRoutine(activities: currentActivities);

    try {
      await LocalDB.insertActivities(activityRoutine);

      // Delete incomplete activities from database since they're now completed
      await LocalDB.deleteIncompleteActivities(today);

      _showSnackbar('Activities saved! Great job!');

      setState(() {
        isActivityCompleted = true;
        completedActivitiesToday = activityRoutine;
        currentActivities = [];
        _showActivityReminder = false;
      });
    } catch (e) {
      _showSnackbar('Error saving activities: $e');
    }
  }

  Future<void> _undoActivityCompletion() async {
    try {
      await LocalDB.removeActivities(today);

      setState(() {
        currentActivities = completedActivitiesToday?.activities ?? [];
        isActivityCompleted = false;
        completedActivitiesToday = null;
      });

      _showSnackbar('Activity completion undone');
    } catch (e) {
      _showSnackbar('Error undoing activities: $e');
    }
  }

  Future<void> _handleCompletedActivityAttachmentChanges(Activity activity, List<ActivityAttachment> newAttachments) async {
    try {
      // Get current activities from database
      final activityRoutine = await LocalDB.getActivitiesForDate(today);
      if (activityRoutine == null) return;

      // Find and update the specific activity
      final updatedActivities = activityRoutine.activities.map((a) {
        if (a.completedAt == activity.completedAt) {
          return a.replaceAttachments(newAttachments.isEmpty ? null : newAttachments);
        }
        return a;
      }).toList();

      // Save to database
      await LocalDB.updateWorkoutsForDate(
        date: today.toIso8601String().substring(0, 10),
        originalMuscleGroups: {},
        newWorkoutsByGroup: {},
        originalHadCore: false,
        newCoreWorkout: null,
        originalHadActivities: true,
        newActivities: updatedActivities,
      );

      // Reload completed activities to show changes
      final refreshedRoutine = await LocalDB.getActivitiesForDate(today);
      setState(() {
        completedActivitiesToday = refreshedRoutine;
      });
    } catch (e) {
      _showSnackbar('Error updating attachments: $e');
    }
  }

  /// Launch URL externally (for search links) or inline (for direct video links)
  Future<void> _launchUrlExternal(String url, String exerciseName) async {
    if (url.isEmpty) {
      _showSnackbar('No video link available');
      return;
    }

    // If URL contains "results", it's a search link - open externally
    if (url.contains('results')) {
      final Uri parsedUrl = Uri.parse(url);
      if (!await launchUrl(parsedUrl, mode: LaunchMode.externalApplication)) {
        _showSnackbar('Could not open video link');
      }
    } else {
      // Direct video link - play inline
      setState(() {
        _currentExerciseVideoUrl = url;
        _currentExerciseVideoName = exerciseName;
      });

      // Scroll to the exercise after a brief delay to let the video render
      Future.delayed(Duration(milliseconds: 300), () {
        final exerciseKeyId = '${selectedTarget?.toString()}_$exerciseName';
        final key = _exerciseKeys[exerciseKeyId];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: 0.0, // Scroll to top of viewport
          );
        }
      });
    }
  }

  /// Launch URL with inline video player (for core exercises with direct video links)
  void _launchUrl(String url) {
    if (url.isEmpty) {
      _showSnackbar('No video link available');
      return;
    }

    setState(() {
      _currentCoreVideoUrl = url;
    });
  }

  void _showSnackbar(String message) {
    showSnackbar(context, message);
  }


  Widget _buildWorkoutView(MuscleGroup target) {
    // Check if selected target has been completed
    if (completedWorkoutsToday.containsKey(target)) {
      final completedExercises = completedWorkoutsToday[target]!;
      final targetName = muscleGroupToString(target);

      return Column(
        children: [
          // Completion message
          buildCompletionMessage(
            title: '$targetName completed!',
            onUndo: () => _undoCompletion(target),
          ),

          // Completed workout exercises
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Completed Workout:',
              style: TextStyles.titleText,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(top: 8),
              itemCount: completedExercises.length,
              itemBuilder: (context, index) {
                final exercise = completedExercises[index];
                return ExerciseCard(
                  exercise: exercise,
                  onUpdate: (_) {}, // Read-only, no updates allowed
                  onLaunchVideo: () => _launchUrlExternal(exercise.videoLink, exercise.name),
                  isReadOnly: true,
                );
              },
            ),
          ),
        ],
      );
    }

    // Show current workout in progress - get the appropriate workout for this target
    final WorkoutRoutine? workout = selectedTarget == target ? currentWorkout : cachedWorkouts[target];

    if (workout == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // Exercise list
        Expanded(
          child: ListView.builder(
            controller: _scrollControllers[target],
            padding: EdgeInsets.only(top: 8),
            itemCount: workout.exercises.length + 1, // +1 for add button/card at end
            itemBuilder: (context, index) {
              // Show exercises first
              if (index < workout.exercises.length) {
                final exercise = workout.exercises[index];
                // Use updated exercise if available
                final displayExercise = exerciseUpdates[exercise.name] ?? exercise;

                // Create GlobalKey for scrolling with page-specific prefix to avoid duplicates during transitions
                // Use the target parameter (not selectedTarget state) to ensure stable keys during transitions
                final exerciseKeyId = '${target.toString()}_${exercise.name}';
                final exerciseKey = _exerciseKeys.putIfAbsent(
                  exerciseKeyId,
                  () => GlobalKey(),
                );

                return Container(
                  key: exerciseKey,
                  child: Column(
                    children: [
                      // Show inline video player above this exercise if it's the current video
                      if (_currentExerciseVideoName == exercise.name && _currentExerciseVideoUrl != null) ...[
                        InlineYouTubePlayer(
                          key: ValueKey(_currentExerciseVideoUrl),
                          videoUrl: _currentExerciseVideoUrl!,
                          onClose: () {
                            setState(() {
                              _currentExerciseVideoUrl = null;
                              _currentExerciseVideoName = null;
                            });
                          },
                        ),
                        SizedBox(height: 16),
                      ],
                      ExerciseCard(
                        exercise: displayExercise,
                        onUpdate: _updateExercise,
                        onLaunchVideo: () => _launchUrlExternal(exercise.videoLink, exercise.name),
                        onSkip: () => _skipExercise(displayExercise),
                        onRestore: () => _restoreExercise(displayExercise),
                      ),
                    ],
                  ),
                );
              }

              // Show either + button or add exercise card at the end
              if (_showAddExerciseCard && selectedTarget == target) {
                return AddExerciseCard(
                  muscleGroup: target,
                  currentExercises: workout.exercises,
                  onAdd: (exercise) {
                    setState(() {
                      // Check if exercise already exists
                      final isDuplicate = workout.exercises.any((e) => e.name == exercise.name);

                      if (isDuplicate) {
                        _showSnackbar('Exercise already in workout');
                        return;
                      }

                      // Add exercise to cached workout
                      final updatedWorkout = WorkoutRoutine(
                        targetArea: workout.targetArea,
                        exercises: [...workout.exercises, exercise],
                      );
                      cachedWorkouts[target] = updatedWorkout;

                      // Update current workout if this is the selected target
                      if (selectedTarget == target) {
                        currentWorkout = updatedWorkout;
                      }

                      // Initialize tracking for new exercise
                      exerciseUpdates[exercise.name] = exercise;

                      // Save incomplete workout to database
                      LocalDB.saveIncompleteWorkout(updatedWorkout);

                      _showSnackbar('Exercise added to workout');

                      // Hide the add card after adding
                      _showAddExerciseCard = false;
                    });
                  },
                  onCancel: () {
                    setState(() {
                      _showAddExerciseCard = false;
                    });
                  },
                );
              } else {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: FloatingActionButton.small(
                      onPressed: () {
                        setState(() {
                          _showAddExerciseCard = true;
                        });
                        // Scroll to bottom to show the add card
                        Future.delayed(Duration(milliseconds: 100), () {
                          final scrollController = _scrollControllers[target];
                          if (scrollController != null && scrollController.hasClients) {
                            scrollController.animateTo(
                              scrollController.position.maxScrollExtent,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      },
                      backgroundColor: primaryColor,
                      shape: CircleBorder(),
                      child: Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                );
              }
            },
          ),
        ),

        // Complete Workout button (hide when add exercise card is visible)
        if (!_showAddExerciseCard && selectedTarget == target)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: ElevatedButton(
                onPressed: () => _completeWorkout(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Complete Workout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoreWorkoutPage() {
    return _WorkoutPageWidget(
      title: muscleGroupToString(MuscleGroup.core),
      isLoading: isLoading,
      workoutView: _buildCoreWorkoutView(),
    );
  }

  Widget _buildCoreWorkoutView() {
    // Show loading if workouts aren't ready
    if (currentCoreWorkout == null && !isCoreCompleted) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // Inline video player at the top
            if (_currentCoreVideoUrl != null) ...[
              InlineYouTubePlayer(
                key: ValueKey(_currentCoreVideoUrl), // Force rebuild when URL changes
                videoUrl: _currentCoreVideoUrl!,
                onClose: () {
                  setState(() {
                    _currentCoreVideoUrl = null;
                  });
                },
              ),
              SizedBox(height: 16),
            ],
            // Today's workout section
            if (isCoreCompleted && completedCoreWorkoutToday != null) ...[
              // Completion message
              buildCompletionMessage(
                title: 'Core completed!',
                onUndo: _undoCoreCompletion,
                margin: const EdgeInsets.only(bottom: 16),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Today: ${completedCoreWorkoutToday!.exercisesPerSet} exercises × ${completedCoreWorkoutToday!.sets} sets',
                  style: TextStyles.titleText,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              buildCoreWorkoutCard(
                context: context,
                routine: completedCoreWorkoutToday!,
                isCompleted: true,
                onToggleComplete: _undoCoreCompletion,
                onLaunchUrl: _launchUrl,
              ),
            ] else if (currentCoreWorkout != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Today: ${currentCoreWorkout!.exercisesPerSet} exercises × ${currentCoreWorkout!.sets} sets',
                  style: TextStyles.titleText,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              buildCoreWorkoutCard(
                context: context,
                routine: currentCoreWorkout!,
                isCompleted: false,
                onToggleComplete: _completeCoreWorkout,
                onLaunchUrl: _launchUrl,
              ),
            ],

            // Yesterday's workout section
            if (yesterdayCoreWorkout != null || completedCoreWorkoutYesterday != null) ...[
              SizedBox(height: 16),
              if (isYesterdayCoreCompleted && completedCoreWorkoutYesterday != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Yesterday: ${completedCoreWorkoutYesterday!.exercisesPerSet} exercises × ${completedCoreWorkoutYesterday!.sets} sets',
                    style: TextStyles.titleText,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
                buildCoreWorkoutCard(
                  context: context,
                  routine: completedCoreWorkoutYesterday!,
                  isCompleted: true,
                  onToggleComplete: _undoYesterdayCoreCompletion,
                  onLaunchUrl: _launchUrl,
                ),
              ] else if (yesterdayCoreWorkout != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Yesterday: ${yesterdayCoreWorkout!.exercisesPerSet} exercises × ${yesterdayCoreWorkout!.sets} sets',
                    style: TextStyles.titleText,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
                buildCoreWorkoutCard(
                  context: context,
                  routine: yesterdayCoreWorkout!,
                  isCompleted: false,
                  onToggleComplete: _completeYesterdayCoreWorkout,
                  onLaunchUrl: _launchUrl,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityPage() {
    return _WorkoutPageWidget(
      title: 'Other Activities',
      isLoading: false,
      workoutView: _buildActivityView(),
      onOpenSettings: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WorkoutSettingsScreen(showActivitiesOnly: true)),
        );
        // Reload activity names after settings change
        final activityNames = await ActivityPreferencesService.getActivityNames();
        setState(() {
          previousActivityNames = activityNames;
        });
      },
    );
  }

  Widget _buildActivityView() {
    // Show completed view
    if (isActivityCompleted && completedActivitiesToday != null) {
      return Column(
        children: [
          // Completion message
          buildCompletionMessage(
            title: 'Activities completed!',
            onUndo: _undoActivityCompletion,
          ),

          // Completed activities list
          Expanded(
            child: ListView.builder(
              itemCount: completedActivitiesToday!.activities.length,
              itemBuilder: (context, index) {
                final activity = completedActivitiesToday!.activities[index];
                return ActivityCard(
                  activity: activity,
                  isReadOnly: true,
                  onAttachmentsChanged: (newAttachments) => _handleCompletedActivityAttachmentChanges(activity, newAttachments),
                );
              },
            ),
          ),
        ],
      );
    }

    // Show input form
    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // Unfocus when tapping outside input fields
              FocusScope.of(context).unfocus();
            },
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Input widget
                  ActivityInputWidget(
                  key: _activityFormKey,
                  onAdd: _addActivity,
                  onFormChanged: (hasInput) {
                    // Defer setState to avoid calling during build
                    Future.microtask(() {
                      if (mounted) {
                        setState(() {
                          _isActivityFormActive = hasInput;
                        });
                      }
                    });
                  },
                  previousActivityNames: previousActivityNames,
                  currentActivities: currentActivities,
                ),

                // Current activities list
                if (currentActivities.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Today\'s Activities:',
                      style: TextStyles.titleText,
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: currentActivities.length,
                    itemBuilder: (context, index) {
                      return ActivityCard(
                        activity: currentActivities[index],
                        onEdit: () => _editActivity(index),
                        onDelete: () => _removeActivity(index),
                        onAttachmentsChanged: (newAttachments) {
                          setState(() {
                            currentActivities[index] = currentActivities[index].replaceAttachments(
                              newAttachments.isEmpty ? null : newAttachments,
                            );
                          });
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
            ),
          ),

        // Reminder banner
        if (_showActivityReminder && currentActivities.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              border: Border.all(color: Colors.amber.shade700, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Don\'t forget to tap "Complete Activities" to save! (Tap outside form if needed)',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Action button - changes based on context
        if (_isActivityFormActive || currentActivities.isNotEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_isActivityFormActive) {
                    // Call form's submit method
                    final state = _activityFormKey.currentState;
                    if (state != null) {
                      (state as dynamic).submitActivity();
                    }
                  } else {
                    _completeActivities();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _isActivityFormActive ? 'Add Activity' : 'Complete Activities',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          // Upper Body Tab
          KeyedSubtree(
            key: ValueKey('upper_body_page'),
            child: _buildWorkoutPage(muscleGroupToString(MuscleGroup.upperBody), MuscleGroup.upperBody),
          ),
          // Lower Body Tab
          KeyedSubtree(
            key: ValueKey('lower_body_page'),
            child: _buildWorkoutPage(muscleGroupToString(MuscleGroup.lowerBody), MuscleGroup.lowerBody),
          ),
          // Core Tab
          KeyedSubtree(
            key: ValueKey('core_page'),
            child: _buildCoreWorkoutPage(),
          ),
          // Other Activities Tab
          KeyedSubtree(
            key: ValueKey('activities_page'),
            child: _buildActivityPage(),
          ),
          // History Tab
          HistoryScreen(
            key: _historyKey,
            onDataImported: _loadTodaysWorkout,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: primaryColor,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: secondaryColor,
        unselectedItemColor: secondaryColor.withValues(alpha: 0.6),
        selectedLabelStyle: TextStyle(
          height: 1.2,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          height: 1.2,
          fontSize: 12,
        ),
        items: [
          // Generate navigation items from workoutTabOrder
          ...workoutTabOrder.map((muscleGroup) {
            final iconMap = {
              MuscleGroup.upperBody: Icons.fitness_center,
              MuscleGroup.lowerBody: Icons.directions_run,
              MuscleGroup.core: Icons.accessibility_new,
              MuscleGroup.otherActivity: Icons.directions_bike,
            };
            return BottomNavigationBarItem(
              icon: Icon(iconMap[muscleGroup]),
              label: muscleGroupShortName(muscleGroup),
            );
          }),
          // History tab
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutPage(String title, MuscleGroup target) {
    return _WorkoutPageWidget(
      title: title,
      isLoading: isLoading,
      workoutView: _buildWorkoutView(target),
      onOpenSettings: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WorkoutSettingsScreen()),
        );
        // Regenerate workout after settings change
        if (selectedTarget != null) {
          // Clear cached workout to force regeneration
          cachedWorkouts.remove(selectedTarget!);
          await LocalDB.deleteIncompleteWorkout(today, selectedTarget!);
          _generateWorkout(selectedTarget!);
        }
      },
    );
  }

}

// Separate widget with AutomaticKeepAliveClientMixin to preserve state
class _WorkoutPageWidget extends StatefulWidget {
  final String title;
  final bool isLoading;
  final Widget workoutView;
  final VoidCallback? onOpenSettings;

  const _WorkoutPageWidget({
    required this.title,
    required this.isLoading,
    required this.workoutView,
    this.onOpenSettings,
  });

  @override
  State<_WorkoutPageWidget> createState() => _WorkoutPageWidgetState();
}

class _WorkoutPageWidgetState extends State<_WorkoutPageWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.onOpenSettings != null)
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: widget.onOpenSettings,
              tooltip: 'Workout Settings',
            ),
        ],
      ),
      body: widget.isLoading
          ? Center(child: CircularProgressIndicator())
          : widget.workoutView,
    );
  }
}

class _EditActivityDialog extends StatefulWidget {
  final Activity activity;

  const _EditActivityDialog({required this.activity});

  @override
  State<_EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<_EditActivityDialog> {
  late final TextEditingController _durationController;
  late final TextEditingController _notesController;
  late final List<ActivityAttachment> _attachments;
  bool _isProcessingAttachment = false;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(text: widget.activity.durationMinutes.toString());
    _notesController = TextEditingController(text: widget.activity.notes ?? '');
    _attachments = List.from(widget.activity.attachments ?? []);
  }

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final keepFullSize = await showAttachmentOptionsDialog(context);
    if (keepFullSize == null) return;

    setState(() => _isProcessingAttachment = true);
    try {
      final attachment = await AttachmentService.pickAttachment(keepFullSize: keepFullSize);
      if (attachment != null && mounted) {
        final attachmentsToAdd = AttachmentService.tryAddAttachment(
          context: context,
          existingAttachments: _attachments,
          newAttachment: attachment,
        );

        if (attachmentsToAdd != null) {
          setState(() {
            _attachments.addAll(attachmentsToAdd);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, 'Error adding attachment: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAttachment = false);
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _save(BuildContext context) {
    final duration = int.tryParse(_durationController.text);
    if (duration != null && duration > 0) {
      Navigator.pop(context, {
        'duration': duration,
        'notes': _notesController.text.trim(),
        'attachments': _attachments.isNotEmpty ? _attachments : null,
      });
    } else {
      showSnackbar(context, 'Please enter a valid duration');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.activity.name, style: TextStyles.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            // Attachments section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attachments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                OutlinedButton.icon(
                  onPressed: _isProcessingAttachment ? null : _pickAttachment,
                  icon: _isProcessingAttachment
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.attach_file, size: 18),
                  label: Text(_isProcessingAttachment ? 'Processing...' : 'Add File'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              SizedBox(height: 8),
              ...List.generate(_attachments.length, (index) {
                final attachment = _attachments[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.white,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            base64Decode(attachment.thumbnailBase64),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // File info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '${AttachmentService.formatFileSize(attachment.originalSizeBytes)}${!attachment.isFullFileInExcel ? ' (thumbnail only)' : ''}',
                              style: TextStyle(
                                color: primaryColor.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Remove button
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: ActionColors.delete),
                        onPressed: () => _removeAttachment(index),
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _save(context),
          child: Text('Save'),
        ),
      ],
    );
  }
}
