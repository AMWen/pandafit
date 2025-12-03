import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../constants.dart';
import '../models/custom_exercise_preferences.dart';
import '../models/exercise_model.dart';
import '../models/activity_model.dart';
import '../widgets/import_dialog.dart';
import 'localdb_service.dart';
import 'attachment_service.dart';

class ExcelImportService {
  /// Import workout data from XLSX file with user selection
  static Future<String> importFromExcel(BuildContext context) async {
    try {
      // Pick file with data loading enabled for cloud file support
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, // Load bytes for cloud files
      );

      if (result == null || result.files.isEmpty) {
        return 'Import canceled';
      }

      final platformFile = result.files.first;

      // Try to get bytes directly (works for cloud files like Google Drive)
      Uint8List? bytes = platformFile.bytes;

      // Fallback to path-based reading for large local files
      if (bytes == null) {
        if (platformFile.path == null) {
          return 'Error: Unable to access file. Try downloading to device first.';
        }
        final file = File(platformFile.path!);
        bytes = await file.readAsBytes();
      }

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
      final warnings = <String>[]; // Collect warnings during import

      // Clear selected muscle groups in single pass if replacing
      if (importAsReplace) {
        final groupsToClear = <MuscleGroup>{};
        if (selectedSheets[ExcelSheetNames.upperBody] == true) {
          groupsToClear.add(MuscleGroup.upperBody);
        }
        if (selectedSheets[ExcelSheetNames.lowerBody] == true) {
          groupsToClear.add(MuscleGroup.lowerBody);
        }
        if (selectedSheets[ExcelSheetNames.core] == true) {
          groupsToClear.add(MuscleGroup.core);
        }
        if (selectedSheets[ExcelSheetNames.otherActivities] == true) {
          groupsToClear.add(MuscleGroup.otherActivity);
        }
        await _clearSelectedMuscleGroups(groupsToClear);
      }

      // Import Upper Body history
      if (selectedSheets[ExcelSheetNames.upperBody] == true) {
        await _importUpperBodyHistory(excel);
        importCount++;
      }

      // Import Lower Body history
      if (selectedSheets[ExcelSheetNames.lowerBody] == true) {
        await _importLowerBodyHistory(excel);
        importCount++;
      }

      // Import Core history
      if (selectedSheets[ExcelSheetNames.core] == true) {
        await _importCoreHistory(excel);
        importCount++;
      }

      // Import Activities history
      if (selectedSheets[ExcelSheetNames.otherActivities] == true) {
        await _importActivitiesHistory(excel);
        importCount++;
      }

      // Import Activity Attachments
      if (selectedSheets[ExcelSheetNames.activityAttachments] == true) {
        final attachmentWarnings = await _importActivityAttachments(excel, importAsReplace);
        warnings.addAll(attachmentWarnings);
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

      String successMessage = 'Successfully imported $importCount item(s)!';
      if (warnings.isNotEmpty) {
        successMessage += '\n\nWarnings:\n${warnings.join('\n')}';
      }
      return successMessage;
    } catch (e) {
      return 'Error importing data: $e';
    }
  }

  /// Helper to clear exercises of multiple muscle groups from all workout logs in single pass
  static Future<void> _clearSelectedMuscleGroups(Set<MuscleGroup> muscleGroups) async {
    if (muscleGroups.isEmpty) return;

    final db = await LocalDB.database;

    // V3 schema: Delete rows for each muscle group directly
    for (final muscleGroup in muscleGroups) {
      final muscleGroupKey = muscleGroupToString(muscleGroup);
      await db.delete('workout_logs',
        where: 'muscle_group = ?',
        whereArgs: [muscleGroupKey]);
    }
  }

  /// Import Upper Body workout history from sheet
  static Future<void> _importUpperBodyHistory(Excel excel) async {
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
        // V3 schema: Check if entry exists for this date AND muscle group
        final muscleGroupKey = muscleGroupToString(MuscleGroup.upperBody);
        final existing = await db.query('workout_logs',
          where: 'date = ? AND muscle_group = ?',
          whereArgs: [date, muscleGroupKey]);

        if (existing.isNotEmpty) {
          // Merge with existing
          final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;

          await db.update('workout_logs', {
            'exercises': jsonEncode([...existingExercises, ...exercises]),
          }, where: 'date = ? AND muscle_group = ?', whereArgs: [date, muscleGroupKey]);
        } else {
          // Insert new
          await db.insert('workout_logs', {
            'date': date,
            'muscle_group': muscleGroupKey,
            'exercises': jsonEncode(exercises),
          });
        }
      }
    }
  }

  /// Import Lower Body workout history from sheet
  static Future<void> _importLowerBodyHistory(Excel excel) async {
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
        // V3 schema: Check if entry exists for this date AND muscle group
        final muscleGroupKey = muscleGroupToString(MuscleGroup.lowerBody);
        final existing = await db.query('workout_logs',
          where: 'date = ? AND muscle_group = ?',
          whereArgs: [date, muscleGroupKey]);

        if (existing.isNotEmpty) {
          // Merge with existing
          final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;

          await db.update('workout_logs', {
            'exercises': jsonEncode([...existingExercises, ...exercises]),
          }, where: 'date = ? AND muscle_group = ?', whereArgs: [date, muscleGroupKey]);
        } else {
          // Insert new
          await db.insert('workout_logs', {
            'date': date,
            'muscle_group': muscleGroupKey,
            'exercises': jsonEncode(exercises),
          });
        }
      }
    }
  }

  /// Import Core workout history from sheet
  static Future<void> _importCoreHistory(Excel excel) async {
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

          // V3 schema: Check if entry exists for this date AND muscle group
          final muscleGroupKey = muscleGroupToString(MuscleGroup.core);
          final existing = await db.query('workout_logs',
            where: 'date = ? AND muscle_group = ?',
            whereArgs: [date, muscleGroupKey]);

          if (existing.isNotEmpty) {
            // Merge with existing
            final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;

            await db.update('workout_logs', {
              'exercises': jsonEncode([...existingExercises, coreWorkoutData]),
            }, where: 'date = ? AND muscle_group = ?', whereArgs: [date, muscleGroupKey]);
          } else {
            // Insert new
            await db.insert('workout_logs', {
              'date': date,
              'muscle_group': muscleGroupKey,
              'exercises': jsonEncode([coreWorkoutData]),
            });
          }
        }
      }
    }
  }

  /// Import Activities workout history from sheet
  static Future<void> _importActivitiesHistory(Excel excel) async {
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
          // Parse format: "45 min" or "45 min: notes here" or "45 min: notes here [2025-01-15T14:30:00.000Z]"
          // Extract completedAt if present (ISO 8601 timestamp in brackets at end)
          DateTime? completedAt;
          String workingValue = cellValue;
          // Match only ISO 8601 datetime format in brackets at end: [YYYY-MM-DDTHH:MM:SS...]
          final completedAtMatch = RegExp(r'\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[^\]]*)\]$').firstMatch(cellValue);
          if (completedAtMatch != null) {
            try {
              completedAt = DateTime.parse(completedAtMatch.group(1)!);
              workingValue = cellValue.substring(0, completedAtMatch.start).trim();
            } catch (e) {
              // If parsing fails, ignore completedAt and keep original value
            }
          }

          final parts = workingValue.split(': ');
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
                'completedAt': completedAt?.toIso8601String(),
              });
            }
          }
        }
      }

      if (activities.isNotEmpty) {
        // V3 schema: Insert each activity in its own row
        for (final activityMap in activities) {
          final activity = Activity.fromMap(activityMap);
          final muscleGroupKey = LocalDB.getActivityMuscleGroupKey(activity);

          // Check if this specific activity already exists
          final existing = await db.query('workout_logs',
              where: 'date = ? AND muscle_group = ?',
              whereArgs: [date, muscleGroupKey]);

          if (existing.isEmpty) {
            // Insert new activity row
            final activityData = {
              'isActivity': true,
              'activities': [activityMap],
            };

            await db.insert('workout_logs', {
              'date': date,
              'muscle_group': muscleGroupKey,
              'exercises': jsonEncode([activityData]),
            });
          }
          // If activity already exists, skip (no merge needed for exact duplicates)
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

  /// Import Activity Attachments from sheet
  static Future<List<String>> _importActivityAttachments(Excel excel, bool replace) async {
    final sheet = excel.tables[ExcelSheetNames.activityAttachments];
    if (sheet == null || sheet.maxRows < 2) return [];

    final warnings = <String>[];

    final db = await LocalDB.database;

    // Check if this export has the completedAt column (backwards compatibility)
    final hasCompletedAtColumn = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
      .value?.toString().toLowerCase().contains('completed') ?? false;

    // Group attachments by date, activity name, and completedAt
    final attachmentsByDateAndActivity = <String, Map<String, Map<String, dynamic>>>{};

    // Skip header row
    for (int i = 1; i < sheet.maxRows; i++) {
      final date = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString();
      final activityName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString();

      // Parse columns based on format (new format has completedAt, old format doesn't)
      final String? completedAt;
      final String? fileName;
      final String? mimeType;
      final String? originalSizeStr;
      final String? thumbnailBase64;
      final String? fullFileBase64;

      if (hasCompletedAtColumn) {
        // New format: includes completedAt column
        completedAt = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i)).value?.toString();
        fileName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i)).value?.toString();
        mimeType = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i)).value?.toString();
        originalSizeStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i)).value?.toString();
        thumbnailBase64 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i)).value?.toString();
        fullFileBase64 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i)).value?.toString();
      } else {
        // Old format: no completedAt column
        completedAt = null;
        fileName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i)).value?.toString();
        mimeType = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i)).value?.toString();
        originalSizeStr = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i)).value?.toString();
        thumbnailBase64 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i)).value?.toString();
        fullFileBase64 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i)).value?.toString();
      }

      if (date == null || activityName == null || fileName == null || mimeType == null ||
          thumbnailBase64 == null || thumbnailBase64.isEmpty) {
        continue; // Skip invalid rows (thumbnail is required)
      }

      final originalSize = int.tryParse(originalSizeStr ?? '0') ?? 0;

      final attachmentData = {
        'fileName': fileName,
        'mimeType': mimeType,
        'thumbnailBase64': thumbnailBase64,
        'fullFileBase64': fullFileBase64 != null && fullFileBase64.isNotEmpty ? fullFileBase64 : null,
        'attachedDate': DateTime.now().toIso8601String(),
        'originalSizeBytes': originalSize,
      };

      // Create unique key: name + completedAt (if available)
      final completedAtKey = (completedAt != null && completedAt.isNotEmpty) ? completedAt : '';
      final activityKey = '$activityName|$completedAtKey';

      if (!attachmentsByDateAndActivity.containsKey(date)) {
        attachmentsByDateAndActivity[date] = {};
      }
      if (!attachmentsByDateAndActivity[date]!.containsKey(activityKey)) {
        attachmentsByDateAndActivity[date]![activityKey] = {
          'activityName': activityName,
          'completedAt': completedAtKey.isNotEmpty ? completedAtKey : null,
          'attachments': <Map<String, dynamic>>[],
        };
      }
      (attachmentsByDateAndActivity[date]![activityKey]!['attachments'] as List).add(attachmentData);
    }

    // Update activities in database with attachments
    for (var dateEntry in attachmentsByDateAndActivity.entries) {
      final date = dateEntry.key;
      final activitiesByKey = dateEntry.value;

      // Get existing workout log for this date
      final existing = await db.query('workout_logs', where: 'date = ?', whereArgs: [date]);

      if (existing.isEmpty) {
        continue; // No activity record for this date, skip
      }

      final existingExercises = jsonDecode(existing.first['exercises'] as String) as List;
      bool modified = false;

      // Track which activity keys have already been matched and processed
      final processedActivityKeys = <String>{};

      // Find activity entries and add attachments
      for (int i = 0; i < existingExercises.length; i++) {
        final item = existingExercises[i];
        if (item is Map && item['isActivity'] == true) {
          final activities = item['activities'] as List;

          for (int j = 0; j < activities.length; j++) {
            final activityData = activities[j] as Map<String, dynamic>;
            final activityName = activityData['name'] as String;
            final activityCompletedAt = activityData['completedAt'] as String?;

            // Try to match by name + completedAt first
            String? matchedKey;

            // If activity has completedAt, try exact match
            if (activityCompletedAt != null && activityCompletedAt.isNotEmpty) {
              final exactKey = '$activityName|$activityCompletedAt';
              if (activitiesByKey.containsKey(exactKey) && !processedActivityKeys.contains(exactKey)) {
                matchedKey = exactKey;
              }
            }

            // Fallback: match by name only (for activities without completedAt or no exact match)
            if (matchedKey == null) {
              final nameOnlyKey = '$activityName|';
              if (activitiesByKey.containsKey(nameOnlyKey) && !processedActivityKeys.contains(nameOnlyKey)) {
                matchedKey = nameOnlyKey;
              }
            }

            if (matchedKey != null) {
              // Mark this key as processed
              processedActivityKeys.add(matchedKey);
              final importedAttachments = (activitiesByKey[matchedKey]!['attachments'] as List).cast<Map<String, dynamic>>();
              List<Map<String, dynamic>> finalAttachments;

              if (replace) {
                // Replace mode: Use only imported attachments
                finalAttachments = importedAttachments;
              } else {
                // Merge mode: Combine existing and imported, deduplicating by fileName
                final existingAttachments = activityData['attachments'] as List?;
                final existingList = existingAttachments?.cast<Map<String, dynamic>>() ?? [];

                // Start with existing attachments
                finalAttachments = List<Map<String, dynamic>>.from(existingList);

                // Add imported attachments if not already present (deduplicate by fileName)
                for (final importedAtt in importedAttachments) {
                  final fileName = importedAtt['fileName'] as String;
                  final isDuplicate = finalAttachments.any((existing) =>
                    existing['fileName'] == fileName
                  );

                  if (!isDuplicate) {
                    finalAttachments.add(importedAtt);
                  }
                }
              }

              // Validate total size of final attachments list
              int totalSize = 0;
              for (var att in finalAttachments) {
                totalSize += (att['thumbnailBase64'] as String).length;
                final fullFile = att['fullFileBase64'] as String?;
                if (fullFile != null) {
                  totalSize += fullFile.length;
                }
              }

              // Check if total size exceeds SQLite limit
              if (totalSize > AttachmentService.maxTotalAttachmentsBase64Size) {
                // Try removing full files, keeping only thumbnails
                final thumbnailOnlyList = finalAttachments.map((att) {
                  return {
                    'fileName': att['fileName'],
                    'mimeType': att['mimeType'],
                    'thumbnailBase64': att['thumbnailBase64'],
                    'fullFileBase64': null, // Remove full file
                    'attachedDate': att['attachedDate'],
                    'originalSizeBytes': att['originalSizeBytes'],
                  };
                }).toList();

                // Recalculate size with thumbnails only
                int thumbnailOnlySize = 0;
                for (var att in thumbnailOnlyList) {
                  thumbnailOnlySize += (att['thumbnailBase64'] as String).length;
                }

                if (thumbnailOnlySize <= AttachmentService.maxTotalAttachmentsBase64Size) {
                  // Use thumbnail-only version
                  activityData['attachments'] = thumbnailOnlyList;
                  modified = true;
                  warnings.add('Imported attachments for "$activityName" on $date as thumbnail-only to stay within size limits');
                } else {
                  // Cannot merge - would exceed limit even with thumbnails only
                  // Keep existing attachments and skip importing new ones
                  if (replace) {
                    // In replace mode, clear attachments if they can't fit
                    activityData['attachments'] = null;
                    modified = true;
                    warnings.add('Cleared attachments for "$activityName" on $date - exceeds size limit even with thumbnails only');
                  } else {
                    // In merge mode, keep existing attachments, skip importing new ones
                    warnings.add('Skipped importing attachments for "$activityName" on $date - would exceed size limit when merged with existing');
                  }
                }
              } else {
                // Size is fine, use final merged/replaced list
                activityData['attachments'] = finalAttachments;
                modified = true;
              }
            }
          }
        }
      }

      // Update database if modified
      if (modified) {
        await db.update('workout_logs', {
          'exercises': jsonEncode(existingExercises),
        }, where: 'date = ?', whereArgs: [date]);
      }
    }

    return warnings;
  }
}
