import 'package:supabase_flutter/supabase_flutter.dart';

class SalesRepository {
  final SupabaseClient client;

  SalesRepository(this.client);

  Future<List<Map<String, dynamic>>> listSales() async {
    final rows = await client
        .from('sales')
        .select(
          'id,folio,seller_id,total,sold_cost,gross_profit,'
          'status,created_at,'
          'user_profiles!sales_seller_id_fkey(name),'
          'sale_payments(method,amount,reference),'
          'sale_items('
          'historical_name,historical_sku,'
          'historical_size,historical_color,'
          'quantity,unit_price,total'
          ')',
        )
        .order(
          'created_at',
          ascending: false,
        );

    return List<Map<String, dynamic>>.from(
      rows as List,
    );
  }
}
