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
/// - Thumbnail: ≤50KB for export/import, 400x560 dimensions
/// - Full file: Stored if original < 500KB
/// - Compressed file: If original ≥500KB, compress to <1MB with variable quality
///   - Smaller files (e.g., 600KB): light compression
///   - Larger files (e.g., 5MB): aggressive compression
/// - No full file stored if can't compress to <1MB
class AttachmentService {
  static const int maxThumbnailSize = 50 * 1024; // 50KB for export/import
  static const int maxFullFileSizeUncompressed = 500 * 1024; // 500KB - store as-is
  static const int maxCompressedFileSize = 1024 * 1024; // 1MB - compression target
  static const int thumbnailWidth = 400;
  static const int thumbnailHeight = 560;

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

    // Generate and compress thumbnail
    String thumbnailBase64 = _generateThumbnailBase64(image);

    // Store full file based on size
    String? fullFileBase64;

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

      // Generate and compress thumbnail
      String thumbnailBase64 = _generateThumbnailBase64(imgData);

      // Store full PDF if < 1MB (can't compress PDFs further)
      String? fullFileBase64;
      if (originalSize < maxCompressedFileSize) {
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

  /// Compress image to target size (<1MB) with variable quality based on original size
  ///
  /// Tries both JPEG and PNG compression, returns smaller format
  /// Returns compressed bytes if successful, null if can't reach target
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

    while (jpegCompressed.length > maxCompressedFileSize && jpegQuality > 20) {
      jpegQuality -= 5;
      jpegCompressed = img.encodeJpg(image, quality: jpegQuality);
    }

    // Try PNG compression (start with high compression, reduce if needed)
    int pngLevel = 9; // Max compression
    Uint8List pngCompressed = img.encodePng(image, level: pngLevel);

    while (pngCompressed.length > maxCompressedFileSize && pngLevel > 0) {
      pngLevel -= 2;
      pngCompressed = img.encodePng(image, level: pngLevel);
    }

    // Use whichever format is smaller and under target
    Uint8List? result;
    if (jpegCompressed.length <= maxCompressedFileSize && pngCompressed.length <= maxCompressedFileSize) {
      // Both fit - use smaller
      result = jpegCompressed.length < pngCompressed.length ? jpegCompressed : pngCompressed;
    } else if (jpegCompressed.length <= maxCompressedFileSize) {
      result = jpegCompressed;
    } else if (pngCompressed.length <= maxCompressedFileSize) {
      result = pngCompressed;
    }

    return result; // null if neither format fits under target
  }

  /// Generate and compress thumbnail to base64
  /// Resizes to 400x560 and compresses to <50KB
  static String _generateThumbnailBase64(img.Image image) {
    final thumbnail = _generateImageThumbnail(image);

    // Try to get thumbnail under 50KB with progressive quality reduction
    int quality = 80;
    Uint8List thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);

    while (thumbnailBytes.length > maxThumbnailSize && quality > 45) {
      quality -= 5;
      thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);
    }

    return base64Encode(thumbnailBytes);
  }

  /// Generate thumbnail image (400x560, maintain aspect ratio)
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
