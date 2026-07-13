class ProductVariant {
  final String sku;
  final String? size;
  final String? color;
  int stock;

  ProductVariant({
    required this.sku,
    this.size,
    this.color,
    this.stock = 0,
  });
}

class Product {
  final String skuBase;
  final String name;
  final String category;
  final double cost;
  final double salePrice;
  final int minimumStock;
  final List<ProductVariant> variants;

  Product({
    required this.skuBase,
    required this.name,
    required this.category,
    required this.cost,
    required this.salePrice,
    required this.minimumStock,
    required this.variants,
  });

  int get totalStock =>
      variants.fold(0, (total, variant) => total + variant.stock);
}
