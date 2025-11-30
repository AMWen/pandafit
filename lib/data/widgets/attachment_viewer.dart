import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/activity_attachment.dart';
import '../constants.dart';
import '../services/attachment_service.dart';

/// Widget to view and edit activity attachments
class AttachmentViewer extends StatefulWidget {
  final List<ActivityAttachment> attachments;
  final String activityName;
  final Function(List<ActivityAttachment>)? onAttachmentsChanged;

  const AttachmentViewer({
    super.key,
    required this.attachments,
    required this.activityName,
    this.onAttachmentsChanged,
  });

  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  late List<ActivityAttachment> _attachments;

  @override
  void initState() {
    super.initState();
    _attachments = List.from(widget.attachments);
  }

  void _deleteAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
    widget.onAttachmentsChanged?.call(_attachments);
  }

  Future<void> _addAttachment() async {
    try {
      final attachment = await AttachmentService.pickAttachment();
      if (attachment != null) {
        setState(() {
          _attachments.add(attachment);
        });
        widget.onAttachmentsChanged?.call(_attachments);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activityName} - Attachments'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.add_photo_alternate),
            onPressed: _addAttachment,
            tooltip: 'Add attachment',
          ),
        ],
      ),
      body: _attachments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_file_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No attachments',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _addAttachment,
                    icon: Icon(Icons.add),
                    label: Text('Add Attachment'),
                    style: primaryButtonStyle,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _attachments.length,
              itemBuilder: (context, index) {
                final attachment = _attachments[index];
                return _AttachmentCard(
                  attachment: attachment,
                  onTap: () => _viewAttachment(context, index),
                  onDelete: () => _deleteAttachment(index),
                );
              },
            ),
    );
  }

  void _viewAttachment(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullAttachmentView(
          attachment: _attachments[index],
          onDelete: () {
            Navigator.pop(context);
            _deleteAttachment(index);
          },
        ),
      ),
    );
  }
}

/// Card showing attachment summary
class _AttachmentCard extends StatelessWidget {
  final ActivityAttachment attachment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AttachmentCard({
    required this.attachment,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(attachment.thumbnailBase64),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 16),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Text(
                      AttachmentService.formatFileSize(attachment.originalSizeBytes),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (!attachment.isFullFileInExcel) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Thumbnail only (compressed file >50KB)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, color: ActionColors.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete Attachment'),
                      content: Text('Are you sure you want to delete this attachment?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: ActionColors.delete,
                          ),
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Delete attachment',
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen attachment view
class _FullAttachmentView extends StatelessWidget {
  final ActivityAttachment attachment;
  final VoidCallback onDelete;

  const _FullAttachmentView({
    required this.attachment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasFullFile = attachment.fullFileBase64 != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(attachment.fileName),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Delete Attachment'),
                  content: Text('Are you sure you want to delete this attachment?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: ActionColors.delete,
                      ),
                      child: Text('Delete'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Delete attachment',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          if (!hasFullFile)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[900], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing thumbnail only. Full file (${AttachmentService.formatFileSize(attachment.originalSizeBytes)}) too large.',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Image view
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  base64Decode(
                    hasFullFile ? attachment.fullFileBase64! : attachment.thumbnailBase64,
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // File info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insert_drive_file, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachment.fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.data_usage,
                      label: AttachmentService.formatFileSize(attachment.originalSizeBytes),
                    ),
                    SizedBox(width: 8),
                    _InfoChip(
                      icon: hasFullFile ? Icons.check_circle : Icons.image,
                      label: hasFullFile ? 'Full file' : 'Thumbnail',
                      color: hasFullFile ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Info chip widget
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey[700])?.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey[700]),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
