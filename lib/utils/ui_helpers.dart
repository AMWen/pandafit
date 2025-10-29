import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/constants.dart';

/// UI helper functions and reusable widgets

/// Shows a snackbar with the given message
void showSnackbar(BuildContext context, String message, {Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration ?? const Duration(seconds: 2),
    ),
  );
}

/// Builds a completion message container with consistent styling
Widget buildCompletionMessage({
  required String title,
  required VoidCallback onUndo,
  EdgeInsets? margin,
}) {
  return Container(
    margin: margin ?? const EdgeInsets.all(16),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    decoration: BoxDecoration(
      color: Colors.green[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green[300]!, width: 2),
    ),
    child: Column(
      children: [
        Icon(Icons.check_circle, color: Colors.green[700], size: 48),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.green[900],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          "You're killing it!",
          style: TextStyle(
            fontSize: 16,
            color: Colors.green[700],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onUndo,
          icon: const Icon(Icons.undo, size: 14),
          label: const Text('undo', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ),
  );
}

/// Styled text input widget with consistent decoration
Widget settingsTextInput({
  required TextEditingController controller,
  String? labelText,
  String? hintText,
  bool isNumeric = false,
  bool allowDecimal = false,
  int maxLines = 1,
  TextCapitalization textCapitalization = TextCapitalization.none,
}) {
  return TextField(
    controller: controller,
    keyboardType: isNumeric
        ? (allowDecimal ? TextInputType.numberWithOptions(decimal: true) : TextInputType.number)
        : TextInputType.text,
    maxLines: maxLines,
    textCapitalization: textCapitalization,
    inputFormatters: isNumeric
        ? (allowDecimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : [FilteringTextInputFormatter.digitsOnly])
        : null,
    decoration: InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyles.hintText,
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
      border: InputBorder.none,
    ),
    style: TextStyles.inputText,
  );
}
