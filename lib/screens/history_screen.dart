import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../data/constants.dart';
import '../data/models/exercise_model.dart';
import '../data/models/core_exercise_model.dart';
import '../data/services/localdb_service.dart';
import '../data/widgets/panda_streak_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  Map<DateTime, Set<MuscleGroup>> _workoutsByDate = {}; // Changed to track workout types
  late TabController _tabController;
  Map<String, List<ExerciseHistory>> _upperBodyHistory = {};
  Map<String, List<ExerciseHistory>> _lowerBodyHistory = {};
  bool _isLoadingProgress = false;
  Set<String> _expandedExercises = {}; // Track which exercises show full history
  static const int _defaultHistoryLimit = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadWorkoutDates();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index > 0 && _upperBodyHistory.isEmpty && _lowerBodyHistory.isEmpty && !_isLoadingProgress) {
      _loadProgressData();
    }
  }

  // Helper function to filter out core workouts from exercise data
  List<Exercise> _filterRegularExercises(List<dynamic> data) {
    return data
        .where((item) => item is! Map || item['isCore'] != true)
        .map((item) => Exercise.fromJson(item))
        .toList();
  }

  void _loadWorkoutDates() async {
    final db = await LocalDB.database;
    final logs = await db.query('workout_logs', orderBy: 'date DESC');

    final workoutsByDate = <DateTime, Set<MuscleGroup>>{};

    for (var log in logs) {
      final dateStr = log['date'] as String;
      final date = DateTime.parse(dateStr);
      final cleanDate = DateTime(date.year, date.month, date.day);

      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      // Initialize set for this date if not exists
      workoutsByDate.putIfAbsent(cleanDate, () => <MuscleGroup>{});

      for (var item in exercisesJson) {
        if (item is Map) {
          if (item['isCore'] == true) {
            // Core workout
            workoutsByDate[cleanDate]!.add(MuscleGroup.core);
          } else {
            // Regular exercise
            final exercise = Exercise.fromJson(item as Map<String, dynamic>);
            // Only count non-skipped exercises
            if (!exercise.isSkipped) {
              workoutsByDate[cleanDate]!.add(exercise.muscleGroup);
            }
          }
        }
      }
    }

    setState(() {
      _workoutsByDate = workoutsByDate;
    });
  }

  Future<void> _loadProgressData() async {
    setState(() => _isLoadingProgress = true);

    final db = await LocalDB.database;
    final logs = await db.query('workout_logs', orderBy: 'date DESC');

    Map<String, List<ExerciseHistory>> upperHistory = {};
    Map<String, List<ExerciseHistory>> lowerHistory = {};

    for (var log in logs) {
      final dateStr = log['date'] as String;
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      // Filter out core workouts (they have isCore: true)
      final regularExercises = _filterRegularExercises(exercisesJson);

      for (var exercise in regularExercises) {
        // Use utility function to check if exercise was actually completed
        if (isExerciseCompleted(exercise)) {
          final entry = ExerciseHistory(
            date: dateStr,
            weight: exercise.weight!,
            completedSets: exercise.completedSets,
          );

          if (exercise.muscleGroup == MuscleGroup.upperBody) {
            upperHistory.putIfAbsent(exercise.name, () => []).add(entry);
          } else {
            lowerHistory.putIfAbsent(exercise.name, () => []).add(entry);
          }
        }
      }
    }

    setState(() {
      _upperBodyHistory = upperHistory;
      _lowerBodyHistory = lowerHistory;
      _isLoadingProgress = false;
    });
  }

  // Get workout types for a specific day
  Set<MuscleGroup> _getWorkoutsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _workoutsByDate[key] ?? {};
  }

  // Event loader for calendar - returns non-empty list if workouts exist
  List<String> _getEventsForDay(DateTime day) {
    final workouts = _getWorkoutsForDay(day);
    return workouts.isEmpty ? [] : ['Workout'];
  }

  Future<void> _showRoutineForDate(DateTime date) async {
    final workoutsByGroup = await LocalDB.getWorkoutsByMuscleGroup(date);
    final coreWorkout = await LocalDB.getCoreRoutineForDate(date);
    final dateString = date.toIso8601String().substring(0, 10);

    if (workoutsByGroup.isEmpty && coreWorkout == null && mounted) {
      showErrorSnackbar(context, 'No workout found for this date');
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => _WorkoutHistoryDialog(
          date: dateString,
          workoutsByGroup: workoutsByGroup,
          coreWorkout: coreWorkout,
        ),
      );
    }
  }

  void showErrorSnackbar(BuildContext context, String message) {
    Duration duration =
        message.contains('Error') ? Duration(milliseconds: 1500) : Duration(milliseconds: 800);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout History'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: secondaryColor,
          unselectedLabelColor: secondaryColor.withValues(alpha: 0.6),
          indicatorColor: secondaryColor,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Upper Body'),
            Tab(text: 'Lower Body'),
          ],
        ),
        actions: [
          SizedBox(
            width: 34,
            child: IconButton(
              icon: Icon(Icons.upload),
              tooltip: 'Import',
              onPressed: () async {
                String result = await LocalDB.importProgress();
                if (context.mounted) {
                  showErrorSnackbar(context, result);
                }
              },
            ),
          ),
          SizedBox(
            width: 34,
            child: IconButton(
              icon: Icon(Icons.save),
              tooltip: 'Export',
              onPressed: () async {
                String result = await LocalDB.exportProgress();
                if (context.mounted) {
                  showErrorSnackbar(context, result);
                }
              },
            ),
          ),
          SizedBox(width: 10),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarView(),
          _buildProgressList(_upperBodyHistory),
          _buildProgressList(_lowerBodyHistory),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        SizedBox(height: 16),
        TableCalendar(
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: DateTime.now(),
          eventLoader: _getEventsForDay,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              final workouts = _getWorkoutsForDay(date);
              if (workouts.isEmpty) return null;

              // Create a dot for each workout type
              final dots = workouts.map((muscleGroup) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    color: WorkoutColors.forMuscleGroup(muscleGroup),
                    shape: BoxShape.circle,
                  ),
                );
              }).toList();

              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: dots,
                ),
              );
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false, // hide the "2 weeks" / "Month" button
          ),
          onDaySelected: (selectedDay, focusedDay) {
            _showRoutineForDate(selectedDay);
          },
        ),
        SizedBox(height: 16),
        // Legend for calendar colors
        _buildColorLegend(),
        PandaStreakWidget(),
      ],
    );
  }

  Widget _buildColorLegend() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem('Upper Body', WorkoutColors.upperBody),
          _buildLegendItem('Lower Body', WorkoutColors.lowerBody),
          _buildLegendItem('Core', WorkoutColors.core),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildProgressList(Map<String, List<ExerciseHistory>> historyMap) {
    if (_isLoadingProgress) {
      return Center(child: CircularProgressIndicator());
    }

    if (historyMap.isEmpty) {
      return Center(
        child: Text(
          'No workout history yet.\nStart logging workouts to see progress!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final exercises = historyMap.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadProgressData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          final exerciseName = exercises[index];
          final history = historyMap[exerciseName]!;
          return _buildExerciseCard(exerciseName, history);
        },
      ),
    );
  }

  Widget _buildExerciseCard(String exerciseName, List<ExerciseHistory> history) {
    // Sort by date (most recent first)
    final sortedHistory = List<ExerciseHistory>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Check if this exercise is expanded
    final isExpanded = _expandedExercises.contains(exerciseName);
    final hasMoreEntries = sortedHistory.length > _defaultHistoryLimit;

    // Limit history to 10 entries unless expanded
    final displayedHistory = isExpanded
        ? sortedHistory
        : sortedHistory.take(_defaultHistoryLimit).toList();

    return Card(
      margin: EdgeInsets.only(bottom: 4),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exerciseName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 35,
                columnSpacing: 50,
                horizontalMargin: 0,
                dividerThickness: 0,
                columns: [
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Sets x Reps', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: displayedHistory.map((record) {
                  final dateStr = _formatDate(record.date);
                  final weightStr = '${formatWeight(record.weight ?? 0)}lb';
                  final setsStr = record.completedSets.map((reps) => reps.toString()).join(', ');

                  return DataRow(cells: [
                    DataCell(Text(dateStr)),
                    DataCell(Text(weightStr)),
                    DataCell(Text(setsStr, style: TextStyle(fontSize: 13))),
                  ]);
                }).toList(),
              ),
            ),
            // Show "Load More" or "Show Less" button if needed
            if (hasMoreEntries)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedExercises.remove(exerciseName);
                        } else {
                          _expandedExercises.add(exerciseName);
                        }
                      });
                    },
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      isExpanded
                          ? 'Show Less'
                          : 'Load All (${sortedHistory.length} total)',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
    } catch (e) {
      return dateStr;
    }
  }
}

// Workout History Dialog with tabs for multiple muscle groups
class _WorkoutHistoryDialog extends StatefulWidget {
  final String date;
  final Map<MuscleGroup, List<Exercise>> workoutsByGroup;
  final CoreWorkoutRoutine? coreWorkout;

  const _WorkoutHistoryDialog({
    required this.date,
    required this.workoutsByGroup,
    this.coreWorkout,
  });

  @override
  State<_WorkoutHistoryDialog> createState() => _WorkoutHistoryDialogState();
}

class _WorkoutHistoryDialogState extends State<_WorkoutHistoryDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _totalTabs;

  @override
  void initState() {
    super.initState();
    _totalTabs = widget.workoutsByGroup.length + (widget.coreWorkout != null ? 1 : 0);
    _tabController = TabController(length: _totalTabs, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildExerciseList(List<Exercise> exercises) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: exercises.map((exercise) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyles.mediumText,
                ),
                SizedBox(height: 4),
                if (exercise.weight != null && exercise.completedSets.isNotEmpty)
                  Text(
                    exercise.completedSets.map((r) => '${formatWeight(exercise.weight!)}lb x $r').join(', '),
                    style: TextStyles.normalText,
                  )
                else
                  Text(
                    '${exercise.sets} sets of ${exercise.reps} reps (not completed)',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCoreWorkoutList(CoreWorkoutRoutine coreWorkout) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '${coreWorkout.sets} sets × ${coreWorkout.exercisesPerSet} exercises',
              style: TextStyles.normalText.copyWith(color: Colors.grey),
            ),
          ),
          ...coreWorkout.exercises.map((exercise) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (exercise.isTimed)
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('⏰', style: TextStyle(fontSize: 16)),
                    ),
                  Text(
                    exercise.formatText(),
                    style: TextStyles.normalText,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroups = widget.workoutsByGroup.keys.toList();
    final hasMultipleTabs = _totalTabs > 1;

    // Build tab labels
    final tabLabels = [
      ...muscleGroups.map((group) => muscleGroupToString(group)),
      if (widget.coreWorkout != null) 'Core',
    ];

    // Build tab content
    final tabContent = [
      ...muscleGroups.map((group) => _buildExerciseList(widget.workoutsByGroup[group]!)),
      if (widget.coreWorkout != null) _buildCoreWorkoutList(widget.coreWorkout!),
    ];

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Workout for ${widget.date}', style: TextStyles.dialogTitle),
          if (hasMultipleTabs) ...[
            SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryColor,
              tabs: tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ] else ...[
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tabLabels.first,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: hasMultipleTabs
            ? TabBarView(
                controller: _tabController,
                children: tabContent,
              )
            : tabContent.first,
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    );
  }
}
