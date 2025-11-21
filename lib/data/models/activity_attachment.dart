import 'dart:convert';

/// Represents a file attachment for an activity (PDF, image, etc.)
///
/// Storage strategy:
/// - Thumbnail: Always stored (≤20KB JPEG), for quick preview and Excel migration
/// - Full file: Stored in app directory while on device, optionally in Excel if ≤50KB
class ActivityAttachment {
  final String fileName;
  final String mimeType;

  /// Thumbnail preview (200x280 JPEG @ 60% quality, typically 15-25KB)
  /// For images: resized and compressed version
  /// For PDFs: first page rendered as JPEG
  final String thumbnailBase64;

  /// Full file as base64 (only for small files ≤50KB for Excel migration)
  /// Null for larger files - full file only stored in app directory
  final String? fullFileBase64;

  final DateTime attachedDate;
  final int originalSizeBytes;

  ActivityAttachment({
    required this.fileName,
    required this.mimeType,
    required this.thumbnailBase64,
    this.fullFileBase64,
    required this.attachedDate,
    required this.originalSizeBytes,
  });

  /// Whether the full file is included in Excel export (small files only)
  bool get isFullFileInExcel => fullFileBase64 != null;

  /// Whether user needs to re-attach full file on device migration
  bool get needsReupload => !isFullFileInExcel && originalSizeBytes > 50000;

  /// Convert to map for JSON storage
  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'mimeType': mimeType,
      'thumbnailBase64': thumbnailBase64,
      'fullFileBase64': fullFileBase64,
      'attachedDate': attachedDate.toIso8601String(),
      'originalSizeBytes': originalSizeBytes,
    };
  }

  /// Create from map (JSON deserialization)
  factory ActivityAttachment.fromMap(Map<String, dynamic> map) {
    return ActivityAttachment(
      fileName: map['fileName'] as String,
      mimeType: map['mimeType'] as String,
      thumbnailBase64: map['thumbnailBase64'] as String,
      fullFileBase64: map['fullFileBase64'] as String?,
      attachedDate: DateTime.parse(map['attachedDate'] as String),
      originalSizeBytes: map['originalSizeBytes'] as int,
    );
  }

  /// Convert to JSON string
  String toJson() => json.encode(toMap());

  /// Create from JSON string
  factory ActivityAttachment.fromJson(String source) =>
      ActivityAttachment.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Create a copy with modifications
  ActivityAttachment copyWith({
    String? fileName,
    String? mimeType,
    String? thumbnailBase64,
    String? fullFileBase64,
    DateTime? attachedDate,
    int? originalSizeBytes,
  }) {
    return ActivityAttachment(
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
      fullFileBase64: fullFileBase64 ?? this.fullFileBase64,
      attachedDate: attachedDate ?? this.attachedDate,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
    );
  }

  @override
  String toString() {
    return 'ActivityAttachment(fileName: $fileName, size: ${_formatBytes(originalSizeBytes)}, '
        'hasFullFile: $isFullFileInExcel)';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ActivityAttachment &&
        other.fileName == fileName &&
        other.mimeType == mimeType &&
        other.thumbnailBase64 == thumbnailBase64 &&
        other.fullFileBase64 == fullFileBase64 &&
        other.attachedDate == attachedDate &&
        other.originalSizeBytes == originalSizeBytes;
  }

  @override
  int get hashCode {
    return fileName.hashCode ^
        mimeType.hashCode ^
        thumbnailBase64.hashCode ^
        fullFileBase64.hashCode ^
        attachedDate.hashCode ^
        originalSizeBytes.hashCode;
  }
}
