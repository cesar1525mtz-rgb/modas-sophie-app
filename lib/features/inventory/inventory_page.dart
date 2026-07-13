import 'package:flutter/material.dart';
import '../../models/product.dart';
import 'new_product_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final products = <Product>[];
  String search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((product) {
      final value = search.toLowerCase();
      return product.name.toLowerCase().contains(value) ||
          product.skuBase.toLowerCase().contains(value);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newProduct,
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                hintText: 'Buscar nombre o SKU',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Aún no hay productos registrados.'),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final product = filtered[index];
                        final lowStock =
                            product.totalStock <= product.minimumStock;
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.checkroom),
                            ),
                            title: Text(product.name),
                            subtitle: Text(
                              '${product.skuBase} · ${product.totalStock} piezas',
                            ),
                            trailing: lowStock
                                ? const Icon(Icons.warning_amber)
                                : Text('\$${product.salePrice.toStringAsFixed(2)}'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newProduct() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const NewProductPage()),
    );

    if (product != null) {
      setState(() => products.add(product));
    }
  }
}
