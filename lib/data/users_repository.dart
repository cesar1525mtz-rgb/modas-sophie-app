import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class UsersRepository {
  final SupabaseClient client;
  UsersRepository(this.client);

  Future<List<AppUser>> listUsers() async {
    final rows = await client.from('user_profiles').select().order('name');
    return (rows as List)
        .map((row) => AppUser.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> setActive(String userId, bool active) async {
    await client.rpc('set_seller_active', params: {
      'p_user_id': userId,
      'p_active': active,
    });
  }
}
