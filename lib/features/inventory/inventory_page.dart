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
            child: Text(
              'No se pudo cargar el inventario',
            ),
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
            child: Text(
              'Aún no hay productos registrados.',
            ),
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
              '${product.skuBase} · '
              '${product.totalStock} piezas',
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
                  style:
                      Theme.of(context).textTheme.headlineSmall,
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
                    label: const Text(
                      'EDITAR PRODUCTO',
                    ),
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
                    label: const Text(
                      'ELIMINAR PRODUCTO',
                    ),
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

    if (variant.size != null &&
        variant.size!.isNotEmpty) {
      details.add('Talla: ${variant.size}');
    }

    if (variant.color != null &&
        variant.color!.isNotEmpty) {
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
    try {
      final productData = await client
          .from('products')
          .select('id')
          .eq('sku_base', product.skuBase)
          .single();

      final productId = productData['id'].toString();

      final variantData = await client
          .from('product_variants')
          .select(
            'id, sku, size, color, current_stock, active',
          )
          .eq('product_id', productId)
          .eq('active', true)
          .order('sku');

      final categoryData = await client
          .from('categories')
          .select('name')
          .eq('active', true)
          .order('name');

      if (!mounted) return;

      final variants = (variantData as List)
          .map(
            (row) => _EditableVariant(
              id: row['id']?.toString(),
              sku: row['sku']?.toString(),
              size: row['size']?.toString(),
              color: row['color']?.toString(),
              stock:
                  (row['current_stock'] as num?)?.toInt() ??
                      0,
            ),
          )
          .toList();

      final categories = (categoryData as List)
          .map(
            (row) => row['name'].toString(),
          )
          .toList();

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _EditProductPage(
            productId: productId,
            product: product,
            variants: variants,
            categories: categories,
          ),
        ),
      );

      if (saved == true) {
        await _loadProducts();
      }
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible abrir la edición: $e',
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
            '¿Deseas eliminar ${product.name} '
            'del inventario?',
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

      _message('Producto eliminado');

      await _loadProducts();
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible eliminar: $e',
      );
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }
}

class _EditableVariant {
  _EditableVariant({
    this.id,
    this.sku,
    this.size,
    this.color,
    required int stock,
  }) : stockController = TextEditingController(
          text: stock.toString(),
        );

  final String? id;
  final String? sku;

  String? size;
  String? color;

  final TextEditingController stockController;

  void dispose() {
    stockController.dispose();
  }
}

class _EditProductPage extends StatefulWidget {
  const _EditProductPage({
    required this.productId,
    required this.product,
    required this.variants,
    required this.categories,
  });

  final String productId;
  final Product product;
  final List<_EditableVariant> variants;
  final List<String> categories;

  @override
  State<_EditProductPage> createState() =>
      _EditProductPageState();
}

class _EditProductPageState
    extends State<_EditProductPage> {
  late final TextEditingController nameController;
  late final TextEditingController costController;
  late final TextEditingController priceController;
  late final TextEditingController minimumController;

  late String selectedCategory;

  late List<_EditableVariant> variants;

  bool saving = false;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.product.name,
    );

    costController = TextEditingController(
      text: widget.product.cost.toStringAsFixed(2),
    );

    priceController = TextEditingController(
      text: widget.product.salePrice.toStringAsFixed(2),
    );

    minimumController = TextEditingController(
      text: widget.product.minimumStock.toString(),
    );

    selectedCategory = widget.product.category;

    variants = List<_EditableVariant>.from(
      widget.variants,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    costController.dispose();
    priceController.dispose();
    minimumController.dispose();

    for (final variant in variants) {
      variant.dispose();
    }

    super.dispose();
  }

  Future<String?> _askValue({
    required String title,
    required String label,
    required String hint,
  }) async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              },
              child: const Text('AGREGAR'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return value;
  }

  Future<void> _addVariant() async {
    final size = await _askValue(
      title: 'Nueva variante',
      label: 'Talla',
      hint: 'Ej. 32, M/L, Unitalla',
    );

    if (!mounted || size == null) return;

    final color = await _askValue(
      title: 'Nueva variante',
      label: 'Color',
      hint: 'Ej. NEGRO, AZUL',
    );

    if (!mounted || color == null) return;

    final cleanSize = size.trim();
    final cleanColor = color.trim();

    if (cleanSize.isEmpty && cleanColor.isEmpty) {
      _message(
        'Indica al menos una talla o un color',
      );
      return;
    }

    final exists = variants.any((variant) {
      return (variant.size ?? '').trim().toLowerCase() ==
              cleanSize.toLowerCase() &&
          (variant.color ?? '').trim().toLowerCase() ==
              cleanColor.toLowerCase();
    });

    if (exists) {
      _message(
        'Esta combinación ya existe',
      );
      return;
    }

    setState(() {
      variants.add(
        _EditableVariant(
          size: cleanSize.isEmpty ? null : cleanSize,
          color: cleanColor.isEmpty ? null : cleanColor,
          stock: 0,
        ),
      );
    });
  }

  Future<void> _removeVariant(
    _EditableVariant variant,
  ) async {
    if (variants.length <= 1) {
      _message(
        'El producto debe conservar al menos una variante',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Retirar variante'),
          content: Text(
            '¿Deseas retirar '
            '${_description(variant)} del producto?\n\n'
            'No se borrará el historial.',
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
              child: const Text('RETIRAR'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      variants.remove(variant);
    });

    variant.dispose();
  }

  String _description(_EditableVariant variant) {
    final values = <String>[];

    if (variant.size != null &&
        variant.size!.trim().isNotEmpty) {
      values.add(variant.size!.trim());
    }

    if (variant.color != null &&
        variant.color!.trim().isNotEmpty) {
      values.add(variant.color!.trim());
    }

    if (values.isEmpty) {
      return 'Sin talla ni color';
    }

    return values.join(' · ');
  }

  Future<void> _save() async {
    if (saving) return;

    final name = nameController.text.trim();

    final cost = double.tryParse(
      costController.text.trim().replaceAll(',', '.'),
    );

    final price = double.tryParse(
      priceController.text.trim().replaceAll(',', '.'),
    );

    final minimum = int.tryParse(
      minimumController.text.trim(),
    );

    if (name.isEmpty ||
        selectedCategory.trim().isEmpty ||
        cost == null ||
        price == null ||
        minimum == null) {
      _message(
        'Completa correctamente todos los datos',
      );
      return;
    }

    if (cost < 0 || price < 0 || minimum < 0) {
      _message(
        'Los valores no pueden ser negativos',
      );
      return;
    }

    if (variants.isEmpty) {
      _message(
        'El producto debe tener al menos una variante',
      );
      return;
    }

    final variantJson = <Map<String, dynamic>>[];

    for (final variant in variants) {
      final stock = int.tryParse(
        variant.stockController.text.trim(),
      );

      if (stock == null || stock < 0) {
        _message(
          'Revisa las existencias de '
          '${_description(variant)}',
        );
        return;
      }

      variantJson.add({
        'id': variant.id,
        'size': variant.size,
        'color': variant.color,
        'stock': stock,
        'active': true,
      });
    }

    setState(() {
      saving = true;
    });

    try {
      await client.rpc(
        'update_product_with_variants',
        params: {
          'p_product_id': widget.productId,
          'p_category_name': selectedCategory,
          'p_name': name,
          'p_cost': cost,
          'p_sale_price': price,
          'p_minimum_stock': minimum,
          'p_variants': variantJson,
        },
      );

      if (!mounted) return;

      _message(
        'Producto actualizado correctamente',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible actualizar: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryValues = <String>{
      selectedCategory,
      ...widget.categories,
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar producto'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: categoryValues.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: costController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Costo',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio de venta',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: minimumController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock mínimo',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 28),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Variantes y existencias',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addVariant,
                  tooltip: 'Agregar variante',
                  icon: const Icon(
                    Icons.add_circle_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Puedes cambiar la existencia, '
              'agregar combinaciones o retirar variantes.',
            ),

            const SizedBox(height: 16),

            ...variants.map((variant) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _description(variant),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                                if (variant.sku != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    variant.sku!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _removeVariant(variant);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            tooltip: 'Retirar variante',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller:
                            variant.stockController,
                        keyboardType:
                            TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Existencia actual',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  saving
                      ? 'GUARDANDO...'
                      : 'GUARDAR CAMBIOS',
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
