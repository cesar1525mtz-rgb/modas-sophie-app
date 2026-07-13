import 'package:supabase_flutter/supabase_flutter.dart';

class PosRepository {
  final SupabaseClient client;
  PosRepository(this.client);

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final rows = await client.rpc('search_pos_products', params: {
      'p_query': query,
    });
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> completeSale({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double paymentAmount,
    String? reference,
  }) async {
    final result = await client.rpc('complete_sale', params: {
      'p_items': items,
      'p_payment_method': paymentMethod,
      'p_payment_amount': paymentAmount,
      'p_reference': reference,
    });
    return result as String;
  }
}
