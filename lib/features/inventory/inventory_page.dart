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

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    repository = InventoryRepository(client);
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

      setState(() {
        products = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
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
      appBar: AppBar(
        title: const Text('Inventario'),
      ),
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
                onChanged: (value) {
                  setState(() {
                    search = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar nombre o SKU',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _content(filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<Product> filtered) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.error_outline,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('No se pudo cargar el inventario'),
          ),
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
          Center(
            child: Text('Aún no hay productos registrados.'),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final product = filtered[index];

        final lowStock =
            product.totalStock <= product.minimumStock;

        return Card(
          child: ListTile(
            onTap: () => _openProduct(product),
            leading: const CircleAvatar(
              child: Icon(Icons.checkroom),
            ),
            title: Text(product.name),
            subtitle: Text(
              '${product.skuBase} · ${product.totalStock} piezas',
            ),
            trailing: lowStock
                ? const Icon(Icons.warning_amber)
                : Text(
                    '\$${product.salePrice.toStringAsFixed(2)}',
                  ),
          ),
        );
      },
    );
  }

  Future<void> _newProduct() async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NewProductPage(),
      ),
    );

    if (saved == true) {
      await _loadProducts();
    }
  }

  Future<void> _openProduct(Product product) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(product.skuBase),
                const SizedBox(height: 20),
                _detailRow(
                  'Categoría',
                  product.category,
                ),
                _detailRow(
                  'Costo',
                  '\$${product.cost.toStringAsFixed(2)}',
                ),
                _detailRow(
                  'Precio',
                  '\$${product.salePrice.toStringAsFixed(2)}',
                ),
                _detailRow(
                  'Stock total',
                  product.totalStock.toString(),
                ),
                _detailRow(
                  'Stock mínimo',
                  product.minimumStock.toString(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Variantes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...product.variants.map((variant) {
                  return Card(
                    child: ListTile(
                      title: Text(variant.sku),
                      subtitle: Text(
                        _variantDescription(variant),
                      ),
                      trailing: Text(
                        '${variant.stock} pzas.',
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _editVariantStock(variant);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _editProduct(product);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('EDITAR PRODUCTO'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _deleteProduct(product);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ELIMINAR PRODUCTO'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _variantDescription(ProductVariant variant) {
    final details = <String>[];

    if (variant.size != null && variant.size!.isNotEmpty) {
      details.add('Talla: ${variant.size}');
    }

    if (variant.color != null && variant.color!.isNotEmpty) {
      details.add('Color: ${variant.color}');
    }

    if (details.isEmpty) {
      return 'Sin talla ni color';
    }

    return details.join(' · ');
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProduct(Product product) async {
    final nameController = TextEditingController(
      text: product.name,
    );

    final costController = TextEditingController(
      text: product.cost.toStringAsFixed(2),
    );

    final priceController = TextEditingController(
      text: product.salePrice.toStringAsFixed(2),
    );

    final minimumController = TextEditingController(
      text: product.minimumStock.toString(),
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                  ),
                ),
                TextField(
                  controller: costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Costo',
                  ),
                ),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio de venta',
                  ),
                ),
                TextField(
                  controller: minimumController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock mínimo',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );

    if (save != true) return;

    try {
      final name = nameController.text.trim();
      final cost = double.parse(costController.text.trim());
      final price = double.parse(priceController.text.trim());
      final minimum = int.parse(minimumController.text.trim());

      await client
          .from('products')
          .update({
            'name': name,
            'current_cost': cost,
            'sale_price': price,
            'minimum_stock': minimum,
          })
          .eq('sku_base', product.skuBase);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto actualizado'),
        ),
      );

      await _loadProducts();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fue posible actualizar: $e'),
        ),
      );
    }
  }

  Future<void> _editVariantStock(ProductVariant variant) async {
    final stockController = TextEditingController(
      text: variant.stock.toString(),
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ajustar stock'),
          content: TextField(
            controller: stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Existencia actual',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );

    if (save != true) return;

    try {
      final stock = int.parse(stockController.text.trim());

      if (stock < 0) {
        throw Exception('El stock no puede ser negativo');
      }

      await client
          .from('product_variants')
          .update({
            'current_stock': stock,
          })
          .eq('sku', variant.sku);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock actualizado'),
        ),
      );

      await _loadProducts();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No fue posible actualizar el stock: $e',
          ),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar producto'),
          content: Text(
            '¿Deseas eliminar ${product.name} del inventario?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('ELIMINAR'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await client
          .from('products')
          .update({
            'active': false,
          })
          .eq('sku_base', product.skuBase);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto eliminado'),
        ),
      );

      await _loadProducts();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fue posible eliminar: $e'),
        ),
      );
    }
  }
}
