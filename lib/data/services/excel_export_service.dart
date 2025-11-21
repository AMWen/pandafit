import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import '../constants.dart';
import '../models/activity_model.dart';
import '../models/custom_exercise_preferences.dart';
import '../models/exercise_model.dart';
import '../models/history_models.dart';
import 'localdb_service.dart';
import 'activity_preferences_service.dart';

class ExcelExportService {
  /// Export all workout data to XLSX format
  static Future<String> exportToExcel() async {
    try {
      final excel = Excel.createExcel();

      // Create sheets for different data types
      await _createUpperBodySheet(excel);
      await _createLowerBodySheet(excel);
      await _createCoreSheet(excel);
      await _createActivitiesSheet(excel);
      await _createActivityAttachmentsSheet(excel);
      await _createUserActivitiesSheet(excel);
      await _createExercisePreferencesSheet(excel);
      await _createUserCustomExercisesSheet(excel);
      await _createWorkoutGenerationPrefsSheet(excel);

      // Remove default sheet after creating all custom sheets
      if (excel.tables.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Encode to bytes
      final bytes = excel.encode();
      if (bytes == null) {
        return 'Error: Failed to generate Excel file';
      }

      // Save file
      String? filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Workout Data',
        fileName: 'pandafit_export.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (filePath != null) {
        return 'Workout data exported successfully!';
      } else {
        return 'Export canceled';
      }
    } catch (e) {
      return 'Error exporting workout data: $e';
    }
  }

  /// Create Upper Body history sheet
  static Future<void> _createUpperBodySheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.upperBody];

    final db = await LocalDB.database;
    final logs = await db.query('workout_logs', orderBy: 'date ASC');

    // Collect all upper body exercises and organize by date
    Map<String, Map<String, ExerciseHistory>> exercisesByName = {};

    for (var log in logs) {
      final dateStr = log['date'] as String;
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      for (var item in exercisesJson) {
        if (item is! Map || item['isCore'] == true || item['isActivity'] == true) {
          continue;
        }

        final exercise = Exercise.fromJson(item as Map<String, dynamic>);
        if (exercise.muscleGroup == MuscleGroup.upperBody && !exercise.isSkipped) {
          if (!exercisesByName.containsKey(exercise.name)) {
            exercisesByName[exercise.name] = {};
          }
          exercisesByName[exercise.name]![dateStr] = ExerciseHistory(
            date: dateStr,
            weight: exercise.weight,
            completedSets: exercise.completedSets,
          );
        }
      }
    }

    // Build header row
    final headers = ['Date', ...exercisesByName.keys.toList()..sort()];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    }

    // Get all unique dates
    final allDates = <String>{};
    for (var exerciseData in exercisesByName.values) {
      allDates.addAll(exerciseData.keys);
    }
    final sortedDates = allDates.toList()..sort();

    // Build data rows
    for (int rowIdx = 0; rowIdx < sortedDates.length; rowIdx++) {
      final date = sortedDates[rowIdx];

      // Date column
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx + 1))
        .value = TextCellValue(date);

      // Exercise columns
      final sortedExercises = exercisesByName.keys.toList()..sort();
      for (int colIdx = 0; colIdx < sortedExercises.length; colIdx++) {
        final exerciseName = sortedExercises[colIdx];
        final history = exercisesByName[exerciseName]![date];

        if (history != null && history.weight != null) {
          final weight = formatWeight(history.weight!);
          final sets = history.completedSets.join(', ');
          final cellValue = '${weight}lb: $sets';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx + 1, rowIndex: rowIdx + 1))
            .value = TextCellValue(cellValue);
        }
      }
    }
  }

  /// Create Lower Body history sheet
  static Future<void> _createLowerBodySheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.lowerBody];

    final db = await LocalDB.database;
    final logs = await db.query('workout_logs', orderBy: 'date ASC');

    // Collect all lower body exercises and organize by date
    Map<String, Map<String, ExerciseHistory>> exercisesByName = {};

    for (var log in logs) {
      final dateStr = log['date'] as String;
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      for (var item in exercisesJson) {
        if (item is! Map || item['isCore'] == true || item['isActivity'] == true) {
          continue;
        }

        final exercise = Exercise.fromJson(item as Map<String, dynamic>);
        if (exercise.muscleGroup == MuscleGroup.lowerBody && !exercise.isSkipped) {
          if (!exercisesByName.containsKey(exercise.name)) {
            exercisesByName[exercise.name] = {};
          }
          exercisesByName[exercise.name]![dateStr] = ExerciseHistory(
            date: dateStr,
            weight: exercise.weight,
            completedSets: exercise.completedSets,
          );
        }
      }
    }

    // Build header row
    final headers = ['Date', ...exercisesByName.keys.toList()..sort()];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    }

    // Get all unique dates
    final allDates = <String>{};
    for (var exerciseData in exercisesByName.values) {
      allDates.addAll(exerciseData.keys);
    }
    final sortedDates = allDates.toList()..sort();

    // Build data rows
    for (int rowIdx = 0; rowIdx < sortedDates.length; rowIdx++) {
      final date = sortedDates[rowIdx];

      // Date column
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx + 1))
        .value = TextCellValue(date);

      // Exercise columns
      final sortedExercises = exercisesByName.keys.toList()..sort();
      for (int colIdx = 0; colIdx < sortedExercises.length; colIdx++) {
        final exerciseName = sortedExercises[colIdx];
        final history = exercisesByName[exerciseName]![date];

        if (history != null && history.weight != null) {
          final weight = formatWeight(history.weight!);
          final sets = history.completedSets.join(', ');
          final cellValue = '${weight}lb: $sets';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx + 1, rowIndex: rowIdx + 1))
            .value = TextCellValue(cellValue);
        }
      }
    }
  }

  /// Create Core history sheet
  static Future<void> _createCoreSheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.core];

    final db = await LocalDB.database;
    final logs = await db.query('workout_logs', orderBy: 'date ASC');

    // Collect core workouts by date
    Map<String, String> coreByDate = {};

    for (var log in logs) {
      final dateStr = log['date'] as String;
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      for (var item in exercisesJson) {
        if (item is Map && item['isCore'] == true) {
          final sets = item['sets'] as int;
          final exercisesPerSet = item['exercisesPerSet'] as int;
          final exercises = item['exercises'] as List;

          // Format: "3 sets x 4 exercises: 30s Plank, 12 Crunches, ..."
          final exerciseDetails = exercises.map((e) {
            final name = e['name'] as String;
            final amount = e['amount'] as int? ?? 0;
            final isTimed = e['isTimed'] as bool? ?? false;
            return isTimed ? '${amount}s $name' : '$amount $name';
          }).join(', ');
          coreByDate[dateStr] = '$sets sets x $exercisesPerSet exercises: $exerciseDetails';
        }
      }
    }

    // Build header row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Date')
      ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = TextCellValue('Core Workout')
      ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);

    // Get all dates with core workouts
    final sortedDates = coreByDate.keys.toList()..sort();

    // Build data rows
    for (int rowIdx = 0; rowIdx < sortedDates.length; rowIdx++) {
      final date = sortedDates[rowIdx];
      final coreInfo = coreByDate[date]!;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx + 1))
        .value = TextCellValue(date);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx + 1))
        .value = TextCellValue(coreInfo);
    }
  }

  /// Create Activities history sheet
  static Future<void> _createActivitiesSheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.otherActivities];

    final db = await LocalDB.database;
    final logs = await db.query('workout_logs', orderBy: 'date ASC');

    // Collect all activities and organize by date (combine duplicates)
    Map<String, Map<String, Activity>> activitiesByName = {};

    for (var log in logs) {
      final dateStr = log['date'] as String;
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      for (var item in exercisesJson) {
        if (item is Map && item['isActivity'] == true) {
          final activities = (item['activities'] as List);
          for (var activityData in activities) {
            final activity = Activity.fromMap(activityData);
            if (!activitiesByName.containsKey(activity.name)) {
              activitiesByName[activity.name] = {};
            }

            // Check if activity already exists for this date (duplicate entry)
            final existing = activitiesByName[activity.name]![dateStr];
            if (existing != null) {
              // Combine: add durations, concatenate notes, merge attachments
              final combinedDuration = existing.durationMinutes + activity.durationMinutes;
              final combinedNotes = [
                if (existing.notes != null && existing.notes!.isNotEmpty) existing.notes!,
                if (activity.notes != null && activity.notes!.isNotEmpty) activity.notes!,
              ].join(' | ');
              final combinedAttachments = [
                ...?existing.attachments,
                ...?activity.attachments,
              ];

              activitiesByName[activity.name]![dateStr] = existing.copyWith(
                durationMinutes: combinedDuration,
                notes: combinedNotes.isEmpty ? null : combinedNotes,
                attachments: combinedAttachments.isEmpty ? null : combinedAttachments,
              );
            } else {
              // Store full Activity object with date
              activitiesByName[activity.name]![dateStr] = activity.copyWith(
                date: DateTime.parse(dateStr),
              );
            }
          }
        }
      }
    }

    // Build header row
    final headers = ['Date', ...activitiesByName.keys.toList()..sort()];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    }

    // Get all unique dates
    final allDates = <String>{};
    for (var activityData in activitiesByName.values) {
      allDates.addAll(activityData.keys);
    }
    final sortedDates = allDates.toList()..sort();

    // Build data rows
    for (int rowIdx = 0; rowIdx < sortedDates.length; rowIdx++) {
      final date = sortedDates[rowIdx];

      // Date column
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx + 1))
        .value = TextCellValue(date);

      // Activity columns
      final sortedActivities = activitiesByName.keys.toList()..sort();
      for (int colIdx = 0; colIdx < sortedActivities.length; colIdx++) {
        final activityName = sortedActivities[colIdx];
        final history = activitiesByName[activityName]![date];

        if (history != null) {
          final duration = '${history.durationMinutes} min';
          final notes = history.notes != null && history.notes!.isNotEmpty
              ? ': ${history.notes}'
              : '';
          final cellValue = duration + notes;
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx + 1, rowIndex: rowIdx + 1))
            .value = TextCellValue(cellValue);
        }
      }
    }
  }

  /// Create User Activities preferences sheet
  static Future<void> _createUserActivitiesSheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.userActivities];

    final activities = await ActivityPreferencesService.getAllActivities();

    // Header
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Activity Name')
      ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = TextCellValue('Usual Duration (minutes)')
      ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);

    // Data
    for (int i = 0; i < activities.length; i++) {
      final activity = activities[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
        .value = TextCellValue(activity.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
        .value = IntCellValue(activity.usualDurationMinutes);
    }
  }

  /// Create Exercise Preferences sheet
  static Future<void> _createExercisePreferencesSheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.exercisePreferences];

    final box = await Hive.openBox<CustomExercisePreference>(HiveBoxNames.customExercisePreferences);
    final prefs = box.values.toList();

    // Header
    final headers = [
      'Exercise Name',
      'Always Include',
      'Never Include',
      'Custom Starting Weight',
      'Custom Rep Range',
      'Custom Notes',
      'Custom Video Link'
    ];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    }

    // Data
    for (int i = 0; i < prefs.length; i++) {
      final pref = prefs[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
        .value = TextCellValue(pref.exerciseName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
        .value = TextCellValue(pref.alwaysInclude ? 'Yes' : 'No');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
        .value = TextCellValue(pref.neverInclude ? 'Yes' : 'No');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
        .value = pref.customStartingWeight != null
            ? DoubleCellValue(pref.customStartingWeight!)
            : TextCellValue('');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1))
        .value = TextCellValue(pref.customRepRange ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1))
        .value = TextCellValue(pref.customNotes ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1))
        .value = TextCellValue(pref.customVideoLink ?? '');
    }
  }

  /// Create User Custom Exercises sheet
  static Future<void> _createUserCustomExercisesSheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.userCustomExercises];

    final box = await Hive.openBox<UserCustomExercise>(HiveBoxNames.userCustomExercises);
    final exercises = box.values.toList();

    // Header
    final headers = [
      'Name',
      'Category',
      'Target Muscles',
      'Reps',
      'Notes',
      'Beginner Weight',
      'Video Link',
      'Always Include',
      'Never Include'
    ];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    }

    // Data
    for (int i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
        .value = TextCellValue(ex.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
        .value = TextCellValue(exerciseCategoryToString(ex.category));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
        .value = TextCellValue(ex.targetMuscles.join(', '));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1))
        .value = TextCellValue(ex.reps);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1))
        .value = TextCellValue(ex.notes);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1))
        .value = ex.beginnerWeight != null
            ? DoubleCellValue(ex.beginnerWeight!)
            : TextCellValue('');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: i + 1))
        .value = TextCellValue(ex.videoLink);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: i + 1))
        .value = TextCellValue(ex.alwaysInclude ? 'Yes' : 'No');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: i + 1))
        .value = TextCellValue(ex.neverInclude ? 'Yes' : 'No');
    }
  }

  /// Create Workout Generation Preferences sheet
  static Future<void> _createWorkoutGenerationPrefsSheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.workoutSettings];

    final box = await Hive.openBox<WorkoutGenerationPreferences>(HiveBoxNames.workoutGenerationPreferences);
    final prefs = box.get(HiveBoxNames.workoutGenPrefsKey);

    if (prefs == null) return;

    // Header
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Setting')
      ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
      ..value = TextCellValue('Value')
      ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);

    // Data
    final settings = [
      ['Upper Body Chest Count', prefs.upperBodyChestCount],
      ['Upper Body Back Count', prefs.upperBodyBackCount],
      ['Upper Body Shoulder Count', prefs.upperBodyShoulderCount],
      ['Upper Body Arm Count', prefs.upperBodyArmCount],
      ['Lower Body Count', prefs.lowerBodyCount],
    ];

    for (int i = 0; i < settings.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
        .value = TextCellValue(settings[i][0] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
        .value = IntCellValue(settings[i][1] as int);
    }
  }

  /// Create Activity Attachments sheet
  static Future<void> _createActivityAttachmentsSheet(Excel excel) async {
    final sheet = excel[ExcelSheetNames.activityAttachments];

    final db = await LocalDB.database;
    final logs = await db.query('workout_logs', orderBy: 'date ASC');

    // Collect all activity attachments (combine duplicates by date + activity name)
    // First collect activities with combined attachments
    Map<String, Map<String, List<dynamic>>> attachmentsByActivity = {};

    for (var log in logs) {
      final dateStr = log['date'] as String;
      final exercisesJson = jsonDecode(log['exercises'] as String) as List;

      for (var item in exercisesJson) {
        if (item is Map && item['isActivity'] == true) {
          final activities = (item['activities'] as List);
          for (var activityData in activities) {
            final activity = Activity.fromMap(activityData);

            // Check if activity has attachments
            if (activity.attachments != null && activity.attachments!.isNotEmpty) {
              final key = '$dateStr|${activity.name}';
              if (!attachmentsByActivity.containsKey(key)) {
                attachmentsByActivity[key] = {
                  'date': [dateStr],
                  'activityName': [activity.name],
                  'attachments': [],
                };
              }
              (attachmentsByActivity[key]!['attachments'] as List).addAll(activity.attachments!);
            }
          }
        }
      }
    }

    // Flatten to list of attachment records
    final attachments = <Map<String, dynamic>>[];
    for (var entry in attachmentsByActivity.entries) {
      final dateStr = (entry.value['date'] as List).first as String;
      final activityName = (entry.value['activityName'] as List).first as String;
      final activityAttachments = entry.value['attachments'] as List;

      for (var attachment in activityAttachments) {
        attachments.add({
          'date': dateStr,
          'activityName': activityName,
          'fileName': attachment.fileName,
          'mimeType': attachment.mimeType,
          'originalSize': attachment.originalSizeBytes,
          'thumbnailBase64': attachment.thumbnailBase64,
          'fullFileBase64': attachment.fullFileBase64,
        });
      }
    }

    if (attachments.isEmpty) {
      // Create empty sheet with headers only
      final headers = ['Date', 'Activity', 'FileName', 'MIMEType', 'OriginalSize', 'ThumbnailBase64', 'FullFileBase64'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
      }
      return;
    }

    // Build header row
    final headers = ['Date', 'Activity', 'FileName', 'MIMEType', 'OriginalSize', 'ThumbnailBase64', 'FullFileBase64'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(headers[i])
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue200);
    }

    // Build data rows
    for (int rowIdx = 0; rowIdx < attachments.length; rowIdx++) {
      final attachment = attachments[rowIdx];

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx + 1))
        .value = TextCellValue(attachment['date'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx + 1))
        .value = TextCellValue(attachment['activityName'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx + 1))
        .value = TextCellValue(attachment['fileName'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx + 1))
        .value = TextCellValue(attachment['mimeType'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx + 1))
        .value = IntCellValue(attachment['originalSize'] as int);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx + 1))
        .value = TextCellValue(attachment['thumbnailBase64'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx + 1))
        .value = TextCellValue(attachment['fullFileBase64'] as String? ?? '');
    }
  }
}
