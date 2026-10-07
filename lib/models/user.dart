import 'json_casts.dart';

class AppUser {
  final int id;
  final String email;
  final String fullName;
  final String role;
  final String phone;
  final String location;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = 'Farm manager',
    this.phone = '',
    this.location = '',
    this.createdAt,
  });

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Farmora User';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: asInt(json['id']),
        email: asStr(json['email']),
        fullName: asStr(json['full_name']),
        role: asStr(json['role'], fallback: 'Farm manager'),
        phone: asStr(json['phone']),
        location: asStr(json['location']),
        createdAt: asDateOrNull(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'phone': phone,
        'location': location,
        'created_at': createdAt?.toIso8601String(),
      };
}
