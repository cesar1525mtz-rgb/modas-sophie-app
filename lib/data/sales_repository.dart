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

    final sales = List<Map<String, dynamic>>.from(
      rows as List,
    );

    final sellerIds = sales
        .map((sale) => sale['seller_id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .toSet()
        .toList();

    final Map<String, String> sellerNames = {};

    if (sellerIds.isNotEmpty) {
      final profiles = await client
          .from('user_profiles')
          .select('id,name')
          .inFilter('id', sellerIds);

      for (final profile in profiles) {
        final id = profile['id']?.toString();
        final name = profile['name']?.toString();

        if (id != null &&
            name != null &&
            name.trim().isNotEmpty) {
          sellerNames[id] = name;
        }
      }
    }

    for (final sale in sales) {
      final sellerId = sale['seller_id']?.toString();

      final sellerName = sellerId == null
          ? null
          : sellerNames[sellerId];

      sale['seller_name'] = sellerName;

      sale['user_profiles'] = sellerName == null
          ? null
          : <String, dynamic>{
              'name': sellerName,
            };
    }

    return sales;
  }
}
