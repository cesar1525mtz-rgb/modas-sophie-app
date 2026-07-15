import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class UsersRepository {
  final SupabaseClient client;

  UsersRepository(this.client);

  Future<List<AppUser>> listUsers() async {
    final result = await client.rpc(
      'list_business_users',
    );

    final rows = result as List;

    return rows
        .map(
          (row) => AppUser.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> setActive(
    String userId,
    bool active,
  ) async {
    await client.rpc(
      'set_seller_active',
      params: {
        'p_user_id': userId,
        'p_active': active,
      },
    );
  }

  Future<Map<String, dynamic>> createSeller({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await client.rpc(
      'create_seller',
      params: {
        'p_name': name.trim(),
        'p_email': email.trim().toLowerCase(),
        'p_password': password,
      },
    );

    return Map<String, dynamic>.from(
      result as Map,
    );
  }
}
