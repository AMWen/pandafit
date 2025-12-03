import 'package:flutter/material.dart';
import '../constants.dart';

/// Dialog to choose attachment storage options before adding
/// Returns true for "Keep Full File", false for "Thumbnail Only", null if canceled
Future<bool?> showAttachmentOptionsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _AttachmentOptionsDialog(),
  );
}

class _AttachmentOptionsDialog extends StatelessWidget {
  const _AttachmentOptionsDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Attachment', style: TextStyles.dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How should this attachment be stored?',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          SizedBox(height: 20),
          // Thumbnail only option
          InkWell(
            onTap: () => Navigator.pop(context, false),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_outlined, color: primaryColor, size: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thumbnail Only',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Recommended for images\nPrevents crashes on low-memory devices',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          // Full file option
          InkWell(
            onTap: () => Navigator.pop(context, true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.file_present, color: primaryColor, size: 28),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keep Full File',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Necessary for scrollable PDFs\nBetter quality but uses more storage',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          // Info note about size limits
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[900]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note: Very large files may still be stored as thumbnails only due to database size limits.',
                    style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
