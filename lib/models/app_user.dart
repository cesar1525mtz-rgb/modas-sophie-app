enum UserRole { owner, seller }

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final bool active;

  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    name: map['name'] as String,
    role: map['role'] == 'OWNER' ? UserRole.owner : UserRole.seller,
    active: map['active'] as bool? ?? true,
  );
}
