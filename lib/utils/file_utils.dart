import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> pickLocation(List<String> allowedExtensions) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
  );
  final filePath = result?.files.first.path;
  return filePath;
}

Future<String> saveWorkoutAsCsv(String fileName, String csvString) async {
  try {
    String? file = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csvString)),
    );

    if (file != null) {
      return 'Workout exported successfully!';
    }
    else {
      return 'Export canceled';
    }
  } catch (e) {
    return 'Error exporting workout: $e';
  }
}
