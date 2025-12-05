import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:file_picker/file_picker.dart';
import '../models/activity_attachment.dart';
import '../constants.dart';
import '../services/attachment_service.dart';
import '../../utils/ui_helpers.dart';
import 'attachment_options_dialog.dart';

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
  bool _isProcessingAttachment = false;

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

  void _removeFullFile(int index) {
    final attachment = _attachments[index];
    if (attachment.fullFileBase64 != null) {
      setState(() {
        _attachments[index] = AttachmentService.createThumbnailOnly(attachment);
      });
      widget.onAttachmentsChanged?.call(_attachments);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _attachments.removeAt(oldIndex);
      _attachments.insert(newIndex, item);
    });
    widget.onAttachmentsChanged?.call(_attachments);
  }


  Future<void> _addAttachment() async {
    // Show dialog to let user choose whether to keep full-size file
    final keepFullSize = await showAttachmentOptionsDialog(context);

    if (keepFullSize == null) return; // User canceled

    setState(() => _isProcessingAttachment = true);
    try {
      final attachment = await AttachmentService.pickAttachment(keepFullSize: keepFullSize);
      if (attachment != null && mounted) {
        final attachmentsToAdd = AttachmentService.tryAddAttachment(
          context: context,
          existingAttachments: _attachments,
          newAttachment: attachment,
        );

        if (attachmentsToAdd != null) {
          setState(() {
            _attachments.addAll(attachmentsToAdd);
          });
          widget.onAttachmentsChanged?.call(_attachments);
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, 'Error adding attachment: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAttachment = false);
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
              icon: _isProcessingAttachment
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.add_photo_alternate),
              onPressed: _isProcessingAttachment ? null : _addAttachment,
              tooltip: _isProcessingAttachment ? 'Processing...' : 'Add attachment',
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
                    onPressed: _isProcessingAttachment ? null : _addAttachment,
                    icon: _isProcessingAttachment
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.add),
                    label: Text(_isProcessingAttachment ? 'Processing...' : 'Add Attachment'),
                    style: primaryButtonStyle,
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _attachments.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final attachment = _attachments[index];
                return _AttachmentCard(
                  key: ValueKey('${attachment.attachedDate.millisecondsSinceEpoch}_$index'),
                  attachment: attachment,
                  onTap: () => _viewAttachment(context, index),
                  onDelete: isEditable ? () => _deleteAttachment(index) : null,
                  onRemoveFullFile: isEditable ? () => _removeFullFile(index) : null,
                  hasFullFile: attachment.fullFileBase64 != null,
                  showReorderHandle: isEditable,
                  reorderIndex: index,
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
          attachments: _attachments,
          initialIndex: index,
          onDelete: (deleteIndex) {
            Navigator.pop(context);
            _deleteAttachment(deleteIndex);
          },
          onRemoveFullFile: (removeIndex) {
            Navigator.pop(context);
            _removeFullFile(removeIndex);
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
  final VoidCallback? onDelete;
  final VoidCallback? onRemoveFullFile;
  final bool hasFullFile;
  final bool showReorderHandle;
  final int? reorderIndex;

  const _AttachmentCard({
    super.key,
    required this.attachment,
    required this.onTap,
    this.onDelete,
    this.onRemoveFullFile,
    required this.hasFullFile,
    this.showReorderHandle = false,
    this.reorderIndex,
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
              if (onDelete != null)
                IconButton(
                icon: Icon(Icons.delete_outline, color: ActionColors.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _AttachmentDeleteDialog(
                      attachment: attachment,
                      onDelete: onDelete!,
                      onRemoveFullFile: onRemoveFullFile,
                    ),
                  );
                },
                tooltip: 'Delete attachment',
              ),
              // Reorder handle (3 vertical dots)
              if (showReorderHandle && reorderIndex != null)
                ReorderableDragStartListener(
                  index: reorderIndex!,
                  child: Icon(Icons.drag_indicator, color: Colors.grey[600], size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen attachment view
class _FullAttachmentView extends StatefulWidget {
  final List<ActivityAttachment> attachments;
  final int initialIndex;
  final Function(int) onDelete;
  final Function(int) onRemoveFullFile;

  const _FullAttachmentView({
    required this.attachments,
    required this.initialIndex,
    required this.onDelete,
    required this.onRemoveFullFile,
  });

  @override
  State<_FullAttachmentView> createState() => _FullAttachmentViewState();
}

class _FullAttachmentViewState extends State<_FullAttachmentView> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, PdfControllerPinch?> _pdfControllers = {};
  final Map<int, bool> _pdfLoadingStates = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Initialize PDF controller for current page if needed
    _initializePdfControllerForIndex(_currentIndex);
  }

  Future<void> _initializePdfControllerForIndex(int index) async {
    final attachment = widget.attachments[index];
    final hasStoredFile = attachment.fullFileBase64 != null;
    final isPdf = attachment.mimeType == 'application/pdf';

    if (!isPdf || !hasStoredFile) return;

    setState(() => _pdfLoadingStates[index] = true);
    try {
      final pdfBytes = base64Decode(attachment.fullFileBase64!);
      _pdfControllers[index] = PdfControllerPinch(
        document: PdfDocument.openData(pdfBytes),
      );
      // Wait for the document to load to catch any errors
      await _pdfControllers[index]!.document;
    } catch (e) {
      // If PDF loading fails, controller stays null and we'll show thumbnail
      debugPrint('Failed to load PDF: $e');
      _pdfControllers[index]?.dispose();
      _pdfControllers[index] = null;
      if (mounted) {
        showSnackbar(context, 'Unable to load PDF viewer. Showing preview instead.');
      }
    } finally {
      if (mounted) {
        setState(() => _pdfLoadingStates[index] = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _pdfControllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Preload PDF for this page if needed
    _initializePdfControllerForIndex(index);
  }

  Future<void> _downloadAttachment() async {
    try {
      final attachment = widget.attachments[_currentIndex];

      // Use full file if available, otherwise use thumbnail
      final fileData = attachment.fullFileBase64 ?? attachment.thumbnailBase64;

      // Decode base64 to bytes
      List<int> bytes;
      try {
        bytes = base64Decode(fileData);
      } catch (e) {
        throw Exception('Failed to decode file data: $e');
      }

      // Get file extension from mime type or filename
      String extension = '';
      if (attachment.mimeType == 'application/pdf') {
        extension = '.pdf';
      } else if (attachment.mimeType.startsWith('image/jpeg') || attachment.fileName.toLowerCase().endsWith('.jpg') || attachment.fileName.toLowerCase().endsWith('.jpeg')) {
        extension = '.jpg';
      } else if (attachment.mimeType.startsWith('image/png') || attachment.fileName.toLowerCase().endsWith('.png')) {
        extension = '.png';
      }

      // Default filename
      final defaultFileName = attachment.fileName.replaceAll(RegExp(r'\.(jpg|jpeg|png|pdf)$', caseSensitive: false), '') + extension;

      // Let user choose save location
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Attachment',
        fileName: defaultFileName,
        type: FileType.any,
        bytes: Uint8List.fromList(bytes),
      );

      if (outputFile != null) {
        // On some platforms, saveFile already writes the bytes
        // On others, we need to write them manually
        try {
          final file = File(outputFile);
          if (!await file.exists() || await file.length() == 0) {
            await file.writeAsBytes(bytes);
          }
        } catch (e) {
          // File might already be written by FilePicker
        }

        if (mounted) {
          showSnackbar(
            context,
            'Downloaded ${attachment.fullFileBase64 != null ? "full file" : "thumbnail"}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, 'Error downloading attachment: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAttachment = widget.attachments[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} of ${widget.attachments.length}'),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _downloadAttachment,
            tooltip: 'Download attachment',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _AttachmentDeleteDialog(
                  attachment: currentAttachment,
                  onDelete: () {
                    widget.onDelete(_currentIndex);
                  },
                  onRemoveFullFile: () {
                    widget.onRemoveFullFile(_currentIndex);
                  },
                ),
              );
            },
            tooltip: 'Delete attachment',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.attachments.length,
        itemBuilder: (context, index) {
          return _buildAttachmentPage(index);
        },
      ),
    );
  }

  Widget _buildAttachmentPage(int index) {
    final attachment = widget.attachments[index];
    final hasStoredFile = attachment.fullFileBase64 != null;
    final storedFileSize = hasStoredFile
        ? (attachment.fullFileBase64!.length * 3 / 4).round() // base64 to bytes approximation
        : 0;
    final isPdf = attachment.mimeType == 'application/pdf';
    final canShowStoredFile = hasStoredFile && !isPdf; // Images only
    final pdfController = _pdfControllers[index];
    final canShowPdf = isPdf && pdfController != null; // PDF with loaded controller
    final isPdfLoading = _pdfLoadingStates[index] ?? false;

    return Column(
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
                    'Showing first page preview. Original PDF (${AttachmentService.formatFileSize(attachment.originalSizeBytes)}) too large to store.',
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
                    'Showing thumbnail only. Original file (${AttachmentService.formatFileSize(attachment.originalSizeBytes)}) too large to store.',
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
          child: isPdfLoading
              ? Center(child: CircularProgressIndicator())
              : canShowPdf
                  ? PdfViewPinch(controller: pdfController)
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.memory(
                          base64Decode(
                            canShowStoredFile ? attachment.fullFileBase64! : attachment.thumbnailBase64,
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
                      label: 'PDF ${hasStoredFile ? AttachmentService.formatFileSize(storedFileSize) : AttachmentService.formatFileSize(attachment.originalSizeBytes)}',
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
                          : AttachmentService.formatFileSize((attachment.thumbnailBase64.length * 3 / 4).round()),
                    ),
                    SizedBox(width: 8),
                    _InfoChip(
                      icon: hasStoredFile ? Icons.check_circle : Icons.image,
                      label: hasStoredFile
                          ? (storedFileSize < attachment.originalSizeBytes ? 'Compressed' : 'Stored')
                          : 'Thumbnail',
                      color: hasStoredFile ? Colors.green : Colors.orange,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reusable delete attachment dialog
class _AttachmentDeleteDialog extends StatelessWidget {
  final ActivityAttachment attachment;
  final VoidCallback onDelete;
  final VoidCallback? onRemoveFullFile;

  const _AttachmentDeleteDialog({
    required this.attachment,
    required this.onDelete,
    this.onRemoveFullFile,
  });

  @override
  Widget build(BuildContext context) {
    final hasFullFile = attachment.fullFileBase64 != null;

    return AlertDialog(
      title: Text('Delete Attachment', style: TextStyles.dialogTitle),
      content: Text(hasFullFile && onRemoveFullFile != null
          ? 'What would you like to do with this attachment?'
          : 'Are you sure you want to delete this attachment?'),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            // Show "Remove full file" option if attachment has full file
            if (hasFullFile && onRemoveFullFile != null) ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRemoveFullFile!();
                },
                child: Text(
                  'Remove\nfull file',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              SizedBox(width: 8),
            ],
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
      ],
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

