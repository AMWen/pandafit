import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import '../constants.dart';
import '../models/activity_model.dart';
import '../models/activity_attachment.dart';
import '../services/activity_preferences_service.dart';
import '../services/attachment_service.dart';
import 'attachment_viewer.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isReadOnly;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onDelete,
    this.onEdit,
    this.isReadOnly = false,
  });

  void _viewAttachments(BuildContext context) {
    if (activity.attachments != null && activity.attachments!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AttachmentViewer(
            attachments: activity.attachments!,
            activityName: activity.name,
          ),
        ),
      );
    }
  }

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
                  // Attachments indicator
                  if (activity.attachments != null && activity.attachments!.isNotEmpty) ...[
                    SizedBox(height: 8),
                    InkWell(
                      onTap: () => _viewAttachments(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_file, size: 14, color: secondaryColor.withValues(alpha: 0.7)),
                            SizedBox(width: 4),
                            Text(
                              '${activity.attachments!.length} attachment${activity.attachments!.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: secondaryColor.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new, size: 12, color: secondaryColor.withValues(alpha: 0.6)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Edit and Delete buttons (only for non-completed activities)
            if (!isReadOnly) ...[
              if (onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: secondaryColor),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: ActionColors.delete),
                  onPressed: onDelete,
                  tooltip: 'Remove',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ActivityInputWidget extends StatefulWidget {
  final Function(Activity) onAdd;
  final Function(bool)? onFormChanged;
  final List<String> previousActivityNames;
  final List<Activity> currentActivities;

  const ActivityInputWidget({
    super.key,
    required this.onAdd,
    this.onFormChanged,
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
  final _durationFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();
  FocusNode? _autocompleteFocusNode;
  TextEditingController? _autocompleteController;
  final List<ActivityAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _durationFocusNode.addListener(_onFocusChanged);
    _notesFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _durationFocusNode.removeListener(_onFocusChanged);
    _notesFocusNode.removeListener(_onFocusChanged);
    _autocompleteFocusNode?.removeListener(_onFocusChanged);
    _durationFocusNode.dispose();
    _notesFocusNode.dispose();
    _nameController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final hasFocus = (_autocompleteFocusNode?.hasFocus ?? false) ||
                     _durationFocusNode.hasFocus ||
                     _notesFocusNode.hasFocus;
    widget.onFormChanged?.call(hasFocus);
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
          ),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void submitActivity() {
    if (_formKey.currentState!.validate()) {
      final activity = Activity.create(
        name: _nameController.text.trim(),
        durationMinutes: int.parse(_durationController.text),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        attachments: _attachments.isNotEmpty ? List.from(_attachments) : null,
      );

      widget.onAdd(activity);

      // Clear form
      _nameController.clear();
      _autocompleteController?.clear();
      _durationController.clear();
      _notesController.clear();
      _attachments.clear();
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

                  // Store reference to autocomplete's controller and focus node
                  _autocompleteController = controller;

                  if (_autocompleteFocusNode != focusNode) {
                    _autocompleteFocusNode?.removeListener(_onFocusChanged);
                    _autocompleteFocusNode = focusNode;
                    _autocompleteFocusNode!.addListener(_onFocusChanged);
                  }

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
                focusNode: _durationFocusNode,
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
                focusNode: _notesFocusNode,
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

              // Attachments section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attachments',
                    style: TextStyle(
                      color: secondaryColor.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickAttachment,
                    icon: Icon(Icons.attach_file, size: 18, color: secondaryColor),
                    label: Text('Add File', style: TextStyle(color: secondaryColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: secondaryColor.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),

              // List of attachments
              if (_attachments.isNotEmpty) ...[
                SizedBox(height: 8),
                ...List.generate(_attachments.length, (index) {
                  final attachment = _attachments[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: secondaryColor.withValues(alpha: 0.3)),
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
                                  color: secondaryColor,
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
                                  color: secondaryColor.withValues(alpha: 0.6),
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
      ),
    );
  }
}
