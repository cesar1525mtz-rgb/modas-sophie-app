import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewProductPage extends StatefulWidget {
  const NewProductPage({super.key});

  @override
  State<NewProductPage> createState() => _NewProductPageState();
}

class _NewProductPageState extends State<NewProductPage> {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final costController = TextEditingController();
  final priceController = TextEditingController();
  final minimumController = TextEditingController(text: '1');

  final List<String> sizes = ['Unitalla'];
  final List<String> colors = [];

  final Set<String> selectedSizes = {'Unitalla'};
  final Set<String> selectedColors = {};

  final Map<String, TextEditingController> stockControllers = {};

  List<Map<String, dynamic>> categories = [];

  bool saving = false;
  bool loadingCategories = true;
  bool savingCategory = false;
  String? deletingCategoryId;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    costController.dispose();
    priceController.dispose();
    minimumController.dispose();

    for (final controller in stockControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  String _variantKey(String? size, String? color) {
    return '${size ?? ''}|${color ?? ''}';
  }

  TextEditingController _stockController(
    String? size,
    String? color,
  ) {
    return stockControllers.putIfAbsent(
      _variantKey(size, color),
      () => TextEditingController(text: '0'),
    );
  }

  List<Map<String, String?>> get combinations {
    final activeSizes = selectedSizes.isEmpty
        ? <String?>[null]
        : selectedSizes.map<String?>((e) => e).toList();

    final activeColors = selectedColors.isEmpty
        ? <String?>[null]
        : selectedColors.map<String?>((e) => e).toList();

    final result = <Map<String, String?>>[];

    for (final size in activeSizes) {
      for (final color in activeColors) {
        result.add({
          'size': size,
          'color': color,
        });
      }
    }

    return result;
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        loadingCategories = true;
      });
    }

    try {
      final response = await client
          .from('categories')
          .select(
            'id, business_id, name, sku_prefix, active',
          )
          .eq('active', true)
          .order('name');

      final loaded = List<Map<String, dynamic>>.from(
        response,
      );

      if (!mounted) return;

      setState(() {
        categories = loaded;
        loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingCategories = false;
      });

      _message(
        'No fue posible cargar las categorías: $e',
      );
    }
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

  String _createSkuPrefix(String name) {
    var clean = name.toUpperCase();

    clean = clean
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');

    clean = clean.replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    if (clean.isEmpty) {
      return 'CAT';
    }

    if (clean.length >= 3) {
      return clean.substring(0, 3);
    }

    return clean.padRight(3, 'X');
  }

  void _selectCategory(
    Map<String, dynamic> category,
  ) {
    setState(() {
      categoryController.text =
          (category['name'] ?? '').toString();
    });
  }

  Future<void> _addCategory() async {
    if (savingCategory) return;

    final value = await _askValue(
      title: 'Agregar categoría',
      label: 'Nombre de la categoría',
      hint: 'Ej. Zapatos',
    );

    if (value == null || value.trim().isEmpty) {
      return;
    }

    final clean = value.trim();

    Map<String, dynamic>? existingCategory;

    for (final item in categories) {
      final itemName = (item['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (itemName == clean.toLowerCase()) {
        existingCategory = item;
        break;
      }
    }

    if (existingCategory != null) {
      _selectCategory(existingCategory);

      _message(
        'La categoría ya existe y fue seleccionada',
      );

      return;
    }

    if (categories.isEmpty) {
      _message(
        'No se encontró el negocio de Modas Sophie',
      );

      return;
    }

    setState(() {
      savingCategory = true;
    });

    try {
      final businessId =
          categories.first['business_id'].toString();

      final basePrefix = _createSkuPrefix(clean);

      String skuPrefix = basePrefix;
      int suffix = 1;

      final usedPrefixes = categories
          .map(
            (item) => (item['sku_prefix'] ?? '')
                .toString()
                .toUpperCase(),
          )
          .toSet();

      while (usedPrefixes.contains(skuPrefix)) {
        skuPrefix = '$basePrefix$suffix';
        suffix++;
      }

      final inserted = await client
          .from('categories')
          .insert({
            'business_id': businessId,
            'name': clean,
            'sku_prefix': skuPrefix,
            'active': true,
          })
          .select(
            'id, business_id, name, sku_prefix, active',
          )
          .single();

      if (!mounted) return;

      setState(() {
        categories.add(
          Map<String, dynamic>.from(inserted),
        );

        categories.sort(
          (a, b) => (a['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b['name'] ?? '')
                    .toString()
                    .toLowerCase(),
              ),
        );

        categoryController.text =
            inserted['name'].toString();
      });

      _message(
        'Categoría guardada correctamente',
      );
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible guardar la categoría: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          savingCategory = false;
        });
      }
    }
  }

  Future<void> _deleteCategory(
    Map<String, dynamic> category,
  ) async {
    final categoryId = category['id'].toString();

    final categoryName =
        (category['name'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar categoría'),
          content: Text(
            '¿Seguro que deseas eliminar la categoría '
            '"$categoryName"?\n\n'
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('ELIMINAR'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      deletingCategoryId = categoryId;
    });

    try {
      await client
          .from('categories')
          .delete()
          .eq('id', categoryId);

      if (!mounted) return;

      setState(() {
        categories.removeWhere(
          (item) =>
              item['id'].toString() == categoryId,
        );

        if (categoryController.text
                .trim()
                .toLowerCase() ==
            categoryName.trim().toLowerCase()) {
          categoryController.clear();
        }
      });

      _message(
        'Categoría eliminada correctamente',
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;

      if (e.code == '23503') {
        _message(
          'Esta categoría tiene productos y no se puede eliminar',
        );
      } else {
        _message(
          'No fue posible eliminar la categoría: ${e.message}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible eliminar la categoría: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingCategoryId = null;
        });
      }
    }
  }

  Future<void> _addSize() async {
    final value = await _askValue(
      title: 'Agregar talla',
      label: 'Talla',
      hint: 'Ej. 28, CH, M, G',
    );

    if (value == null || value.trim().isEmpty) {
      return;
    }

    final clean = value.trim();

    if (sizes.any(
      (e) => e.toLowerCase() == clean.toLowerCase(),
    )) {
      return;
    }

    setState(() {
      sizes.add(clean);
      selectedSizes.add(clean);
    });
  }

  Future<void> _addColor() async {
    final value = await _askValue(
      title: 'Agregar color',
      label: 'Color',
      hint: 'Ej. Negro, Azul, Café',
    );

    if (value == null || value.trim().isEmpty) {
      return;
    }

    final clean = value.trim();

    if (colors.any(
      (e) => e.toLowerCase() == clean.toLowerCase(),
    )) {
      return;
    }

    setState(() {
      colors.add(clean);
      selectedColors.add(clean);
    });
  }

  Future<void> _save() async {
    if (saving) return;

    final name = nameController.text.trim();
    final category = categoryController.text.trim();

    final cost = double.tryParse(
      costController.text
          .trim()
          .replaceAll(',', '.'),
    );

    final price = double.tryParse(
      priceController.text
          .trim()
          .replaceAll(',', '.'),
    );

    final minimum = int.tryParse(
      minimumController.text.trim(),
    );

    if (name.isEmpty ||
        category.isEmpty ||
        cost == null ||
        price == null ||
        minimum == null) {
      _message(
        'Completa correctamente todos los datos',
      );

      return;
    }

    final variants = combinations.map((variant) {
      final size = variant['size'];
      final color = variant['color'];

      final stock = int.tryParse(
            _stockController(
              size,
              color,
            ).text.trim(),
          ) ??
          0;

      return {
        'size': size,
        'color': color,
        'stock': stock,
      };
    }).toList();

    setState(() {
      saving = true;
    });

    try {
      await client.rpc(
        'create_product_with_variants',
        params: {
          'p_category_name': category,
          'p_name': name,
          'p_cost': cost,
          'p_sale_price': price,
          'p_minimum_stock': minimum,
          'p_variants': variants,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto guardado'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible guardar: $e',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo producto'),
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

            TextField(
              controller: categoryController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Categoría seleccionada',
                hintText: 'Selecciona una categoría',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Categorías',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: loadingCategories
                      ? null
                      : _loadCategories,
                  tooltip: 'Actualizar categorías',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (loadingCategories)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (categories.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay categorías disponibles',
                  ),
                ),
              )
            else
              ...categories.map((category) {
                final categoryId =
                    category['id'].toString();

                final categoryName =
                    (category['name'] ?? '').toString();

                final selected =
                    categoryController.text
                            .trim()
                            .toLowerCase() ==
                        categoryName
                            .trim()
                            .toLowerCase();

                final deleting =
                    deletingCategoryId == categoryId;

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 8,
                  ),
                  child: ListTile(
                    onTap: deleting
                        ? null
                        : () {
                            _selectCategory(category);
                          },
                    leading: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.category_outlined,
                    ),
                    title: Text(
                      categoryName,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'SKU: '
                      '${category['sku_prefix'] ?? ''}',
                    ),
                    trailing: deleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : IconButton(
                            tooltip:
                                'Eliminar categoría',
                            icon: const Icon(
                              Icons.delete_outline,
                            ),
                            onPressed: () {
                              _deleteCategory(category);
                            },
                          ),
                  ),
                );
              }),

            const SizedBox(height: 8),

            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: savingCategory
                    ? null
                    : _addCategory,
                icon: savingCategory
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  savingCategory
                      ? 'GUARDANDO CATEGORÍA...'
                      : 'AGREGAR CATEGORÍA',
                ),
              ),
            ),

            const SizedBox(height: 20),

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

            const Text(
              'Tallas',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...sizes.map((size) {
                  return FilterChip(
                    label: Text(size),
                    selected:
                        selectedSizes.contains(size),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedSizes.add(size);
                        } else {
                          selectedSizes.remove(size);
                        }
                      });
                    },
                  );
                }),

                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('Agregar talla'),
                  onPressed:
