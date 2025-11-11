import 'package:flutter/material.dart';
import '../constants.dart';

class ImportOptionsDialog extends StatefulWidget {
  final Map<String, bool> availableSheets;

  const ImportOptionsDialog({
    super.key,
    required this.availableSheets,
  });

  @override
  State<ImportOptionsDialog> createState() => _ImportOptionsDialogState();
}

class _ImportOptionsDialogState extends State<ImportOptionsDialog> {
  late Map<String, bool> selectedSheets;
  bool importAsReplace = true;

  @override
  void initState() {
    super.initState();
    // By default, select all available sheets
    selectedSheets = Map.from(widget.availableSheets);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Import Workout Data', style: TextStyles.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workout History Section
            if (selectedSheets.containsKey(ExcelSheetNames.upperBody) ||
                selectedSheets.containsKey(ExcelSheetNames.lowerBody) ||
                selectedSheets.containsKey(ExcelSheetNames.core) ||
                selectedSheets.containsKey(ExcelSheetNames.otherActivities)) ...[
              Text(
                'Workout History',
                style: TextStyles.primaryBoldHeading,
              ),
              if (selectedSheets.containsKey(ExcelSheetNames.upperBody))
                CheckboxListTile(
                  dense: true,
                  title: Text('Upper Body History'),
                  value: selectedSheets[ExcelSheetNames.upperBody],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.upperBody] = value ?? false;
                    });
                  },
                ),
              if (selectedSheets.containsKey(ExcelSheetNames.lowerBody))
                CheckboxListTile(
                  dense: true,
                  title: Text('Lower Body History'),
                  value: selectedSheets[ExcelSheetNames.lowerBody],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.lowerBody] = value ?? false;
                    });
                  },
                ),
              if (selectedSheets.containsKey(ExcelSheetNames.core))
                CheckboxListTile(
                  dense: true,
                  title: Text('Core History'),
                  value: selectedSheets[ExcelSheetNames.core],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.core] = value ?? false;
                    });
                  },
                ),
              if (selectedSheets.containsKey(ExcelSheetNames.otherActivities))
                CheckboxListTile(
                  dense: true,
                  title: Text('Activities History'),
                  value: selectedSheets[ExcelSheetNames.otherActivities],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.otherActivities] = value ?? false;
                    });
                  },
                ),
              SizedBox(height: 12),
            ],

            // Settings & Preferences Section
            if (selectedSheets.containsKey(ExcelSheetNames.workoutSettings) ||
                selectedSheets.containsKey(ExcelSheetNames.exercisePreferences) ||
                selectedSheets.containsKey(ExcelSheetNames.userCustomExercises) ||
                selectedSheets.containsKey(ExcelSheetNames.userActivities)) ...[
              Text(
                'Settings & Preferences',
                style: TextStyles.primaryBoldHeading,
              ),
              if (selectedSheets.containsKey(ExcelSheetNames.workoutSettings))
                CheckboxListTile(
                  dense: true,
                  title: Text('Workout Settings'),
                  subtitle: Text('Exercise counts per workout', style: TextStyle(fontSize: 12)),
                  value: selectedSheets[ExcelSheetNames.workoutSettings],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.workoutSettings] = value ?? false;
                    });
                  },
                ),
              if (selectedSheets.containsKey(ExcelSheetNames.exercisePreferences))
                CheckboxListTile(
                  dense: true,
                  title: Text('Default Exercise Preferences'),
                  subtitle: Text('Always/never include settings', style: TextStyle(fontSize: 12)),
                  value: selectedSheets[ExcelSheetNames.exercisePreferences],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.exercisePreferences] = value ?? false;
                    });
                  },
                ),
              if (selectedSheets.containsKey(ExcelSheetNames.userCustomExercises))
                CheckboxListTile(
                  dense: true,
                  title: Text('User Custom Exercises'),
                  subtitle: Text('Your custom exercises', style: TextStyle(fontSize: 12)),
                  value: selectedSheets[ExcelSheetNames.userCustomExercises],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.userCustomExercises] = value ?? false;
                    });
                  },
                ),
              if (selectedSheets.containsKey(ExcelSheetNames.userActivities))
                CheckboxListTile(
                  dense: true,
                  title: Text('User Activities'),
                  subtitle: Text('Saved activities with usual durations', style: TextStyle(fontSize: 12)),
                  value: selectedSheets[ExcelSheetNames.userActivities],
                  onChanged: (value) {
                    setState(() {
                      selectedSheets[ExcelSheetNames.userActivities] = value ?? false;
                    });
                  },
                ),
              SizedBox(height: 12),
            ],

            // Import Mode Selection
            Divider(),
            SizedBox(height: 8),
            Text(
              'Import Mode:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            RadioListTile<bool>(
              dense: true,
              title: Text('Replace existing data'),
              subtitle: Text('Overwrite all current data', style: TextStyle(fontSize: 12)),
              value: true,
              groupValue: importAsReplace,
              onChanged: (value) {
                setState(() {
                  importAsReplace = value!;
                });
              },
            ),
            RadioListTile<bool>(
              dense: true,
              title: Text('Merge with existing data'),
              subtitle: Text('Keep current data and add new', style: TextStyle(fontSize: 12)),
              value: false,
              groupValue: importAsReplace,
              onChanged: (value) {
                setState(() {
                  importAsReplace = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final hasSelection = selectedSheets.values.any((v) => v);
            if (!hasSelection) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please select at least one item to import'),
                  duration: Duration(milliseconds: 800),
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'selectedSheets': selectedSheets,
              'importAsReplace': importAsReplace,
            });
          },
          child: Text('Import'),
        ),
      ],
    );
  }
}
