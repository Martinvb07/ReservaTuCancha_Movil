/// Lo que devuelve `POST /auth/login` del backend NestJS: los dos tokens y el
/// usuario. Ver `auth.service.ts:38`.
library;

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;

  /// admin | owner
  final String role;

  final String? avatarUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] ?? json['_id'] ?? json['userId'] ?? '').toString(),
    name: (json['name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    role: (json['role'] as String?) ?? 'owner',
    avatarUrl: json['avatarUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'avatarUrl': avatarUrl,
  };

  /// La inicial para el avatar del navbar cuando no hay foto.
  String get initial => name.isEmpty
      ? (email.isEmpty ? '?' : email[0].toUpperCase())
      : name.substring(0, 1).toUpperCase();
}
