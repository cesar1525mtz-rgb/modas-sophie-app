import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class InventoryRepository {
  final SupabaseClient client;

  InventoryRepository(this.client);

  Future<List<Product>> listProducts() async {
    final rows = await client
        .from('products')
        .select(
          'sku_base,'
          'name,'
          'current_cost,'
          'sale_price,'
          'minimum_stock,'
          'categories(name),'
          'product_variants('
          'sku,'
          'size,'
          'color,'
          'current_stock,'
          'active'
          ')',
        )
        .eq('active', true)
        .order('name');

    return (rows as List).map((row) {
      final variantRows =
          row['product_variants'] as List? ?? [];

      final variants = variantRows
          .where((variant) => variant['active'] == true)
          .map(
            (variant) => ProductVariant(
              sku: variant['sku'].toString(),
              size: variant['size']?.toString(),
              color: variant['color']?.toString(),
              stock:
                  (variant['current_stock'] as num?)
                          ?.toInt() ??
                      0,
            ),
          )
          .toList();

      final categoryData = row['categories'];

      return Product(
        skuBase: row['sku_base'].toString(),
        name: row['name'].toString(),
        category: categoryData == null
            ? ''
            : categoryData['name'].toString(),
        cost:
            (row['current_cost'] as num?)?.toDouble() ??
                0,
        salePrice:
            (row['sale_price'] as num?)?.toDouble() ??
                0,
        minimumStock:
            (row['minimum_stock'] as num?)?.toInt() ??
                0,
        variants: variants,
      );
    }).toList();
  }

  Future<void> createProduct({
    required String categoryName,
    required String name,
    required double cost,
    required double salePrice,
    required int minimumStock,
    String? size,
    String? color,
    required int initialStock,
  }) async {
    await client.rpc(
      'create_product_with_variant',
      params: {
        'p_category_name': categoryName,
        'p_name': name,
        'p_cost': cost,
        'p_sale_price': salePrice,
        'p_minimum_stock': minimumStock,
        'p_size': size,
        'p_color': color,
        'p_initial_stock': initialStock,
      },
    );
  }
}
