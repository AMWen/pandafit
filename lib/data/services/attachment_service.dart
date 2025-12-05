import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:printing/printing.dart';
import '../models/activity_attachment.dart';
import '../../utils/ui_helpers.dart';

// Service for handling activity attachments
//
// Supports:
// - PDF files: Generates thumbnail from first page
// - Images (JPEG, PNG): Compresses and generates thumbnail
//
// Storage strategy:
// - Thumbnail: ≤50KB for export/import, 400x560 dimensions
// - Full file: Stored if original < 500KB
// - Compressed file: If original ≥500KB, compress to <600KB with variable quality
class AttachmentService {
  static const int maxThumbnailSize = 50 * 1024; // 50KB for export/import
  static const int maxFullFileSizeUncompressed = 500 * 1024; // 500KB - store as-is
  static const int maxCompressedFileSize = 600 * 1024; // 600KB - compression target
  static const int thumbnailWidth = 400;
  static const int thumbnailHeight = 560;

  // Maximum total base64 size for all attachments in a single activity (1.9MB)
  // This prevents SQLite row size limits (2MB CursorWindow) from being exceeded
  static const int maxTotalAttachmentsBase64Size = 1950 * 1024;

  // Error message for size limit exceeded
  static String get sizeExceededErrorMessage {
    final limitMB = maxTotalAttachmentsBase64Size / (1024 * 1024);
    return 'Cannot add attachment: total size would exceed ${limitMB.toStringAsFixed(1)} MB limit per activity';
  }

  // Warning message when thumbnail-only is added
  static const String thumbnailOnlyWarning =
      'Attachment added (preview only) - full file too large for database limit';

  // Pick and process a file attachment
  // Returns null if user cancels or error occurs
  // Shows error message to user if file is unsupported
  // keepFullSize: whether to store the full file (default varies by type)
  static Future<ActivityAttachment?> pickAttachment({bool? keepFullSize}) async {
    try {
      // Pick file with data loading for cloud file support
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Load bytes immediately
      );

      if (result == null || result.files.isEmpty) {
        return null; // User canceled
      }

      final platformFile = result.files.first;

      // Get file bytes (works for both local and cloud files)
      Uint8List? bytes = platformFile.bytes;
      if (bytes == null) {
        if (platformFile.path == null) {
          throw Exception('Unable to access file. Try downloading to device first.');
        }
        bytes = await File(platformFile.path!).readAsBytes();
      }

      final fileName = platformFile.name;
      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      final originalSize = bytes.length;

      // Determine default for keepFullSize based on file type if not specified
      bool shouldKeepFullSize = keepFullSize ?? (mimeType == 'application/pdf');

      // Generate thumbnail and optionally store full file
      String thumbnailBase64;
      String? fullFileBase64;

      if (mimeType.startsWith('image/')) {
        // Process image
        final result = await _processImage(bytes, originalSize, shouldKeepFullSize);
        thumbnailBase64 = result.thumbnail;
        fullFileBase64 = result.fullFile;
      } else if (mimeType == 'application/pdf') {
        // Process PDF
        final result = await _processPdf(bytes, originalSize, shouldKeepFullSize);
        thumbnailBase64 = result.thumbnail;
        fullFileBase64 = result.fullFile;
      } else {
        throw Exception('Unsupported file type: $mimeType');
      }

      return ActivityAttachment(
        fileName: fileName,
        mimeType: mimeType,
        thumbnailBase64: thumbnailBase64,
        fullFileBase64: fullFileBase64,
        attachedDate: DateTime.now(),
        originalSizeBytes: originalSize,
      );
    } catch (e) {
      // Re-throw exception for caller to handle
      rethrow;
    }
  }

  // Process image file: compress and generate thumbnail
  static Future<_ProcessedFile> _processImage(
    Uint8List bytes,
    int originalSize,
    bool keepFullSize,
  ) async {
    // Decode image
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Unable to decode image');
    }

    // Generate and compress thumbnail
    String thumbnailBase64 = _generateThumbnailBase64(image);

    // Store full file based on preference and size
    String? fullFileBase64;

    if (keepFullSize) {
      if (originalSize < maxFullFileSizeUncompressed) {
        // Original is < 500KB - store as-is without compression
        fullFileBase64 = base64Encode(bytes);
      } else {
        // Original ≥ 500KB - try to compress to < 1MB with variable quality
        final Uint8List? compressed = _compressImageToTarget(image, originalSize);
        if (compressed != null) {
          fullFileBase64 = base64Encode(compressed);
        }
        // If compression failed (returned null), fullFileBase64 stays null
      }
    }
    // else: keepFullSize is false, so fullFileBase64 stays null (thumbnail only)

    return _ProcessedFile(thumbnail: thumbnailBase64, fullFile: fullFileBase64);
  }

  // Process PDF file: generate thumbnail from first page
  static Future<_ProcessedFile> _processPdf(
    Uint8List bytes,
    int originalSize,
    bool keepFullSize,
  ) async {
    try {
      // Render first page of PDF to image
      // Use a higher DPI for better quality, then resize
      final pageImageStream = Printing.raster(
        bytes,
        pages: [0], // First page only
        dpi: 150, // Good quality for thumbnail
      );

      // Get the first page from the stream
      final firstPage = await pageImageStream.first;

      // Convert PDF raster image to img.Image
      // Get properly aligned byte buffer from pixels
      final pixelBytes = Uint8List.fromList(firstPage.pixels);

      final imgData = img.Image.fromBytes(
        width: firstPage.width,
        height: firstPage.height,
        bytes: pixelBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      // Create a white background
      final whiteBackground = img.Image(
        width: firstPage.width,
        height: firstPage.height,
        numChannels: 4,
      );
      img.fill(whiteBackground, color: img.ColorRgb8(255, 255, 255));

      // Composite your page on top of the white background
      final composited = img.compositeImage(whiteBackground, imgData, dstX: 0, dstY: 0);

      // Generate and compress thumbnail
      String thumbnailBase64 = _generateThumbnailBase64(composited);

      // Store full PDF if preference is enabled and size permits
      String? fullFileBase64;
      if (keepFullSize && originalSize < maxCompressedFileSize) {
        fullFileBase64 = base64Encode(bytes);
      }

      return _ProcessedFile(thumbnail: thumbnailBase64, fullFile: fullFileBase64);
    } catch (e) {
      // If PDF rendering fails, create a placeholder thumbnail
      throw Exception('Failed to render PDF: $e');
    }
  }

  // Compress image to target size (<1MB) with variable quality based on original size
  static Uint8List? _compressImageToTarget(img.Image image, int originalSize) {
    // Calculate initial quality based on original size
    // Smaller files (600KB): start with higher quality (85)
    // Larger files (5MB+): start with lower quality (60)
    int jpegQuality;
    if (originalSize < 1024 * 1024) {
      // < 1MB: light compression
      jpegQuality = 85;
    } else if (originalSize < 3 * 1024 * 1024) {
      // 1-3MB: medium compression
      jpegQuality = 75;
    } else {
      // ≥ 3MB: aggressive compression
      jpegQuality = 60;
    }

    // Try JPEG compression with progressively lower quality
    Uint8List jpegCompressed = img.encodeJpg(image, quality: jpegQuality);

    jpegQuality -= 10;
    while (jpegCompressed.length > maxCompressedFileSize && jpegQuality > 40) {
      jpegCompressed = img.encodeJpg(image, quality: jpegQuality);
      jpegQuality -= 10;
    }

    // If JPEG already fits under target, just use it (skip PNG entirely)
    if (jpegCompressed.length <= maxCompressedFileSize) {
      return jpegCompressed;
    }

    // Try PNG compression only if JPEG didn't fit
    Uint8List pngCompressed = img.encodePng(image, level: 8); // 8 is pretty high compression

    // If PNG fits, use it
    if (pngCompressed.length <= maxCompressedFileSize) {
      return pngCompressed;
    }
    // Return smaller of the two, even if neither fits
    else {
      return jpegCompressed.length < pngCompressed.length ? jpegCompressed : pngCompressed;
    }
  }

  // Generate and compress thumbnail to base64
  // Resizes to 400x560 and compresses to <50KB
  static String _generateThumbnailBase64(img.Image image) {
    final thumbnail = _generateImageThumbnail(image);

    // Try to get thumbnail under 50KB with progressive quality reduction
    int quality = 80;
    Uint8List thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);
    quality -= 10;

    while (thumbnailBytes.length > maxThumbnailSize && quality > 40) {
      quality -= 10;
      thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);
    }

    return base64Encode(thumbnailBytes);
  }

  // Generate thumbnail image (400x560, maintain aspect ratio)
  static img.Image _generateImageThumbnail(img.Image image) {
    final aspectRatio = image.width / image.height;
    final targetRatio = thumbnailWidth / thumbnailHeight;

    int newWidth, newHeight;

    if (aspectRatio > targetRatio) {
      // Image is wider than target
      newWidth = thumbnailWidth;
      newHeight = (thumbnailWidth / aspectRatio).round();
    } else {
      // Image is taller than target
      newHeight = thumbnailHeight;
      newWidth = (thumbnailHeight * aspectRatio).round();
    }

    return img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.average,
    );
  }

  // Decode base64 attachment data to bytes
  static Uint8List decodeAttachment(String base64Data) {
    return base64Decode(base64Data);
  }

  // Get file size display string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Calculate total base64 size of all attachments
  static int calculateTotalAttachmentSize(List<ActivityAttachment> attachments) {
    int totalSize = 0;
    for (final attachment in attachments) {
      totalSize += attachment.thumbnailBase64.length;
      if (attachment.fullFileBase64 != null) {
        totalSize += attachment.fullFileBase64!.length;
      }
    }
    return totalSize;
  }

  // Check if adding a new attachment would exceed the size limit
  static bool canAddAttachment(
    List<ActivityAttachment> existingAttachments,
    ActivityAttachment newAttachment,
  ) {
    final currentSize = calculateTotalAttachmentSize(existingAttachments);
    final newSize =
        newAttachment.thumbnailBase64.length + (newAttachment.fullFileBase64?.length ?? 0);
    return (currentSize + newSize) <= maxTotalAttachmentsBase64Size;
  }

  // Check if adding just the thumbnail would fit
  static bool canAddThumbnailOnly(
    List<ActivityAttachment> existingAttachments,
    ActivityAttachment newAttachment,
  ) {
    final currentSize = calculateTotalAttachmentSize(existingAttachments);
    final thumbnailSize = newAttachment.thumbnailBase64.length;
    return (currentSize + thumbnailSize) <= maxTotalAttachmentsBase64Size;
  }

  // Create a thumbnail-only version of an attachment (removes full file)
  static ActivityAttachment createThumbnailOnly(ActivityAttachment attachment) {
    return attachment.clearFullFile();
  }

  /// Validates and adds an attachment to an existing list with size checks
  ///
  /// Shows snackbar messages automatically when size limits are exceeded.
  /// Returns the list of attachments to add, or null if validation failed.
  static List<ActivityAttachment>? tryAddAttachment({
    required BuildContext context,
    required List<ActivityAttachment> existingAttachments,
    required ActivityAttachment newAttachment,
  }) {
    // Check if full attachment fits
    if (canAddAttachment(existingAttachments, newAttachment)) {
      return [newAttachment];
    }

    // Try thumbnail only if full attachment is too large
    if (canAddThumbnailOnly(existingAttachments, newAttachment)) {
      final thumbnailOnly = createThumbnailOnly(newAttachment);
      showSnackbar(context, thumbnailOnlyWarning, isError: true);
      return [thumbnailOnly];
    }

    // Exceeded limit even with thumbnail only
    showSnackbar(context, sizeExceededErrorMessage, isError: true);
    return null;
  }
}

// Internal class for processed file results
class _ProcessedFile {
  final String thumbnail;
  final String? fullFile;

  _ProcessedFile({required this.thumbnail, this.fullFile});
}
