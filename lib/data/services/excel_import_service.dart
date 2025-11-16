import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../constants.dart';
import '../models/custom_exercise_preferences.dart';
import '../models/exercise_model.dart';
import '../widgets/import_dialog.dart';
import 'localdb_service.dart';

class ExcelImportService {
  /// Import workout data from XLSX file with user selection
  static Future<String> importFromExcel(BuildContext context) async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.first.path == null) {
        return 'Import canceled';
      }

      final filePath = result.files.first.path!;
      final file = File(filePath);
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      // Get available sheets
      final availableSheets = <String, bool>{};
      for (var sheetName in excel.tables.keys) {
        availableSheets[sheetName] = true;
      }

      if (!context.mounted) return 'Error: Context no longer valid';

      // Show import dialog
      final options = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => ImportOptionsDialog(availableSheets: availableSheets),
      );

      if (options == null) {
        return 'Import canceled';
      }

      final selectedSheets = options['selectedSheets'] as Map<String, bool>;
      final importAsReplace = options['importAsReplace'] as bool;

      int importCount = 0;

      // Import workout history first (if replace mode, clear existing data)
      if (importAsReplace && (selectedSheets[ExcelSheetNames.upperBody] == true ||
          selectedSheets[ExcelSheetNames.lowerBody] == true ||
          selectedSheets[ExcelSheetNames.core] == true ||
          selectedSheets[ExcelSheetNames.otherActivities] == true)) {
        // Clear workout logs if replacing
        final db = await LocalDB.database;
        await db.delete('workout_logs');
      }

      // Import Upper Body history
      if (selectedSheets[ExcelSheetNames.upperBody] == true) {
        await _importUpperBodyHistory(excel, importAsReplace);
        importCount++;
      }

      // Import Lower Body history
      if (selectedSheets[ExcelSheetNames.lowerBody] == true) {
        await _importLowerBodyHistory(excel, importAsReplace);
        importCount++;
      }

      // Import Core history
      if (selectedSheets[ExcelSheetNames.core] == true) {
        await _importCoreHistory(excel, importAsReplace);
        importCount++;
      }

      // Import Activities history
      if (selectedSheets[ExcelSheetNames.otherActivities] == true) {
        await _importActivitiesHistory(excel, importAsReplace);
        importCount++;
      }

      // Import User Activities preferences
      if (selectedSheets[ExcelSheetNames.userActivities] == true) {
        await _importUserActivities(excel, importAsReplace);
        importCount++;
      }

      // Import Exercise Preferences
      if (selectedSheets[ExcelSheetNames.exercisePreferences] == true) {
        await _importExercisePreferences(excel, importAsReplace);
        importCount++;
      }

      // Import User Custom Exercises
      if (selectedSheets[ExcelSheetNames.userCustomExercises] == true) {
        await _importUserCustomExercises(excel, importAsReplace);
        importCount++;
      }

      // Import Workout Settings
      if (selectedSheets[ExcelSheetNames.workoutSettings] == true) {
        await _importWorkoutSettings(excel);
        importCount++;
      }

      if (importCount == 0) {
        return 'No data imported';
      }

      return 'Successfully imported $importCount item(s)!';
    } catch (e) {
      return 'Error importing data: $e';
    }
  }

  /// Import Upper Body workout history from sheet
  static Future<void> _importUpperBodyHistory(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.upperBody];
    if (sheet == null || sheet.maxRows < 2) return;

    final db = await LocalDB.database;

    // Read header row to get exercise names
    final exerciseNames = <String>[];
    int col = 1;
    while (true) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      final name = cell.value?.toString();
      if (name == null || name.isEmpty) break;
      exerciseNames.add(name);
      col++;
    }

    // Process each date row
    for (int row = 1; row < sheet.maxRows; row++) {
      final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      final date = dateCell.value?.toString();

      if (date == null || date.isEmpty) continue;

      final exercises = <Map<String, dynamic>>[];

      // Process each exercise column
      for (int col = 0; col < exerciseNames.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + 1, rowIndex: row));
        final cellValue = cell.value?.toString();

        if (cellValue != null && cellValue.isNotEmpty) {
          // Parse format: "25lb: 10, 10, 10"
          final match = RegExp(r'([\d.]+)lb:\s*(.+)').firstMatch(cellValue);
          if (match != null) {
            final weight = double.tryParse(match.group(1)!);
            final setsStr = match.group(2)!;
            final sets = setsStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();

            exercises.add({
              'name': exerciseNames[col],
              'muscleGroup': muscleGroupToString(MuscleGroup.upperBody),
              'targetMuscles': <String>[],
              'reps': '8-12',
              'sets': 3,
              'weight': weight,
              'completedSets': sets,
              'videoLink': '',
              'notes': '',
              'isSkipped': false,
            });
          }
        }
      }

      if (exercises.isNotEmpty) {
        // Check if entry exists for this date
        final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [date]);

        if (existing.isNotEmpty) {
          // Merge with existing
          final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;
          final existingTargetArea = existing.first['target_area'] as String;

          final newTargetArea = existingTargetArea.contains(muscleGroupToString(MuscleGroup.upperBody))
              ? existingTargetArea
              : '$existingTargetArea + ${muscleGroupToString(MuscleGroup.upperBody)}';

          await db.update('workout_logs', {
            'target_area': newTargetArea,
            'exercises': jsonEncode([...existingExercises, ...exercises]),
          }, where: 'date = ?', whereArgs: [date]);
        } else {
          // Insert new
          await db.insert('workout_logs', {
            'date': date,
            'target_area': muscleGroupToString(MuscleGroup.upperBody),
            'exercises': jsonEncode(exercises),
          });
        }
      }
    }
  }

  /// Import Lower Body workout history from sheet
  static Future<void> _importLowerBodyHistory(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.lowerBody];
    if (sheet == null || sheet.maxRows < 2) return;

    final db = await LocalDB.database;

    // Read header row to get exercise names
    final exerciseNames = <String>[];
    int col = 1;
    while (true) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      final name = cell.value?.toString();
      if (name == null || name.isEmpty) break;
      exerciseNames.add(name);
      col++;
    }

    // Process each date row
    for (int row = 1; row < sheet.maxRows; row++) {
      final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      final date = dateCell.value?.toString();

      if (date == null || date.isEmpty) continue;

      final exercises = <Map<String, dynamic>>[];

      // Process each exercise column
      for (int col = 0; col < exerciseNames.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + 1, rowIndex: row));
        final cellValue = cell.value?.toString();

        if (cellValue != null && cellValue.isNotEmpty) {
          // Parse format: "25lb: 10, 10, 10"
          final match = RegExp(r'([\d.]+)lb:\s*(.+)').firstMatch(cellValue);
          if (match != null) {
            final weight = double.tryParse(match.group(1)!);
            final setsStr = match.group(2)!;
            final sets = setsStr.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();

            exercises.add({
              'name': exerciseNames[col],
              'muscleGroup': muscleGroupToString(MuscleGroup.lowerBody),
              'targetMuscles': <String>[],
              'reps': '8-12',
              'sets': 3,
              'weight': weight,
              'completedSets': sets,
              'videoLink': '',
              'notes': '',
              'isSkipped': false,
            });
          }
        }
      }

      if (exercises.isNotEmpty) {
        // Check if entry exists for this date
        final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [date]);

        if (existing.isNotEmpty) {
          // Merge with existing
          final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;
          final existingTargetArea = existing.first['target_area'] as String;

          final newTargetArea = existingTargetArea.contains(muscleGroupToString(MuscleGroup.lowerBody))
              ? existingTargetArea
              : '$existingTargetArea + ${muscleGroupToString(MuscleGroup.lowerBody)}';

          await db.update('workout_logs', {
            'target_area': newTargetArea,
            'exercises': jsonEncode([...existingExercises, ...exercises]),
          }, where: 'date = ?', whereArgs: [date]);
        } else {
          // Insert new
          await db.insert('workout_logs', {
            'date': date,
            'target_area': muscleGroupToString(MuscleGroup.lowerBody),
            'exercises': jsonEncode(exercises),
          });
        }
      }
    }
  }

  /// Import Core workout history from sheet
  static Future<void> _importCoreHistory(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.core];
    if (sheet == null || sheet.maxRows < 2) return;

    final db = await LocalDB.database;

    // Process each date row
    for (int row = 1; row < sheet.maxRows; row++) {
      final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      final coreCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));

      final date = dateCell.value?.toString();
      final coreInfo = coreCell.value?.toString();

      if (date == null || date.isEmpty || coreInfo == null || coreInfo.isEmpty) continue;

      // Parse format: "3 sets x 4 exercises: Exercise1(12), Exercise2(10), ..."
      final match = RegExp(r'(\d+)\s+sets\s+x\s+(\d+)\s+exercises:\s*(.+)').firstMatch(coreInfo);
      if (match != null) {
        final sets = int.tryParse(match.group(1)!);
        final exercisesPerSet = int.tryParse(match.group(2)!);
        final exercisesDetailsStr = match.group(3)!;
        final exercisesDetails = exercisesDetailsStr.split(',').map((e) => e.trim()).toList();

        if (sets != null && exercisesPerSet != null) {
          // Parse each exercise detail "30s Plank" or "12 Crunches"
          final exercises = exercisesDetails.map((detail) {
            // Match: number (optional 's') followed by name
            final detailMatch = RegExp(r'^(\d+)(s?)\s+(.+)$').firstMatch(detail);
            if (detailMatch != null) {
              final amount = int.tryParse(detailMatch.group(1)!) ?? 0;
              final isTimed = detailMatch.group(2) == 's';
              final name = detailMatch.group(3)!.trim();
              return {
                'name': name,
                'amount': amount,
                'isTimed': isTimed,
              };
            } else {
              // Fallback: treat as exercise name with 0 amount
              return {
                'name': detail.trim(),
                'amount': 0,
                'isTimed': false,
              };
            }
          }).toList();

          // Create core workout data structure
          final coreWorkoutData = {
            'isCore': true,
            'sets': sets,
            'exercisesPerSet': exercisesPerSet,
            'exercises': exercises,
          };

          // Check if entry exists for this date
          final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [date]);

          if (existing.isNotEmpty) {
            // Merge with existing
            final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;
            final existingTargetArea = existing.first['target_area'] as String;

            final coreLabel = muscleGroupToString(MuscleGroup.core);
            final newTargetArea = existingTargetArea.contains(coreLabel)
                ? existingTargetArea
                : '$existingTargetArea + $coreLabel';

            await db.update('workout_logs', {
              'target_area': newTargetArea,
              'exercises': jsonEncode([...existingExercises, coreWorkoutData]),
            }, where: 'date = ?', whereArgs: [date]);
          } else {
            // Insert new
            await db.insert('workout_logs', {
              'date': date,
              'target_area': muscleGroupToString(MuscleGroup.core),
              'exercises': jsonEncode([coreWorkoutData]),
            });
          }
        }
      }
    }
  }

  /// Import Activities workout history from sheet
  static Future<void> _importActivitiesHistory(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.otherActivities];
    if (sheet == null || sheet.maxRows < 2) return;

    final db = await LocalDB.database;

    // Read header row to get activity names
    final activityNames = <String>[];
    int col = 1;
    while (true) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      final name = cell.value?.toString();
      if (name == null || name.isEmpty) break;
      activityNames.add(name);
      col++;
    }

    // Process each date row
    for (int row = 1; row < sheet.maxRows; row++) {
      final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      final date = dateCell.value?.toString();

      if (date == null || date.isEmpty) continue;

      final activities = <Map<String, dynamic>>[];

      // Process each activity column
      for (int col = 0; col < activityNames.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + 1, rowIndex: row));
        final cellValue = cell.value?.toString();

        if (cellValue != null && cellValue.isNotEmpty) {
          // Parse format: "45 min" or "45 min: notes here"
          final parts = cellValue.split(': ');
          final durationPart = parts[0].trim();
          final notesPart = parts.length > 1 ? parts.sublist(1).join(': ') : null;

          final durationMatch = RegExp(r'(\d+)\s*min').firstMatch(durationPart);
          if (durationMatch != null) {
            final duration = int.tryParse(durationMatch.group(1)!);

            if (duration != null) {
              activities.add({
                'name': activityNames[col],
                'durationMinutes': duration,
                'notes': notesPart,
              });
            }
          }
        }
      }

      if (activities.isNotEmpty) {
        final activityData = {
          'isActivity': true,
          'activities': activities,
        };

        // Check if entry exists for this date
        final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [date]);

        if (existing.isNotEmpty) {
          // Merge with existing
          final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;
          final existingTargetArea = existing.first['target_area'] as String;

          final activityLabel = muscleGroupToString(MuscleGroup.otherActivity);
          final newTargetArea = existingTargetArea.contains(activityLabel)
              ? existingTargetArea
              : '$existingTargetArea + $activityLabel';

          await db.update('workout_logs', {
            'target_area': newTargetArea,
            'exercises': jsonEncode([...existingExercises, activityData]),
          }, where: 'date = ?', whereArgs: [date]);
        } else {
          // Insert new
          await db.insert('workout_logs', {
            'date': date,
            'target_area': muscleGroupToString(MuscleGroup.otherActivity),
            'exercises': jsonEncode([activityData]),
          });
        }
      }
    }
  }

  /// Import User Activities from sheet
  static Future<void> _importUserActivities(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.userActivities];
    if (sheet == null) return;

    final box = await Hive.openBox<UserActivity>(HiveBoxNames.userActivities);

    if (replace) {
      await box.clear();
    }

    // Skip header row
    for (int i = 1; i < sheet.maxRows; i++) {
      final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i));
      final durationCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i));

      final name = nameCell.value?.toString();
      final durationStr = durationCell.value?.toString();

      if (name != null && name.isNotEmpty && durationStr != null) {
        final duration = int.tryParse(durationStr);
        if (duration != null) {
          final activity = UserActivity(
            name: name,
            usualDurationMinutes: duration,
          );
          await box.put(name, activity);
        }
      }
    }
  }

  /// Import Exercise Preferences from sheet
  static Future<void> _importExercisePreferences(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.exercisePreferences];
    if (sheet == null) return;

    final box = await Hive.openBox<CustomExercisePreference>(HiveBoxNames.customExercisePreferences);

    if (replace) {
      await box.clear();
    }

    // Skip header row
    for (int i = 1; i < sheet.maxRows; i++) {
      final exerciseName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString();
      final alwaysInclude = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString() == 'Yes';
      final neverInclude = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i)).value?.toString() == 'Yes';
      final weightStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i)).value?.toString();
      final customRepRange = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i)).value?.toString();
      final customNotes = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i)).value?.toString();
      final customVideoLink = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i)).value?.toString();

      if (exerciseName != null && exerciseName.isNotEmpty) {
        final weight = weightStr != null && weightStr.isNotEmpty ? double.tryParse(weightStr) : null;

        final pref = CustomExercisePreference(
          exerciseName: exerciseName,
          alwaysInclude: alwaysInclude,
          neverInclude: neverInclude,
          customStartingWeight: weight,
          customRepRange: customRepRange != null && customRepRange.isNotEmpty ? customRepRange : null,
          customNotes: customNotes != null && customNotes.isNotEmpty ? customNotes : null,
          customVideoLink: customVideoLink != null && customVideoLink.isNotEmpty ? customVideoLink : null,
        );
        await box.put(exerciseName, pref);
      }
    }
  }

  /// Import User Custom Exercises from sheet
  static Future<void> _importUserCustomExercises(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.userCustomExercises];
    if (sheet == null) return;

    final box = await Hive.openBox<UserCustomExercise>(HiveBoxNames.userCustomExercises);

    if (replace) {
      await box.clear();
    }

    // Skip header row
    for (int i = 1; i < sheet.maxRows; i++) {
      final name = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString();
      final categoryStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString();
      final targetMusclesStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i)).value?.toString();
      final reps = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i)).value?.toString();
      final notes = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i)).value?.toString();
      final weightStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i)).value?.toString();
      final videoLink = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i)).value?.toString();
      final alwaysInclude = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i)).value?.toString() == 'Yes';
      final neverInclude = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: i)).value?.toString() == 'Yes';

      if (name != null && name.isNotEmpty && categoryStr != null) {
        final category = stringToExerciseCategory(categoryStr);
        final targetMuscles = targetMusclesStr != null && targetMusclesStr.isNotEmpty
            ? targetMusclesStr.split(',').map((e) => e.trim()).toList()
            : <String>[];
        final weight = weightStr != null && weightStr.isNotEmpty ? double.tryParse(weightStr) : null;

        final exercise = UserCustomExercise(
          name: name,
          category: category,
          targetMuscles: targetMuscles,
          reps: reps ?? '8-12',
          notes: notes ?? '',
          beginnerWeight: weight,
          videoLink: videoLink ?? '',
          alwaysInclude: alwaysInclude,
          neverInclude: neverInclude,
        );
        await box.put(name, exercise);
      }
    }
  }

  /// Import Workout Settings from sheet
  static Future<void> _importWorkoutSettings(Excel excel) async {
    final sheet = excel.tables[ExcelSheetNames.workoutSettings];
    if (sheet == null) return;

    final box = await Hive.openBox<WorkoutGenerationPreferences>(HiveBoxNames.workoutGenerationPreferences);

    final settings = <String, int>{};

    // Read settings
    for (int i = 1; i < sheet.maxRows; i++) {
      final settingName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString();
      final valueStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString();

      if (settingName != null && valueStr != null) {
        final value = int.tryParse(valueStr);
        if (value != null) {
          settings[settingName] = value;
        }
      }
    }

    // Create preferences object
    if (settings.isNotEmpty) {
      final prefs = WorkoutGenerationPreferences(
        upperBodyChestCount: settings['Upper Body Chest Count'] ?? 1,
        upperBodyBackCount: settings['Upper Body Back Count'] ?? 1,
        upperBodyShoulderCount: settings['Upper Body Shoulder Count'] ?? 1,
        upperBodyArmCount: settings['Upper Body Arm Count'] ?? 2,
        lowerBodyCount: settings['Lower Body Count'] ?? 4,
      );
      await box.put(HiveBoxNames.workoutGenPrefsKey, prefs);
    }
  }
}
