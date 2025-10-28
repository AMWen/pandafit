import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/constants.dart';
import '../data/models/exercise_model.dart';
import '../data/models/core_exercise_model.dart';
import '../data/services/localdb_service.dart';
import '../data/services/workout_generator.dart';
import '../data/services/core_workout_generator.dart';
import '../data/widgets/exercise_card_widget.dart';
import '../data/widgets/core_workout_card_widget.dart';
import 'history_screen.dart';

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
  CoreWorkoutRoutine? completedCoreWorkoutToday;
  CoreWorkoutRoutine? completedCoreWorkoutYesterday;
  DateTime today = DateTime.now();
  DateTime yesterday = DateTime.now().subtract(Duration(days: 1));
  Map<String, Exercise> exerciseUpdates = {}; // Track exercise updates by name
  Map<MuscleGroup, List<Exercise>> completedWorkoutsToday = {}; // Track completed workouts with exercises

  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadTodaysWorkout();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0 || index == 1) { // Upper Body (0) or Lower Body (1)
        selectedTarget = index == 0 ? MuscleGroup.upperBody : MuscleGroup.lowerBody;
        if (currentWorkout == null || currentWorkout!.targetArea != selectedTarget) {
          _generateWorkout(selectedTarget!);
        }
      } else if (index == 2) { // Core tab
        if (currentCoreWorkout == null && !isCoreCompleted) {
          _generateCoreWorkout();
        }
      }
    });
  }

  void _onItemTapped(int index) {
    _pageController.jumpToPage(index); // Instant jump, no animation
  }

  Future<void> _loadTodaysWorkout() async {
    final routine = await LocalDB.getRoutineForDate(today);
    final coreRoutine = await LocalDB.getCoreRoutineForDate(today);
    final yesterdayCoreRoutine = await LocalDB.getCoreRoutineForDate(yesterday);

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
        final defaultCompletedSets = List.generate(exercise.sets, (_) => lowEndReps);

        exerciseUpdates[exercise.name] = exercise.copyWith(
          completedSets: defaultCompletedSets,
        );
      }

      setState(() {
        currentWorkout = workout;
        isLoading = false;
      });
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
      _showSnackbar('Workout saved! Great job!');

      // Mark this target as completed today
      setState(() {
        completedWorkoutsToday[currentWorkout!.targetArea] = updatedExercises;
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
          completedWorkoutsToday.remove(targetArea);
        });

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(milliseconds: 800)),
    );
  }


  Widget _buildWorkoutView() {
    // Check if selected target has been completed
    if (selectedTarget != null && completedWorkoutsToday.containsKey(selectedTarget!)) {
      final completedExercises = completedWorkoutsToday[selectedTarget!]!;
      final targetName = muscleGroupToString(selectedTarget!);

      return Column(
        children: [
          // Completion message
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[300]!, width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 48),
                SizedBox(height: 12),
                Text(
                  '$targetName completed!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "You're killing it!",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _undoCompletion(selectedTarget!),
                  icon: Icon(Icons.undo, size: 14),
                  label: Text('undo', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
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
            itemCount: currentWorkout!.exercises.length,
            itemBuilder: (context, index) {
              final exercise = currentWorkout!.exercises[index];
              // Use updated exercise if available
              final displayExercise = exerciseUpdates[exercise.name] ?? exercise;

              return ExerciseCard(
                exercise: displayExercise,
                onUpdate: _updateExercise,
                onLaunchVideo: () => _launchUrl(exercise.videoLink),
              );
            },
          ),
        ),

        // Complete workout button - always visible
        Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _completeWorkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              'Complete Workout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoreWorkoutPage() {
    return _WorkoutPageWidget(
      title: 'Core',
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
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[300]!, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Core workout completed!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "You're killing it!",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _undoCoreCompletion,
                      icon: Icon(Icons.undo, size: 14),
                      label: Text('undo', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          // Upper Body Tab
          _buildWorkoutPage('Upper Body'),
          // Lower Body Tab
          _buildWorkoutPage('Lower Body'),
          // Core Tab
          _buildCoreWorkoutPage(),
          // History Tab
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: primaryColor,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: secondaryColor,
        unselectedItemColor: secondaryColor.withValues(alpha: 0.6),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Upper Body',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Lower Body',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.accessibility_new),
            label: 'Core',
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
    );
  }
}

// Separate widget with AutomaticKeepAliveClientMixin to preserve state
class _WorkoutPageWidget extends StatefulWidget {
  final String title;
  final bool isLoading;
  final Widget workoutView;

  const _WorkoutPageWidget({
    required this.title,
    required this.isLoading,
    required this.workoutView,
  });

  @override
  State<_WorkoutPageWidget> createState() => _WorkoutPageWidgetState();
}

class _WorkoutPageWidgetState extends State<_WorkoutPageWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: widget.isLoading
          ? Center(child: CircularProgressIndicator())
          : widget.workoutView,
    );
  }
}
