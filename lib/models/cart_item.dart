class CartItem {
  final String variantId;
  final String name;
  final String sku;
  final String? size;
  final String? color;
  final double unitPrice;
  int quantity;

  CartItem({
    required this.variantId,
    required this.name,
    required this.sku,
    this.size,
    this.color,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get total => unitPrice * quantity;
}
