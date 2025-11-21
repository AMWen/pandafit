import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:printing/printing.dart';
import '../models/activity_attachment.dart';

/// Service for handling activity attachments
///
/// Supports:
/// - PDF files: Generates thumbnail from first page
/// - Images (JPEG, PNG): Compresses and generates thumbnail
///
/// Storage strategy:
/// - Thumbnail: Always ≤20KB (fallback to 50KB if needed), stored in Excel
/// - Full file: Only stored if ≤50KB, otherwise thumbnail only
class AttachmentService {
  static const int maxThumbnailSize = 20 * 1024; // 20KB target
  static const int maxThumbnailSizeFallback = 50 * 1024; // 50KB fallback
  static const int maxFullFileSize = 50 * 1024; // 50KB
  static const int thumbnailWidth = 200;
  static const int thumbnailHeight = 280;

  /// Pick and process a file attachment
  ///
  /// Returns null if user cancels or error occurs
  /// Shows error message to user if file is unsupported
  static Future<ActivityAttachment?> pickAttachment() async {
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

      // Generate thumbnail and optionally store full file
      String thumbnailBase64;
      String? fullFileBase64;

      if (mimeType.startsWith('image/')) {
        // Process image
        final result = await _processImage(bytes, originalSize);
        thumbnailBase64 = result.thumbnail;
        fullFileBase64 = result.fullFile;
      } else if (mimeType == 'application/pdf') {
        // Process PDF
        final result = await _processPdf(bytes, originalSize);
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

  /// Process image file: compress and generate thumbnail
  static Future<_ProcessedFile> _processImage(
    Uint8List bytes,
    int originalSize,
  ) async {
    // Decode image
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Unable to decode image');
    }

    // Generate thumbnail (200x280, maintain aspect ratio)
    final thumbnail = _generateImageThumbnail(image);
    final thumbnailBytes = img.encodeJpg(thumbnail, quality: 60);
    String thumbnailBase64 = base64Encode(thumbnailBytes);

    // If thumbnail exceeds 20KB, try lower quality
    if (thumbnailBytes.length > maxThumbnailSize) {
      final lowerQuality = img.encodeJpg(thumbnail, quality: 45);
      if (lowerQuality.length <= maxThumbnailSizeFallback) {
        thumbnailBase64 = base64Encode(lowerQuality);
      }
    }

    // Store full file if small enough - try both PNG and JPEG, use smaller
    String? fullFileBase64;
    if (originalSize <= maxFullFileSize) {
      final compressedJpeg = img.encodeJpg(image, quality: 75);
      final compressedPng = img.encodePng(image, level: 9); // Max compression

      // Use the smaller format that fits within limit
      if (compressedJpeg.length <= maxFullFileSize && compressedPng.length <= maxFullFileSize) {
        // Both fit - use smaller one
        fullFileBase64 = base64Encode(compressedJpeg.length < compressedPng.length ? compressedJpeg : compressedPng);
      } else if (compressedJpeg.length <= maxFullFileSize) {
        fullFileBase64 = base64Encode(compressedJpeg);
      } else if (compressedPng.length <= maxFullFileSize) {
        fullFileBase64 = base64Encode(compressedPng);
      }
    }

    return _ProcessedFile(
      thumbnail: thumbnailBase64,
      fullFile: fullFileBase64,
    );
  }

  /// Process PDF file: generate thumbnail from first page
  static Future<_ProcessedFile> _processPdf(
    Uint8List bytes,
    int originalSize,
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
      final imgData = img.Image.fromBytes(
        width: firstPage.width,
        height: firstPage.height,
        bytes: firstPage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4, // RGBA
      );

      // Resize to thumbnail dimensions
      final thumbnail = _generateImageThumbnail(imgData);

      // Encode as PNG first
      final pngBytes = img.encodePng(thumbnail);
      String thumbnailBase64 = base64Encode(pngBytes);

      // If thumbnail exceeds 20KB, compress as JPEG
      if (pngBytes.length > maxThumbnailSize) {
        final jpegBytes = img.encodeJpg(thumbnail, quality: 60);
        if (jpegBytes.length <= maxThumbnailSizeFallback) {
          thumbnailBase64 = base64Encode(jpegBytes);
        } else {
          // Try even lower quality
          final lowerJpeg = img.encodeJpg(thumbnail, quality: 40);
          thumbnailBase64 = base64Encode(lowerJpeg);
        }
      }

      // Store full PDF if small enough
      String? fullFileBase64;
      if (originalSize <= maxFullFileSize) {
        fullFileBase64 = base64Encode(bytes);
      }

      return _ProcessedFile(
        thumbnail: thumbnailBase64,
        fullFile: fullFileBase64,
      );
    } catch (e) {
      // If PDF rendering fails, create a placeholder thumbnail
      throw Exception('Failed to render PDF: $e');
    }
  }

  /// Generate thumbnail image (200x280, maintain aspect ratio)
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

  /// Decode base64 attachment data to bytes
  static Uint8List decodeAttachment(String base64Data) {
    return base64Decode(base64Data);
  }

  /// Get file size display string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Internal class for processed file results
class _ProcessedFile {
  final String thumbnail;
  final String? fullFile;

  _ProcessedFile({
    required this.thumbnail,
    this.fullFile,
  });
}
