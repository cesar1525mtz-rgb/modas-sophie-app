import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final SupabaseClient client;
  DashboardRepository(this.client);

  Future<Map<String, dynamic>> today() async {
    final result = await client.rpc('owner_dashboard_today');
    return Map<String, dynamic>.from(result);
  }
}
