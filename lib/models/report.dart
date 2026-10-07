import 'json_casts.dart';

class Report {
  final int id;
  final int farmId;
  final String title;
  final String category;
  final String? notes;
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
        title: asStr(json['report_title'] ?? json['title'], fallback: 'Report'),
        category: asStr(json['category'], fallback: 'General inspection'),
        notes: asStrOrNull(json['notes']),
        fileUrl: asStrOrNull(json['file_path'] ?? json['file_url']),
        createdAt: asDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'farm_id': farmId,
        'report_title': title,
        'title': title,
        'category': category,
        'notes': notes,
        'file_path': fileUrl,
        'file_url': fileUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
