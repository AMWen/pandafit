import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
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
    final isEditable = widget.onAttachmentsChanged != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activityName} - Attachments'),
        backgroundColor: primaryColor,
        actions: [
          if (isEditable)
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
                      'Original: ${AttachmentService.formatFileSize(attachment.originalSizeBytes)}',
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
                              'Thumbnail only (file too large)',
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
class _FullAttachmentView extends StatefulWidget {
  final ActivityAttachment attachment;
  final VoidCallback onDelete;

  const _FullAttachmentView({
    required this.attachment,
    required this.onDelete,
  });

  @override
  State<_FullAttachmentView> createState() => _FullAttachmentViewState();
}

class _FullAttachmentViewState extends State<_FullAttachmentView> {
  PdfControllerPinch? _pdfController;
  bool _isPdfLoading = false;

  @override
  void initState() {
    super.initState();
    final hasStoredFile = widget.attachment.fullFileBase64 != null;
    final isPdf = widget.attachment.mimeType == 'application/pdf';

    // Initialize PDF controller if we have a stored PDF
    if (isPdf && hasStoredFile) {
      _initializePdfController();
    }
  }

  Future<void> _initializePdfController() async {
    setState(() => _isPdfLoading = true);
    try {
      final pdfBytes = base64Decode(widget.attachment.fullFileBase64!);
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(pdfBytes),
      );
      // Wait for the document to load to catch any errors
      await _pdfController!.document;
    } catch (e) {
      // If PDF loading fails, controller stays null and we'll show thumbnail
      debugPrint('Failed to load PDF: $e');
      _pdfController?.dispose();
      _pdfController = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load PDF viewer. Showing preview instead.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPdfLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasStoredFile = widget.attachment.fullFileBase64 != null;
    final storedFileSize = hasStoredFile
        ? (widget.attachment.fullFileBase64!.length * 3 / 4).round() // base64 to bytes approximation
        : 0;
    final isPdf = widget.attachment.mimeType == 'application/pdf';
    final canShowStoredFile = hasStoredFile && !isPdf; // Images only
    final canShowPdf = isPdf && _pdfController != null; // PDF with loaded controller

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.attachment.fileName),
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
                        widget.onDelete();
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
          if (isPdf && !hasStoredFile)
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
                      'Showing first page preview. Original PDF (${AttachmentService.formatFileSize(widget.attachment.originalSizeBytes)}) too large to store.',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!canShowStoredFile && !isPdf)
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
                      'Showing thumbnail only. Original file (${AttachmentService.formatFileSize(widget.attachment.originalSizeBytes)}) too large to store.',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Content view - PDF or Image
          Expanded(
            child: _isPdfLoading
                ? Center(child: CircularProgressIndicator())
                : canShowPdf
                    ? PdfViewPinch(controller: _pdfController!)
                    : InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.memory(
                            base64Decode(
                              canShowStoredFile ? widget.attachment.fullFileBase64! : widget.attachment.thumbnailBase64,
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
                        widget.attachment.fileName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    if (isPdf) ...[
                      _InfoChip(
                        icon: Icons.picture_as_pdf,
                        label: 'PDF ${hasStoredFile ? AttachmentService.formatFileSize(storedFileSize) : AttachmentService.formatFileSize(widget.attachment.originalSizeBytes)}',
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      _InfoChip(
                        icon: canShowPdf ? Icons.chrome_reader_mode : Icons.preview,
                        label: canShowPdf ? 'Scrollable' : 'Preview only',
                        color: canShowPdf ? Colors.green : Colors.orange,
                      ),
                    ] else ...[
                      _InfoChip(
                        icon: Icons.data_usage,
                        label: hasStoredFile
                            ? AttachmentService.formatFileSize(storedFileSize)
                            : AttachmentService.formatFileSize(widget.attachment.originalSizeBytes),
                      ),
                      SizedBox(width: 8),
                      _InfoChip(
                        icon: hasStoredFile ? Icons.check_circle : Icons.image,
                        label: hasStoredFile
                            ? (storedFileSize < widget.attachment.originalSizeBytes ? 'Compressed' : 'Stored')
                            : 'Thumbnail only',
                        color: hasStoredFile ? Colors.green : Colors.orange,
                      ),
                    ],
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
