import 'json_casts.dart';

/// One field report from the `reports` table, served by get_reports.php and
/// written by add_report.php (attachments go through upload_file.php).
class Report {
  final int id;
  final int farmId;
  final String title;
  final String category;
  final String? notes;

  /// Public URL of the uploaded photo/document, if any.
  final String? fileUrl;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.farmId,
    required this.title,
    required this.category,
    this.notes,
    this.fileUrl,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: asInt(json['id']),
        farmId: asInt(json['farm_id']),
        title: asStr(json['title'], fallback: 'Report'),
        category: asStr(json['category'], fallback: 'General inspection'),
        notes: asStrOrNull(json['notes']),
        fileUrl: asStrOrNull(json['file_url']),
        createdAt: asDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'farm_id': farmId,
        'title': title,
        'category': category,
        'notes': notes,
        'file_url': fileUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
