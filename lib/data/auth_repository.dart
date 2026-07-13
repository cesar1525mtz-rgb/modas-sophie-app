import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class AuthRepository {
  final SupabaseClient client;
  AuthRepository(this.client);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => client.auth.signOut();

  Future<AppUser> currentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('AUTH_SESSION_MISSING');
    }

    final row = await client
        .from('user_profiles')
        .select('id,business_id,name,role,active')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      throw StateError('PROFILE_NOT_FOUND');
    }

    return AppUser.fromMap(row);
  }
}
