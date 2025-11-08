import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/constants.dart';
import '../data/models/exercise_model.dart';
import '../data/models/core_exercise_model.dart';
import '../data/models/activity_model.dart';
import '../data/services/localdb_service.dart';
import '../data/services/workout_generator.dart';
import '../data/services/core_workout_generator.dart';
import '../data/services/activity_preferences_service.dart';
import '../data/widgets/exercise_card_widget.dart';
import '../data/widgets/core_workout_card_widget.dart';
import '../data/widgets/activity_card_widget.dart';
import '../data/widgets/add_exercise_card_widget.dart';
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
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      // Save current workout to cache and database before switching
      if (currentWorkout != null && selectedTarget != null) {
        cachedWorkouts[selectedTarget!] = currentWorkout!;
        LocalDB.saveIncompleteWorkout(currentWorkout!);
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

    final routine = await LocalDB.getRoutineForDate(today);
    final coreRoutine = await LocalDB.getCoreRoutineForDate(today);
    final yesterdayCoreRoutine = await LocalDB.getCoreRoutineForDate(yesterday);
    final activityRoutine = await LocalDB.getActivitiesForDate(today);
    final activityNames = await ActivityPreferencesService.getActivityNames();
    final incompleteWorkouts = await LocalDB.getIncompleteWorkouts(today);

    // Load incomplete workouts into cache
    cachedWorkouts = incompleteWorkouts;

    // Load completed workouts and set default selection to Upper Body
    if (routine != null) {
      // Group exercises by their muscle group
      for (var exercise in routine.exercises) {
        if (!completedWorkoutsToday.containsKey(exercise.muscleGroup)) {
          completedWorkoutsToday[exercise.muscleGroup] = [];
        }
        completedWorkoutsToday[exercise.muscleGroup]!.add(exercise);
      }
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

    // Default to Upper Body selection
    setState(() {
      selectedTarget = MuscleGroup.upperBody;
    });

    // Generate Upper Body workout if not completed
    if (!completedWorkoutsToday.containsKey(MuscleGroup.upperBody)) {
      _generateWorkout(MuscleGroup.upperBody);
    }
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

  void _updateExercise(Exercise updated) {
    // Store exercise updates by name
    exerciseUpdates[updated.name] = updated;
  }

  void _skipExercise(Exercise exercise) {
    setState(() {
      final skipped = exercise.copyWith(isSkipped: true);
      exerciseUpdates[exercise.name] = skipped;
    });
  }

  void _restoreExercise(Exercise exercise) {
    setState(() {
      final restored = exercise.copyWith(isSkipped: false);
      exerciseUpdates[exercise.name] = restored;
    });
  }

  Future<void> _completeWorkout() async {
    if (currentWorkout == null) return;

    // Apply all exercise updates to the workout
    final updatedExercises = currentWorkout!.exercises.map((ex) {
      return exerciseUpdates[ex.name] ?? ex;
    }).toList();

    final finalWorkout = WorkoutRoutine(
      targetArea: currentWorkout!.targetArea,
      exercises: updatedExercises,
    );

    try {
      await LocalDB.insertWorkout(finalWorkout);
      // Delete from incomplete workouts
      await LocalDB.deleteIncompleteWorkout(today, currentWorkout!.targetArea);
      _showSnackbar('Workout saved! Great job!');

      // Mark this target as completed today
      setState(() {
        completedWorkoutsToday[currentWorkout!.targetArea] = updatedExercises;
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
      debugPrint('Activity saved to Hive: ${activity.name}');
    } catch (e) {
      // Activity still logged to daily workout, just not saved for autocomplete
      debugPrint('Error saving activity to Hive: $e');
    }
  }

  void _removeActivity(int index) {
    setState(() {
      currentActivities.removeAt(index);
    });
  }

  Future<void> _completeActivities() async {
    if (currentActivities.isEmpty) {
      _showSnackbar('Please add at least one activity');
      return;
    }

    final activityRoutine = ActivityRoutine(activities: currentActivities);

    try {
      await LocalDB.insertActivities(activityRoutine);
      _showSnackbar('Activities saved! Great job!');

      setState(() {
        isActivityCompleted = true;
        completedActivitiesToday = activityRoutine;
        currentActivities = [];
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

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      _showSnackbar('No video link available');
      return;
    }

    final Uri parsedUrl = Uri.parse(url);

    if (!await launchUrl(parsedUrl, mode: LaunchMode.externalApplication)) {
      _showSnackbar('Could not open video link');
    }
  }

  void _showSnackbar(String message) {
    showSnackbar(context, message, duration: const Duration(milliseconds: 800));
  }


  Widget _buildWorkoutView() {
    // Check if selected target has been completed
    if (selectedTarget != null && completedWorkoutsToday.containsKey(selectedTarget!)) {
      final completedExercises = completedWorkoutsToday[selectedTarget!]!;
      final targetName = muscleGroupToString(selectedTarget!);

      return Column(
        children: [
          // Completion message
          buildCompletionMessage(
            title: '$targetName completed!',
            onUndo: () => _undoCompletion(selectedTarget!),
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
              itemCount: completedExercises.length,
              itemBuilder: (context, index) {
                final exercise = completedExercises[index];
                return ExerciseCard(
                  exercise: exercise,
                  onUpdate: (_) {}, // Read-only, no updates allowed
                  onLaunchVideo: () => _launchUrl(exercise.videoLink),
                  isReadOnly: true,
                );
              },
            ),
          ),
        ],
      );
    }

    // Show current workout in progress
    if (currentWorkout == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // Exercise list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: currentWorkout!.exercises.length + 1, // +1 for add button/card at end
            itemBuilder: (context, index) {
              // Show exercises first
              if (index < currentWorkout!.exercises.length) {
                final exercise = currentWorkout!.exercises[index];
                // Use updated exercise if available
                final displayExercise = exerciseUpdates[exercise.name] ?? exercise;

                return ExerciseCard(
                  exercise: displayExercise,
                  onUpdate: _updateExercise,
                  onLaunchVideo: () => _launchUrl(exercise.videoLink),
                  onSkip: () => _skipExercise(displayExercise),
                  onRestore: () => _restoreExercise(displayExercise),
                );
              }

              // Show either + button or add exercise card at the end
              if (_showAddExerciseCard) {
                return AddExerciseCard(
                  muscleGroup: selectedTarget!,
                  currentExercises: currentWorkout!.exercises,
                  onAdd: (exercise) {
                    setState(() {
                      if (currentWorkout != null) {
                        // Check if exercise already exists
                        final isDuplicate = currentWorkout!.exercises.any((e) => e.name == exercise.name);

                        if (isDuplicate) {
                          _showSnackbar('Exercise already in workout');
                          return;
                        }

                        // Add exercise to current workout
                        currentWorkout = WorkoutRoutine(
                          targetArea: currentWorkout!.targetArea,
                          exercises: [...currentWorkout!.exercises, exercise],
                        );
                        // Initialize tracking for new exercise
                        exerciseUpdates[exercise.name] = exercise;

                        // Save incomplete workout to database
                        LocalDB.saveIncompleteWorkout(currentWorkout!);

                        _showSnackbar('Exercise added to workout');

                        // Hide the add card after adding
                        _showAddExerciseCard = false;
                      }
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
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
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
        if (!_showAddExerciseCard)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: ElevatedButton(
                onPressed: _completeWorkout,
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
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Today's workout section
            if (isCoreCompleted && completedCoreWorkoutToday != null) ...[
              // Completion message
              buildCompletionMessage(
                title: 'Core workout completed!',
                onUndo: _undoCoreCompletion,
                margin: const EdgeInsets.only(bottom: 16),
              ),
              Text(
                'Today: ${completedCoreWorkoutToday!.exercisesPerSet} exercises × ${completedCoreWorkoutToday!.sets} sets',
                style: TextStyles.titleText,
                textAlign: TextAlign.center,
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
              Text(
                'Today: ${currentCoreWorkout!.exercisesPerSet} exercises × ${currentCoreWorkout!.sets} sets',
                style: TextStyles.titleText,
                textAlign: TextAlign.center,
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
                Text(
                  'Yesterday: ${completedCoreWorkoutYesterday!.exercisesPerSet} exercises × ${completedCoreWorkoutYesterday!.sets} sets',
                  style: TextStyles.titleText,
                  textAlign: TextAlign.center,
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
                Text(
                  'Yesterday: ${yesterdayCoreWorkout!.exercisesPerSet} exercises × ${yesterdayCoreWorkout!.sets} sets',
                  style: TextStyles.titleText,
                  textAlign: TextAlign.center,
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Input widget
                ActivityInputWidget(
                  onAdd: _addActivity,
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
                        onDelete: () => _removeActivity(index),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // Complete button - always at bottom
        if (currentActivities.isNotEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: ElevatedButton(
                onPressed: _completeActivities,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Complete Activities',
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
          _buildWorkoutPage(muscleGroupToString(MuscleGroup.upperBody)),
          // Lower Body Tab
          _buildWorkoutPage(muscleGroupToString(MuscleGroup.lowerBody)),
          // Core Tab
          _buildCoreWorkoutPage(),
          // Other Activities Tab
          _buildActivityPage(),
          // History Tab
          HistoryScreen(key: _historyKey),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Upper',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Lower',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.accessibility_new),
            label: 'Core',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bike),
            label: 'Activities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutPage(String title) {
    return _WorkoutPageWidget(
      title: title,
      isLoading: isLoading,
      workoutView: _buildWorkoutView(),
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
