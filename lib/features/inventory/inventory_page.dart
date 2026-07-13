import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/inventory_repository.dart';
import '../../models/product.dart';
import 'new_product_page.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final InventoryRepository repository;
  List<Product> products = [];
  String search = '';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    repository = InventoryRepository(Supabase.instance.client);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await repository.listProducts();
      if (!mounted) return;
      setState(() => products = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = search.toLowerCase();
    final filtered = products.where((product) {
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
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: Padding(
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
              Expanded(child: _content(filtered)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<Product> filtered) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Center(child: Text('No se pudo cargar el inventario')),
          const SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: _loadProducts,
              child: const Text('REINTENTAR'),
            ),
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Center(child: Text('Aún no hay productos registrados.')),
        ],
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final product = filtered[index];
        final lowStock = product.totalStock <= product.minimumStock;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.checkroom)),
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
    );
  }

  Future<void> _newProduct() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewProductPage()),
    );

    if (saved == true) {
      await _loadProducts();
    }
  }
}
