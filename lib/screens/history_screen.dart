import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import '../data/constants.dart';
import '../data/models/exercise_model.dart';
import '../data/models/core_exercise_model.dart';
import '../data/models/activity_model.dart';
import '../data/models/activity_attachment.dart';
import '../data/models/history_models.dart';
import '../data/services/localdb_service.dart';
import '../data/services/excel_export_service.dart';
import '../data/services/excel_import_service.dart';
import '../data/services/attachment_service.dart';
import '../data/services/workout_generator.dart';
import '../data/services/core_workout_generator.dart';
import '../data/services/activity_preferences_service.dart';
import '../data/widgets/panda_streak_widget.dart';
import '../data/widgets/attachment_viewer.dart';
import '../data/widgets/exercise_selection_dialog.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onDataImported;

  const HistoryScreen({super.key, this.onDataImported});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late TabController _tabController;
  final Map<DateTime, List<String>> _workoutDates = {};
  DateTime _focusedDay = DateTime.now();
  bool _isLoadingProgress = false;

  // Progress data
  final Map<String, List<ExerciseHistory>> _upperBodyHistory = {};
  final Map<String, List<ExerciseHistory>> _lowerBodyHistory = {};
  final Map<String, List<Activity>> _activitiesHistory = {};

  // Calendar expansion state
  final Set<String> _expandedExercises = {}; // Stores exercise names
  static const int _defaultHistoryLimit = 10;
  final GlobalKey<PandaStreakWidgetState> _streakKey = GlobalKey<PandaStreakWidgetState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadWorkoutDates();
    _loadProgressData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void refreshData() {
    _loadWorkoutDates();
    _loadProgressData();
  }

  Future<void> _loadWorkoutDates() async {
    final db = await LocalDB.database;
    final logs = await db.query('workout_logs');

    final Map<DateTime, List<String>> dates = {};

    for (var log in logs) {
      try {
        final dateStr = log['date'] as String;
        final date = DateTime.parse(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);

        // Parse exercises to determine workout types
        final List<String> workoutTypes = [];
        final exercisesJson = jsonDecode(log['exercises'] as String) as List;

        for (var item in exercisesJson) {
          if (item is Map) {
            // Check for activities
            if (item['isActivity'] == true) {
              if (!workoutTypes.contains('Activity')) {
                workoutTypes.add('Activity');
              }
            }
            // Check for core workout
            else if (item['isCore'] == true) {
              if (!workoutTypes.contains('Core')) {
                workoutTypes.add('Core');
              }
            }
            // Check for upper/lower body
            else if (item['muscleGroup'] != null) {
              final muscleGroup = item['muscleGroup'] as String;
              if (muscleGroup == 'Upper Body' && !workoutTypes.contains('Upper Body')) {
                workoutTypes.add('Upper Body');
              } else if (muscleGroup == 'Lower Body' && !workoutTypes.contains('Lower Body')) {
                workoutTypes.add('Lower Body');
              }
            }
          }
        }

        if (workoutTypes.isNotEmpty) {
          dates[dateOnly] = workoutTypes;
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    if (mounted) {
      setState(() {
        _workoutDates.clear();
        _workoutDates.addAll(dates);
      });
    }
  }

  Future<void> _loadProgressData() async {
    setState(() {
      _isLoadingProgress = true;
    });

    try {
      final db = await LocalDB.database;
      final logs = await db.query('workout_logs', orderBy: 'date ASC');

      // Clear existing data
      _upperBodyHistory.clear();
      _lowerBodyHistory.clear();
      _activitiesHistory.clear();

      // Process each workout log
      for (var log in logs) {
        final dateStr = log['date'] as String;
        final exercisesJson = jsonDecode(log['exercises'] as String) as List;

        for (var item in exercisesJson) {
          if (item is Map) {
            // Handle exercises (upper/lower body)
            if (item['muscleGroup'] != null) {
              final exercise = Exercise.fromJson(Map<String, dynamic>.from(item));

              if (exercise.muscleGroup == MuscleGroup.upperBody) {
                final name = exercise.name;
                if (!_upperBodyHistory.containsKey(name)) {
                  _upperBodyHistory[name] = [];
                }
                _upperBodyHistory[name]!.add(ExerciseHistory(
                  date: dateStr,
                  weight: exercise.weight,
                  completedSets: exercise.completedSets,
                ));
              } else if (exercise.muscleGroup == MuscleGroup.lowerBody) {
                final name = exercise.name;
                if (!_lowerBodyHistory.containsKey(name)) {
                  _lowerBodyHistory[name] = [];
                }
                _lowerBodyHistory[name]!.add(ExerciseHistory(
                  date: dateStr,
                  weight: exercise.weight,
                  completedSets: exercise.completedSets,
                ));
              }
            }
            // Handle activities
            else if (item['isActivity'] == true) {
              final activities = (item['activities'] as List);
              for (var activityData in activities) {
                final activity = Activity.fromMap(activityData);
                final activityWithDate = Activity(
                  name: activity.name,
                  durationMinutes: activity.durationMinutes,
                  notes: activity.notes,
                  date: DateTime.parse(dateStr),
                  attachments: activity.attachments,
                );
                if (!_activitiesHistory.containsKey(activity.name)) {
                  _activitiesHistory[activity.name] = [];
                }
                _activitiesHistory[activity.name]!.add(activityWithDate);
              }
            }
          }
        }
      }
    } catch (e) {
      // Handle error silently
    }

    if (mounted) {
      setState(() {
        _isLoadingProgress = false;
      });
    }
  }

  List<String> _getWorkoutsForDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _workoutDates[dateOnly] ?? [];
  }

  List<String> _getEventsForDay(DateTime day) {
    final workouts = _getWorkoutsForDay(day);
    return workouts.isEmpty ? [] : ['Workout'];
  }

  Future<void> _showRoutineForDate(DateTime date, {int initialTabIndex = 0}) async {
    final workoutsByGroup = await LocalDB.getWorkoutsByMuscleGroup(date);
    final coreWorkout = await LocalDB.getCoreRoutineForDate(date);
    final activities = await LocalDB.getActivitiesForDate(date);
    final dateString = date.toIso8601String().substring(0, 10);

    if (mounted) {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => _WorkoutHistoryDialog(
          date: dateString,
          workoutsByGroup: workoutsByGroup,
          coreWorkout: coreWorkout,
          activities: activities,
          initialTabIndex: initialTabIndex,
          onWorkoutChanged: () {
            // Refresh calendar dots immediately when workout changes
            _loadWorkoutDates();
            // Refresh streak display
            _streakKey.currentState?.refresh();
            // Only refresh home screen if TODAY's date was modified
            final today = DateTime.now().toIso8601String().substring(0, 10);
            if (dateString == today) {
              widget.onDataImported?.call();
            }
          },
        ),
      );

      // Refresh data if changes were saved
      if (result == true) {
        refreshData();
        // Note: Home screen refresh already called via onWorkoutChanged callback
      }
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout History'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: secondaryColor,
          unselectedLabelColor: secondaryColor.withValues(alpha: 0.6),
          indicatorColor: secondaryColor,
          tabs: [
            Tab(text: 'Calendar'),
            Tab(text: muscleGroupShortName(MuscleGroup.upperBody)),
            Tab(text: muscleGroupShortName(MuscleGroup.lowerBody)),
            Tab(text: muscleGroupShortName(MuscleGroup.otherActivity)),
          ],
        ),
        actions: [
          SizedBox(
            width: 34,
            child: IconButton(
              icon: Icon(Icons.upload),
              tooltip: 'Import',
              onPressed: () async {
                if (!context.mounted) return;
                String result = await ExcelImportService.importFromExcel(context);
                if (context.mounted) {
                  showErrorSnackbar(context, result);
                  // Refresh data after import
                  refreshData();
                  // Refresh streak display
                  _streakKey.currentState?.refresh();
                  // Notify parent to refresh home screen data
                  widget.onDataImported?.call();
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
                String result = await ExcelExportService.exportToExcel();
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
          _buildProgressList(_upperBodyHistory, MuscleGroup.upperBody),
          _buildProgressList(_lowerBodyHistory, MuscleGroup.lowerBody),
          _buildActivitiesList(_activitiesHistory),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadWorkoutDates();
      },
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: TableCalendar(
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => false,
          eventLoader: _getEventsForDay,
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;

              // Get workout types for the day
              final workoutTypes = _getWorkoutsForDay(date);
              if (workoutTypes.isEmpty) return null;

              // Color mapping for different workout types using WorkoutColors
              final Map<String, Color> colorMap = {
                'Upper Body': WorkoutColors.upperBody,
                'Lower Body': WorkoutColors.lowerBody,
                'Core': WorkoutColors.core,
                'Activity': WorkoutColors.otherActivity,
              };

              // Sort workout types in consistent order: Upper, Lower, Core, Activities
              final sortOrder = ['Upper Body', 'Lower Body', 'Core', 'Activity'];
              final sortedWorkoutTypes = workoutTypes.toList()
                ..sort((a, b) {
                  final indexA = sortOrder.indexOf(a);
                  final indexB = sortOrder.indexOf(b);
                  return indexA.compareTo(indexB);
                });

              // Create dots for each workout type (max 4)
              final dots = sortedWorkoutTypes.take(4).map((type) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    color: colorMap[type] ?? primaryColor,
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
            ),
          SizedBox(height: 16),
          // Legend for calendar colors
          _buildColorLegend(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: PandaStreakWidget(key: _streakKey),
          ),
          SizedBox(height: 24),
        ],
        ),
      ),
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
          _buildLegendItem(muscleGroupToString(MuscleGroup.upperBody), WorkoutColors.upperBody),
          _buildLegendItem(muscleGroupToString(MuscleGroup.lowerBody), WorkoutColors.lowerBody),
          _buildLegendItem(muscleGroupToString(MuscleGroup.core), WorkoutColors.core),
          _buildLegendItem(muscleGroupToString(MuscleGroup.otherActivity), WorkoutColors.otherActivity),
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

  Widget _buildProgressList(Map<String, List<ExerciseHistory>> historyMap, MuscleGroup muscleGroup) {
    if (_isLoadingProgress) {
      return Center(child: CircularProgressIndicator());
    }

    if (historyMap.isEmpty) {
      return Center(
        child: Text(
          'No exercise history yet.\nComplete workouts to see progress!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final exerciseNames = historyMap.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadProgressData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: exerciseNames.length + 1, // +1 for info message
        itemBuilder: (context, index) {
          // Show info message as first item
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        children: [
                          TextSpan(
                            text: 'Blue badge',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: ' shows PR (best weight × reps)'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Show exercise cards
          final exerciseIndex = index - 1;
          final exerciseName = exerciseNames[exerciseIndex];
          final history = historyMap[exerciseName]!;
          return _buildExerciseCard(exerciseName, history, muscleGroup);
        },
      ),
    );
  }

  Widget _buildExerciseCard(String exerciseName, List<ExerciseHistory> history, MuscleGroup muscleGroup) {
    // Sort by date (most recent first)
    final sortedHistory = List<ExerciseHistory>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Determine tab index based on muscle group using tab order
    final tabIndex = workoutTabOrder.indexOf(muscleGroup);

    // Check if this exercise is expanded
    final isExpanded = _expandedExercises.contains(exerciseName);
    final hasMoreEntries = sortedHistory.length > _defaultHistoryLimit;

    // Limit history to 10 entries unless expanded
    final displayedHistory = isExpanded
        ? sortedHistory
        : sortedHistory.take(_defaultHistoryLimit).toList();

    // Calculate best set (max weight × reps)
    double bestVolume = 0;
    String bestSetDisplay = '';
    for (var entry in sortedHistory) {
      if (entry.weight != null) {
        for (var reps in entry.completedSets) {
          double volume = entry.weight! * reps;
          if (volume > bestVolume) {
            bestVolume = volume;
            bestSetDisplay = '${formatWeight(entry.weight!)}lb × $reps';
          }
        }
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 4),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exerciseName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (bestSetDisplay.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bestSetDisplay,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 32,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 40,
                columnSpacing: 35,
                horizontalMargin: 0,
                dividerThickness: 0,
                columns: [
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Sets × Reps', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: displayedHistory.map((entry) {
                  final sets = entry.completedSets.join(', ');
                  return DataRow(
                    onSelectChanged: (_) {
                      // Parse date and open dialog with appropriate tab
                      final date = DateTime.parse(entry.date);
                      _showRoutineForDate(date, initialTabIndex: tabIndex);
                    },
                    cells: [
                      DataCell(Text(_formatDate(entry.date))),
                      DataCell(Text(entry.weight != null ? '${formatWeight(entry.weight!)}lb' : '-')),
                      DataCell(Text(sets.isNotEmpty ? sets : '-')),
                    ],
                  );
                }).toList(),
              ),
            ),
            // Show/Hide more button
            if (hasMoreEntries)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedExercises.remove(exerciseName);
                      } else {
                        _expandedExercises.add(exerciseName);
                      }
                    });
                  },
                  child: Text(
                    isExpanded
                        ? 'Show less'
                        : 'Show all (${sortedHistory.length} entries)',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitiesList(Map<String, List<Activity>> historyMap) {
    if (_isLoadingProgress) {
      return Center(child: CircularProgressIndicator());
    }

    if (historyMap.isEmpty) {
      return Center(
        child: Text(
          'No activity history yet.\nStart logging activities to see progress!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final activityNames = historyMap.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadProgressData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: activityNames.length + 1, // +1 for info message
        itemBuilder: (context, index) {
          // Show info message as first item
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Scroll right for attachments (if needed) • Tap notes to expand',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Show activity cards
          final activityIndex = index - 1;
          final activityName = activityNames[activityIndex];
          final history = historyMap[activityName]!;
          return _buildActivityCard(activityName, history);
        },
      ),
    );
  }

  Widget _buildActivityCard(String activityName, List<Activity> history) {
    // Sort by date (most recent first)
    final sortedHistory = List<Activity>.from(history)
      ..sort((a, b) => (b.date ?? DateTime.now()).compareTo(a.date ?? DateTime.now()));

    // Check if this activity is expanded
    final isExpanded = _expandedExercises.contains(activityName);
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
              activityName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 32,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 40,
                columnSpacing: 35,
                horizontalMargin: 0,
                dividerThickness: 0,
                columns: [
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: displayedHistory.map((activity) {
                  final dateStr = _formatDate(activity.date?.toIso8601String() ?? '');
                  final durationStr = '${activity.durationMinutes} min';
                  final notesStr = activity.notes ?? '';
                  final hasAttachments = activity.attachments != null && activity.attachments!.isNotEmpty;

                  return DataRow(
                    onSelectChanged: (_) {
                      // Open dialog with activities tab selected
                      if (activity.date != null) {
                        final tabIndex = workoutTabOrder.indexOf(MuscleGroup.otherActivity);
                        _showRoutineForDate(activity.date!, initialTabIndex: tabIndex);
                      }
                    },
                    cells: [
                      DataCell(Text(dateStr)),
                      DataCell(Text(durationStr)),
                      DataCell(
                        _buildNotesCell(notesStr),
                      ),
                      DataCell(
                        hasAttachments
                            ? _buildAttachmentsCell(activity)
                            : SizedBox.shrink(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            // Show/Hide more button
            if (hasMoreEntries)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedExercises.remove(activityName);
                      } else {
                        _expandedExercises.add(activityName);
                      }
                    });
                  },
                  child: Text(
                    isExpanded
                        ? 'Show less'
                        : 'Show all (${sortedHistory.length} entries)',
                    style: TextStyle(color: primaryColor),
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

  Widget _buildAttachmentsCell(Activity activity) {
    if (activity.attachments == null || activity.attachments!.isEmpty) {
      return SizedBox.shrink();
    }

    final attachments = activity.attachments!;
    final firstAttachment = attachments.first;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttachmentViewer(
              attachments: attachments,
              activityName: activity.name,
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.memory(
                base64Decode(firstAttachment.thumbnailBase64),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (attachments.length > 1) ...[
            SizedBox(width: 4),
            Text(
              '+${attachments.length - 1}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          SizedBox(width: 4),
          Icon(Icons.open_in_new, size: 12, color: Colors.grey[600]),
        ],
      ),
    );
  }

  Widget _buildNotesCell(String notes) {
    if (notes.isEmpty) {
      return SizedBox.shrink();
    }

    // Count actual newlines to determine number of lines
    final lineCount = '\n'.allMatches(notes).length + 1;
    final maxLines = lineCount.clamp(1, 2);

    return Tooltip(
      message: notes,
      triggerMode: TooltipTriggerMode.tap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 120),
        child: Text(
          notes,
          style: TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
          maxLines: maxLines,
        ),
      ),
    );
  }
}

// Workout History Dialog with tabs for multiple muscle groups
class _WorkoutHistoryDialog extends StatefulWidget {
  final String date;
  final Map<MuscleGroup, List<Exercise>> workoutsByGroup;
  final CoreWorkoutRoutine? coreWorkout;
  final ActivityRoutine? activities;
  final int initialTabIndex;
  final VoidCallback? onWorkoutChanged;

  const _WorkoutHistoryDialog({
    required this.date,
    required this.workoutsByGroup,
    this.coreWorkout,
    this.activities,
    this.initialTabIndex = 0,
    this.onWorkoutChanged,
  });

  @override
  State<_WorkoutHistoryDialog> createState() => _WorkoutHistoryDialogState();
}

class _WorkoutHistoryDialogState extends State<_WorkoutHistoryDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _totalTabs;
  bool _isEditing = false;

  // Editable data
  late Map<MuscleGroup, List<Exercise>> _editableWorkouts;
  late CoreWorkoutRoutine? _editableCoreWorkout;
  late List<Activity> _editableActivities;

  // Current saved state (what's actually in the database after any saves from view mode)
  late Map<MuscleGroup, List<Exercise>> _currentSavedWorkouts;
  late CoreWorkoutRoutine? _currentSavedCoreWorkout;
  late List<Activity> _currentSavedActivities;

  @override
  void initState() {
    super.initState();
    // Always show all 4 tabs in consistent order
    _totalTabs = 4;
    _tabController = TabController(
      length: _totalTabs,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _totalTabs - 1),
    );

    // Add listener to rebuild when tab changes (updates Add/Edit button)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    // Initialize editable copies and saved state
    _editableWorkouts = Map.from(widget.workoutsByGroup.map((key, value) =>
      MapEntry(key, value.map((e) => e.copyWith()).toList())));
    _editableCoreWorkout = widget.coreWorkout;
    _editableActivities = widget.activities?.activities.map((a) => a.copyWith()).toList() ?? [];

    // Initialize current saved state to match initial data
    _currentSavedWorkouts = Map.from(widget.workoutsByGroup.map((key, value) =>
      MapEntry(key, value.map((e) => e.copyWith()).toList())));
    _currentSavedCoreWorkout = widget.coreWorkout;
    _currentSavedActivities = widget.activities?.activities.map((a) => a.copyWith()).toList() ?? [];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState(String message, {MuscleGroup? muscleGroup}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            // Show "Add Workout" button in edit mode for upper/lower/core
            if (_isEditing && muscleGroup != null && muscleGroup != MuscleGroup.otherActivity) ...[
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _addWorkoutForCurrentTab(),
                icon: Icon(Icons.add, size: 18),
                label: Text('Add Workout'),
                style: compactButtonStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasContent(MuscleGroup muscleGroup) {
    if (muscleGroup == MuscleGroup.core) {
      return _editableCoreWorkout != null;
    } else if (muscleGroup == MuscleGroup.otherActivity) {
      return _editableActivities.isNotEmpty;
    } else {
      return _editableWorkouts.containsKey(muscleGroup);
    }
  }

  Widget _buildExerciseList(List<Exercise> exercises, MuscleGroup muscleGroup) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exercise = entry.value;

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: TextStyles.mediumText,
                        ),
                      ),
                      if (_isEditing)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: ActionColors.delete),
                          onPressed: () {
                            setState(() {
                              _editableWorkouts[muscleGroup]!.removeAt(index);
                            });
                          },
                          tooltip: 'Delete exercise',
                          padding: EdgeInsets.all(4),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                if (_isEditing) ...[
                  // Editable weight (matching home screen style)
                  Row(
                    children: [
                      Text('Weight: ', style: TextStyles.normalText),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: TextEditingController(text: exercise.weight?.toString() ?? ''),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          decoration: InputDecoration(
                            hintText: '0',
                            suffixText: 'lbs',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (value) {
                            final weight = double.tryParse(value);
                            _editableWorkouts[muscleGroup]![index] = exercise.copyWith(weight: weight);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Editable sets (matching home screen style with Wrap)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(exercise.completedSets.length, (setIndex) {
                      return SizedBox(
                        width: 75,
                        child: TextField(
                          controller: TextEditingController(text: exercise.completedSets[setIndex].toString()),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Set ${setIndex + 1}',
                            hintText: 'reps',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            final reps = int.tryParse(value) ?? 0;
                            final newSets = List<int>.from(exercise.completedSets);
                            newSets[setIndex] = reps;
                            _editableWorkouts[muscleGroup]![index] = exercise.copyWith(completedSets: newSets);
                          },
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 8),
                ] else ...[
                  // View mode
                  if (exercise.weight != null && exercise.completedSets.isNotEmpty)
                    Text(
                      exercise.completedSets.map((r) => '${formatWeight(exercise.weight!)}lb x $r').join(', '),
                      style: TextStyles.normalText,
                    )
                  else
                    Text(
                      '$numSets sets of ${exercise.reps} reps (not completed)',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ],
            ),
          );
          }),
          // Add Exercise button (in edit mode)
          if (_isEditing) ...[
            SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _showAddExerciseDialog(muscleGroup),
                icon: Icon(Icons.add, size: 18),
                label: Text('Add Exercise'),
                style: compactButtonStyle,
              ),
            ),
          ],
        ],
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

  Widget _buildActivitiesContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show empty state if no activities and not editing
          if (_editableActivities.isEmpty && !_isEditing) ...[
            _buildEmptyState('No activities'),
          ],
          // Show activities list
          ..._editableActivities.asMap().entries.map((entry) {
            final index = entry.key;
            final activity = entry.value;

            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.name,
                          style: TextStyles.mediumText,
                        ),
                      ),
                      if (_isEditing)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: ActionColors.delete),
                          onPressed: () {
                            setState(() {
                              _editableActivities.removeAt(index);
                            });
                          },
                          tooltip: 'Delete activity',
                          padding: EdgeInsets.all(4),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (_isEditing) ...[
                  // Editable duration
                  Row(
                    children: [
                      Text('Duration: ', style: TextStyles.normalText),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: TextEditingController(text: activity.durationMinutes.toString()),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: 'min',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final duration = int.tryParse(value) ?? activity.durationMinutes;
                            _editableActivities[index] = activity.copyWith(durationMinutes: duration);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Editable notes
                  TextField(
                    controller: TextEditingController(text: activity.notes ?? ''),
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (value) {
                      _editableActivities[index] = activity.copyWith(notes: value.isEmpty ? null : value);
                    },
                  ),
                  SizedBox(height: 8),
                  // Attachments
                  Row(
                    children: [
                      Text('Attachments:', style: TextStyles.normalText),
                      SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final attachment = await AttachmentService.pickAttachment();
                            if (attachment != null) {
                              setState(() {
                                final newAttachments = List<ActivityAttachment>.from(activity.attachments ?? []);
                                newAttachments.add(attachment);
                                _editableActivities[index] = activity.copyWith(attachments: newAttachments);
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding attachment: $e'),
                                  backgroundColor: ActionColors.error,
                                  duration: Duration(milliseconds: 1500),
                                ),
                              );
                            }
                          }
                        },
                        icon: Icon(Icons.attach_file, size: 16),
                        label: Text('Add'),
                        style: smallButtonStyle,
                      ),
                    ],
                  ),
                  if (activity.attachments != null && activity.attachments!.isNotEmpty) ...[
                    SizedBox(height: 4),
                    ...activity.attachments!.asMap().entries.map((attachEntry) {
                      final attIndex = attachEntry.key;
                      final attachment = attachEntry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: 4),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.white),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: Image.memory(base64Decode(attachment.thumbnailBase64), fit: BoxFit.cover),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(attachment.fileName, style: TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 16, color: ActionColors.delete),
                              onPressed: () {
                                setState(() {
                                  final newAttachments = List<ActivityAttachment>.from(activity.attachments!);
                                  newAttachments.removeAt(attIndex);
                                  _editableActivities[index] = activity.copyWith(
                                    attachments: newAttachments.isEmpty ? null : newAttachments,
                                  );
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ] else ...[
                  // View mode
                  Text(
                    '${activity.durationMinutes} minutes',
                    style: TextStyles.normalText.copyWith(color: Colors.grey),
                  ),
                  if (activity.notes != null && activity.notes!.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      activity.notes!,
                      style: TextStyles.normalText.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (activity.attachments != null && activity.attachments!.isNotEmpty) ...[
                    SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttachmentViewer(
                              attachments: activity.attachments!,
                              activityName: activity.name,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            '${activity.attachments!.length} attachment${activity.attachments!.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
              ),
            );
          }),
          // Add Activity button (in edit mode)
          if (_isEditing) ...[
            SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: _showAddActivityDialogForHistory,
                icon: Icon(Icons.add, size: 18),
                label: Text('Add Activity'),
                style: compactButtonStyle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddActivityDialogForHistory() async {
    final result = await showDialog<Activity>(
      context: context,
      builder: (context) => _AddActivityDialog(),
    );

    if (result != null) {
      setState(() {
        _editableActivities.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultipleTabs = _totalTabs > 1;

    // Always show all 4 tabs in consistent order using source of truth
    final tabLabels = workoutTabOrder.map((mg) => muscleGroupShortName(mg)).toList();

    final tabContent = workoutTabOrder.map((muscleGroup) {
      if (muscleGroup == MuscleGroup.core) {
        return _editableCoreWorkout != null
            ? _buildCoreWorkoutList(_editableCoreWorkout!)
            : _buildEmptyState('No core workout', muscleGroup: muscleGroup);
      } else if (muscleGroup == MuscleGroup.otherActivity) {
        // Always show activities list (includes Add button in edit mode)
        return _buildActivitiesContent();
      } else {
        return _editableWorkouts.containsKey(muscleGroup)
            ? _buildExerciseList(_editableWorkouts[muscleGroup]!, muscleGroup)
            : _buildEmptyState('No ${muscleGroupToString(muscleGroup).toLowerCase()} workout', muscleGroup: muscleGroup);
      }
    }).toList();

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
              indicatorColor: primaryColor,
              labelPadding: EdgeInsets.symmetric(horizontal: 4),
              tabs: workoutTabOrder.asMap().entries.map((entry) {
                final index = entry.key;
                final muscleGroup = entry.value;
                final hasContent = _hasContent(muscleGroup);

                return Tab(
                  child: Text(
                    tabLabels[index],
                    style: TextStyle(
                      color: hasContent ? WorkoutColors.forMuscleGroup(muscleGroup) : Colors.grey,
                      fontWeight: hasContent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isEditing) ...[
              // Show appropriate button based on current tab
              Builder(
                builder: (context) {
                  final currentTabIndex = _tabController.index;
                  final currentMuscleGroup = workoutTabOrder[currentTabIndex];
                  final hasContent = _hasContent(currentMuscleGroup);
                  final isOtherActivities = currentMuscleGroup == MuscleGroup.otherActivity;

                  // Other Activities tab shows Delete icon and Edit button if has content
                  if (isOtherActivities) {
                    if (!hasContent) {
                      // No content - just show Edit button
                      return OutlinedButton(
                        onPressed: () => setState(() => _isEditing = true),
                        style: primaryButtonStyle,
                        child: Text('Edit', style: TextStyle(fontSize: 16)),
                      );
                    } else {
                      // Has content - show Delete icon and Edit button
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _deleteCurrentWorkout,
                            icon: Icon(Icons.delete, color: ActionColors.delete),
                            tooltip: 'Delete workout',
                            padding: EdgeInsets.all(8),
                          ),
                          SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => setState(() => _isEditing = true),
                            style: primaryButtonStyle,
                            child: Text('Edit', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      );
                    }
                  }

                  // Core tab with content shows Delete icon (can't edit core)
                  if (currentMuscleGroup == MuscleGroup.core && hasContent) {
                    return IconButton(
                      onPressed: _deleteCurrentWorkout,
                      icon: Icon(Icons.delete, color: ActionColors.delete),
                      tooltip: 'Delete workout',
                      padding: EdgeInsets.all(8),
                    );
                  }

                  // For other tabs, show Add if no content, Edit+Delete if has content
                  if (!hasContent) {
                    return OutlinedButton(
                      onPressed: () => _addWorkoutForCurrentTab(),
                      style: primaryButtonStyle,
                      child: Text('Add', style: TextStyle(fontSize: 16)),
                    );
                  } else {
                    // Show both Delete and Edit buttons
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _deleteCurrentWorkout,
                          icon: Icon(Icons.delete, color: ActionColors.delete),
                          tooltip: 'Delete workout',
                          padding: EdgeInsets.all(8),
                        ),
                        SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => setState(() => _isEditing = true),
                          style: primaryButtonStyle,
                          child: Text('Edit', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    );
                  }
                },
              ),
              SizedBox(width: 12),
            ],
            if (_isEditing) ...[
              IconButton(
                onPressed: _deleteCurrentWorkout,
                icon: Icon(Icons.delete, color: ActionColors.delete),
                tooltip: 'Delete workout',
                padding: EdgeInsets.all(8),
              ),
              SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  // Cancel - reset to current saved state (what's in the database)
                  setState(() {
                    _editableWorkouts = Map.from(_currentSavedWorkouts.map((key, value) =>
                      MapEntry(key, value.map((e) => e.copyWith()).toList())));
                    _editableCoreWorkout = _currentSavedCoreWorkout;
                    _editableActivities = _currentSavedActivities.map((a) => a.copyWith()).toList();
                    _isEditing = false;
                  });
                },
                style: primaryButtonStyle,
                child: Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Save', style: TextStyle(fontSize: 16)),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Close', style: TextStyle(fontSize: 16)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _addWorkoutForCurrentTab() async {
    final currentTabIndex = _tabController.index;
    final currentMuscleGroup = workoutTabOrder[currentTabIndex];

    // Check if content already exists (shouldn't happen, but handle it)
    if (_hasContent(currentMuscleGroup)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Workout already exists for this date'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
      return;
    }

    // Add workout based on muscle group
    if (currentMuscleGroup == MuscleGroup.upperBody || currentMuscleGroup == MuscleGroup.lowerBody) {
      try {
        // Use the selected date to generate deterministic workout
        final date = DateTime.parse(widget.date);
        final dateSeed = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
        final workout = await WorkoutGenerator.generateWorkout(currentMuscleGroup, dateSeed);

        // Mark exercises as completed by filling in completedSets with suggested reps
        final completedExercises = workout.exercises.map((e) {
          final lowEndReps = int.tryParse(e.reps.split('-').first) ?? 8;
          final completedSets = List.generate(numSets, (_) => lowEndReps);
          return e.copyWith(completedSets: completedSets);
        }).toList();

        if (_isEditing) {
          // In edit mode: just update local state (don't save to DB yet)
          setState(() {
            _editableWorkouts[currentMuscleGroup] = completedExercises;
          });
        } else {
          // Not in edit mode: save immediately to database
          await _saveWorkoutToDatabase(muscleGroup: currentMuscleGroup, exercises: completedExercises);
          await _refreshDialogData();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${muscleGroupToString(currentMuscleGroup)} workout added!'),
              duration: Duration(milliseconds: 800),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating workout: $e'),
              backgroundColor: ActionColors.error,
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      }
    } else if (currentMuscleGroup == MuscleGroup.core) {
      try {
        final date = DateTime.parse(widget.date);
        final dateSeed = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
        final coreWorkout = CoreWorkoutGenerator.generateDailyCoreRoutine(dateSeed);

        if (_isEditing) {
          // In edit mode: just update local state (don't save to DB yet)
          setState(() {
            _editableCoreWorkout = coreWorkout;
          });
        } else {
          // Not in edit mode: save immediately to database
          await _saveWorkoutToDatabase(coreWorkout: coreWorkout);
          await _refreshDialogData();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Core workout added!'),
              duration: Duration(milliseconds: 800),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating core workout: $e'),
              backgroundColor: ActionColors.error,
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      }
    }
  }

  Future<void> _showAddExerciseDialog(MuscleGroup muscleGroup) async {
    // Get all exercises for this muscle group from ExerciseDatabase
    final allExercises = muscleGroup == MuscleGroup.upperBody
        ? [
            ...ExerciseDatabase.chestExercises,
            ...ExerciseDatabase.backExercises,
            ...ExerciseDatabase.shoulderExercises,
            ...ExerciseDatabase.armExercises,
          ]
        : ExerciseDatabase.legExercises;

    // Filter out exercises that are already in the current workout
    final currentExerciseNames = (_editableWorkouts[muscleGroup] ?? [])
        .map((e) => e.name)
        .toSet();
    final availableExercises = allExercises
        .where((ex) => !currentExerciseNames.contains(ex.name))
        .toList();

    if (!mounted) return;

    // Show exercise selection dialog
    final selectedExercise = await showExerciseSelectionDialog(
      context: context,
      availableExercises: availableExercises,
    );

    if (selectedExercise != null && mounted) {
      setState(() {
        // Add with completed sets pre-filled
        final lowEndReps = int.tryParse(selectedExercise.reps.split('-').first) ?? 8;
        final completedSets = List.generate(numSets, (_) => lowEndReps);
        final exerciseWithSets = selectedExercise.copyWith(completedSets: completedSets);
        _editableWorkouts[muscleGroup]!.add(exerciseWithSets);
      });
    }
  }

  Future<void> _deleteCurrentWorkout() async {
    // Determine which workout to delete based on current tab
    final tabIndex = _tabController.index;
    if (tabIndex < 0 || tabIndex >= workoutTabOrder.length) return;

    final muscleGroup = workoutTabOrder[tabIndex];
    final workoutName = muscleGroupShortName(muscleGroup);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Workout'),
        content: Text('Are you sure you want to delete the entire $workoutName workout for this date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: ActionColors.delete),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Update local state
      setState(() {
        if (muscleGroup == MuscleGroup.core) {
          _editableCoreWorkout = null;
        } else if (muscleGroup == MuscleGroup.otherActivity) {
          _editableActivities.clear();
        } else {
          _editableWorkouts.remove(muscleGroup);
        }
      });

      // If not in edit mode, save the deletion to database immediately and refresh
      if (!_isEditing) {
        try {
          await _saveChangesWithoutClosing();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Workout deleted successfully'),
                duration: Duration(milliseconds: 800),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting workout: $e'),
                backgroundColor: ActionColors.error,
                duration: Duration(milliseconds: 1500),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _refreshDialogData({bool preserveEditMode = false}) async {
    // Reload workout data from database
    final date = DateTime.parse(widget.date);
    final workoutsByGroup = await LocalDB.getWorkoutsByMuscleGroup(date);
    final coreWorkout = await LocalDB.getCoreRoutineForDate(date);
    final activities = await LocalDB.getActivitiesForDate(date);

    if (mounted) {
      setState(() {
        // Update editable copies with fresh data
        _editableWorkouts = Map.from(workoutsByGroup.map((key, value) =>
          MapEntry(key, value.map((e) => e.copyWith()).toList())));
        _editableCoreWorkout = coreWorkout;
        _editableActivities = activities?.activities.map((a) => a.copyWith()).toList() ?? [];

        // Update current saved state to reflect what's actually in the database
        _currentSavedWorkouts = Map.from(workoutsByGroup.map((key, value) =>
          MapEntry(key, value.map((e) => e.copyWith()).toList())));
        _currentSavedCoreWorkout = coreWorkout;
        _currentSavedActivities = activities?.activities.map((a) => a.copyWith()).toList() ?? [];

        if (!preserveEditMode) {
          _isEditing = false; // Exit edit mode to show in view mode
        }
      });
    }
  }

  Future<void> _saveWorkoutToDatabase({
    MuscleGroup? muscleGroup,
    List<Exercise>? exercises,
    CoreWorkoutRoutine? coreWorkout,
  }) async {
    final dateStr = widget.date;
    final db = await LocalDB.database;

    // Get existing workout log
    final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [dateStr]);
    List<dynamic> existingExercises = [];

    if (existing.isNotEmpty) {
      final existingData = existing.first;
      existingExercises = jsonDecode(existingData['exercises'] as String) as List;
    }

    // Add exercises for the muscle group
    if (muscleGroup != null && exercises != null) {
      // Remove old exercises for this muscle group
      existingExercises.removeWhere((item) =>
        item is Map && item['muscleGroup'] == muscleGroupToString(muscleGroup));

      // Add new exercises
      for (final exercise in exercises) {
        existingExercises.add(exercise.toJson());
      }
    }

    // Add core workout
    if (coreWorkout != null) {
      // Remove old core workout
      existingExercises.removeWhere((item) =>
        item is Map && item['isCore'] == true);

      // Add new core workout
      existingExercises.add({
        'isCore': true,
        'sets': coreWorkout.sets,
        'exercisesPerSet': coreWorkout.exercisesPerSet,
        'exercises': coreWorkout.exercises.map((e) => e.toJson()).toList(),
      });
    }

    // Calculate target area
    final targetAreas = <String>[];
    for (var item in existingExercises) {
      if (item is Map) {
        if (item['muscleGroup'] == muscleGroupToString(MuscleGroup.upperBody) &&
            !targetAreas.contains(muscleGroupToString(MuscleGroup.upperBody))) {
          targetAreas.add(muscleGroupToString(MuscleGroup.upperBody));
        } else if (item['muscleGroup'] == muscleGroupToString(MuscleGroup.lowerBody) &&
            !targetAreas.contains(muscleGroupToString(MuscleGroup.lowerBody))) {
          targetAreas.add(muscleGroupToString(MuscleGroup.lowerBody));
        } else if (item['isCore'] == true &&
            !targetAreas.contains(muscleGroupToString(MuscleGroup.core))) {
          targetAreas.add(muscleGroupToString(MuscleGroup.core));
        }
      }
    }
    final targetAreaStr = targetAreas.isNotEmpty ? targetAreas.join(' + ') : 'Workout';

    // Update or insert
    if (existing.isEmpty) {
      await db.insert('workout_logs', {
        'date': dateStr,
        'target_area': targetAreaStr,
        'exercises': jsonEncode(existingExercises),
      });
    } else {
      await db.update('workout_logs', {
        'target_area': targetAreaStr,
        'exercises': jsonEncode(existingExercises),
      }, where: 'date = ?', whereArgs: [dateStr]);
    }

    // Notify parent to refresh calendar dots
    widget.onWorkoutChanged?.call();
  }

  Future<void> _saveChanges() async {
    try {
      // Save changes to database
      await _saveChangesWithoutClosing();

      // Update current saved state to match what was just saved
      if (mounted) {
        setState(() {
          _currentSavedWorkouts = Map.from(_editableWorkouts.map((key, value) =>
            MapEntry(key, value.map((e) => e.copyWith()).toList())));
          _currentSavedCoreWorkout = _editableCoreWorkout;
          _currentSavedActivities = _editableActivities.map((a) => a.copyWith()).toList();
        });
      }

      // Close dialog and show success message
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate changes were saved
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Workout updated successfully'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: ActionColors.error,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  Future<void> _saveChangesWithoutClosing() async {
    final dateStr = widget.date;

    // Use the service method to update workouts while preserving other muscle groups
    await LocalDB.updateWorkoutsForDate(
      date: dateStr,
      originalMuscleGroups: widget.workoutsByGroup.keys.toSet(),
      newWorkoutsByGroup: _editableWorkouts,
      originalHadCore: widget.coreWorkout != null,
      newCoreWorkout: _editableCoreWorkout,
      originalHadActivities: widget.activities != null,
      newActivities: _editableActivities.isEmpty ? null : _editableActivities,
    );

    // Notify parent to refresh calendar dots
    widget.onWorkoutChanged?.call();
  }
}

// Dialog for adding a new activity
class _AddActivityDialog extends StatefulWidget {
  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();
  final List<ActivityAttachment> _attachments = [];
  List<String> _previousActivityNames = [];

  @override
  void initState() {
    super.initState();
    _loadPreviousActivityNames();
  }

  Future<void> _loadPreviousActivityNames() async {
    final names = await ActivityPreferencesService.getActivityNames();
    if (mounted) {
      setState(() {
        _previousActivityNames = names;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final attachment = await AttachmentService.pickAttachment();
      if (attachment != null) {
        setState(() {
          _attachments.add(attachment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding attachment: $e'),
            backgroundColor: ActionColors.error,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _durationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter activity name and duration'),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text);
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid duration'),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    final activity = Activity(
      name: _nameController.text.trim(),
      durationMinutes: duration,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      attachments: _attachments.isEmpty ? null : List.from(_attachments),
    );

    // Auto-save to Hive for future autocomplete and duration pre-fill
    try {
      await ActivityPreferencesService.saveOrUpdateActivity(
        activity.name,
        activity.durationMinutes,
      );
    } catch (e) {
      // Ignore save errors, activity will still be added to workout
    }

    if (mounted) {
      Navigator.pop(context, activity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _previousActivityNames.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) async {
                _nameController.text = selection;

                // Pre-fill duration from Hive if available
                final savedActivity = await ActivityPreferencesService.getActivity(selection);
                if (savedActivity != null && mounted) {
                  setState(() {
                    _durationController.text = savedActivity.usualDurationMinutes.toString();
                  });
                }
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sync with our controller
                controller.text = _nameController.text;
                controller.selection = _nameController.selection;

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Activity Name',
                    hintText: 'e.g., Kayaking, Cycling, Taekwondo',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    _nameController.text = value;
                  },
                );
              },
            ),
            SizedBox(height: 16),
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
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Attachments', style: TextStyle(fontWeight: FontWeight.w500)),
                OutlinedButton.icon(
                  onPressed: _pickAttachment,
                  icon: Icon(Icons.attach_file, size: 16),
                  label: Text('Add File'),
                  style: smallButtonStyle,
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              SizedBox(height: 8),
              ..._attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                return Container(
                  margin: EdgeInsets.only(bottom: 4),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.white),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Image.memory(base64Decode(attachment.thumbnailBase64), fit: BoxFit.cover),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(attachment.fileName, style: TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 16, color: ActionColors.delete),
                        onPressed: () => setState(() => _attachments.removeAt(index)),
                        padding: EdgeInsets.zero,
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
          onPressed: _save,
          child: Text('Add'),
        ),
      ],
    );
  }
}
