import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../models/activity_model.dart';
import '../services/activity_preferences_service.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback? onDelete;
  final bool isReadOnly;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onDelete,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: primaryColor,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity name
                  Text(
                    activity.name,
                    style: TextStyles.mediumText.copyWith(color: secondaryColor),
                  ),
                  SizedBox(height: 8),
                  // Duration
                  Text(
                    '${activity.durationMinutes} minutes',
                    style: TextStyle(
                      color: secondaryColor.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  // Notes
                  if (activity.notes != null && activity.notes!.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      activity.notes!,
                      style: TextStyle(
                        color: secondaryColor.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Delete button (only for non-completed activities)
            if (!isReadOnly && onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                onPressed: onDelete,
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}

class ActivityInputWidget extends StatefulWidget {
  final Function(Activity) onAdd;
  final List<String> previousActivityNames;
  final List<Activity> currentActivities;

  const ActivityInputWidget({
    super.key,
    required this.onAdd,
    this.previousActivityNames = const [],
    this.currentActivities = const [],
  });

  @override
  State<ActivityInputWidget> createState() => _ActivityInputWidgetState();
}

class _ActivityInputWidgetState extends State<ActivityInputWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitActivity() {
    if (_formKey.currentState!.validate()) {
      final activity = Activity(
        name: _nameController.text.trim(),
        durationMinutes: int.parse(_durationController.text),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      widget.onAdd(activity);

      // Clear form
      _nameController.clear();
      _durationController.clear();
      _notesController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      color: primaryColor,
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log Activity',
                style: TextStyles.titleText.copyWith(color: secondaryColor),
              ),
              SizedBox(height: 16),

              // Activity name with autocomplete
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  // Filter out activities already added today
                  final currentActivityNames = widget.currentActivities.map((a) => a.name.toLowerCase()).toSet();
                  return widget.previousActivityNames.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase()) &&
                        !currentActivityNames.contains(option.toLowerCase());
                  });
                },
                onSelected: (String selection) async {
                  _nameController.text = selection;

                  // Pre-fill duration from Hive if available
                  final savedActivity = await ActivityPreferencesService.getActivity(selection);
                  if (savedActivity != null) {
                    _durationController.text = savedActivity.usualDurationMinutes.toString();
                  }
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  _nameController.text = controller.text;
                  _nameController.selection = controller.selection;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(color: secondaryColor),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Activity Name',
                      labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                      hintText: 'e.g., Kayaking, Cycling, Taekwondo',
                      hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: secondaryColor, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an activity name';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _nameController.text = value;
                    },
                  );
                },
              ),

              SizedBox(height: 16),

              // Duration
              TextFormField(
                controller: _durationController,
                style: TextStyle(color: secondaryColor),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Duration (minutes)',
                  labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                  hintText: 'e.g., 45',
                  hintStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: secondaryColor, width: 2),
                  ),
                ),
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

              SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                style: TextStyle(color: secondaryColor),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: TextStyle(color: secondaryColor.withValues(alpha: 0.7)),
                  hintText: 'Any additional details...',
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

              // Add button
              Center(
                child: ElevatedButton(
                  onPressed: _submitActivity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    'Add Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
