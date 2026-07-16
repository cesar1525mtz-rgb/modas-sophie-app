import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewProductPage extends StatefulWidget {
  final String? initialCategoryName;

  const NewProductPage({
    super.key,
    this.initialCategoryName,
  });

  @override
  State<NewProductPage> createState() => _NewProductPageState();
}

class _NewProductPageState extends State<NewProductPage> {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final costController = TextEditingController();
  final priceController = TextEditingController();
  final minimumController = TextEditingController(text: '1');

  final Map<String, TextEditingController> stockControllers = {};

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> sizes = [];
  List<Map<String, dynamic>> colors = [];

  final Set<String> selectedSizes = {};
  final Set<String> selectedColors = {};

  bool saving = false;
  bool loading = true;
  bool savingCategory = false;
  bool savingSize = false;
  bool savingColor = false;

  String? deletingCategoryId;
  String? deletingSizeId;
  String? deletingColorId;

  SupabaseClient get client => Supabase.instance.client;

  @override
void initState() {
  super.initState();

  if (widget.initialCategoryName != null) {
    categoryController.text = widget.initialCategoryName!;
  }

  _loadCatalogs();
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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _loadCatalogs() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final categoriesResponse = await client
          .from('categories')
          .select('id,business_id,name,sku_prefix,active')
          .eq('active', true)
          .order('name');

      final sizesResponse = await client
          .from('sizes')
          .select('id,business_id,name,active')
          .eq('active', true)
          .order('name');

      final colorsResponse = await client
          .from('colors')
          .select('id,business_id,name,active')
          .eq('active', true)
          .order('name');

      if (!mounted) return;

      final loadedSizes =
          List<Map<String, dynamic>>.from(sizesResponse);

      setState(() {
        categories =
            List<Map<String, dynamic>>.from(categoriesResponse);

        sizes = loadedSizes;

        colors =
            List<Map<String, dynamic>>.from(colorsResponse);

        if (selectedSizes.isEmpty) {
          for (final size in loadedSizes) {
            final name = (size['name'] ?? '').toString();

            if (name.toLowerCase() == 'unitalla') {
              selectedSizes.add(name);
              break;
            }
          }
        }

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _message('No fue posible cargar los catálogos: $e');
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
              onPressed: dialogContext.mounted
                  ? () => Navigator.pop(dialogContext)
                  : null,
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: dialogContext.mounted
                  ? () {
                      Navigator.pop(
                        dialogContext,
                        controller.text.trim(),
                      );
                    }
                  : null,
              child: const Text('AGREGAR'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return value;
  }

  Future<bool> _confirmDelete(
    String title,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            '¿Seguro que deseas eliminar "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: dialogContext.mounted
                  ? () {
                      Navigator.pop(dialogContext, false);
                    }
                  : null,
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: dialogContext.mounted
                  ? () {
                      Navigator.pop(dialogContext, true);
                    }
                  : null,
              child: const Text('ELIMINAR'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  String _createSkuPrefix(String name) {
    var clean = name
        .toUpperCase()
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

    if (clean.isEmpty) return 'CAT';

    if (clean.length >= 3) {
      return clean.substring(0, 3);
    }

    return clean.padRight(3, 'X');
  }

  String? get _businessId {
    if (categories.isNotEmpty) {
      return categories.first['business_id']?.toString();
    }

    if (sizes.isNotEmpty) {
      return sizes.first['business_id']?.toString();
    }

    if (colors.isNotEmpty) {
      return colors.first['business_id']?.toString();
    }

    return null;
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

    if (value == null || value.trim().isEmpty) return;

    final clean = value.trim();

    for (final category in categories) {
      final name =
          (category['name'] ?? '').toString().trim();

      if (name.toLowerCase() == clean.toLowerCase()) {
        _selectCategory(category);

        _message(
          'La categoría ya existe y fue seleccionada',
        );

        return;
      }
    }

    final businessId = _businessId;

    if (businessId == null) {
      _message(
        'No se encontró el negocio de Modas Sophie',
      );

      return;
    }

    setState(() {
      savingCategory = true;
    });

    try {
      final basePrefix = _createSkuPrefix(clean);
      var skuPrefix = basePrefix;
      var suffix = 1;

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
            'id,business_id,name,sku_prefix,active',
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

      _message('Categoría guardada correctamente');
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
    final id = category['id'].toString();
    final name = (category['name'] ?? '').toString();

    final confirmed = await _confirmDelete(
      'Eliminar categoría',
      name,
    );

    if (!confirmed) return;

    setState(() {
      deletingCategoryId = id;
    });

    try {
      await client
          .from('categories')
          .delete()
          .eq('id', id);

      if (!mounted) return;

      setState(() {
        categories.removeWhere(
          (item) => item['id'].toString() == id,
        );

        if (categoryController.text
                .trim()
                .toLowerCase() ==
            name.trim().toLowerCase()) {
          categoryController.clear();
        }
      });

      _message('Categoría eliminada correctamente');
    } on PostgrestException catch (e) {
      if (!mounted) return;

      if (e.code == '23503') {
        _message(
          'Esta categoría contiene productos y no se puede eliminar',
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
    if (savingSize) return;

    final value = await _askValue(
      title: 'Agregar talla',
      label: 'Talla',
      hint: 'Ej. 28, CH, M, G',
    );

    if (value == null || value.trim().isEmpty) return;

    final clean = value.trim();

    for (final size in sizes) {
      final name = (size['name'] ?? '').toString().trim();

      if (name.toLowerCase() == clean.toLowerCase()) {
        setState(() {
          selectedSizes.add(name);
        });

        _message(
          'La talla ya existe y fue seleccionada',
        );

        return;
      }
    }

    final businessId = _businessId;

    if (businessId == null) {
      _message(
        'No se encontró el negocio de Modas Sophie',
      );

      return;
    }

    setState(() {
      savingSize = true;
    });

    try {
      final inserted = await client
          .from('sizes')
          .insert({
            'business_id': businessId,
            'name': clean,
            'active': true,
          })
          .select('id,business_id,name,active')
          .single();

      if (!mounted) return;

      setState(() {
        sizes.add(
          Map<String, dynamic>.from(inserted),
        );

        sizes.sort(
          (a, b) => (a['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b['name'] ?? '')
                    .toString()
                    .toLowerCase(),
              ),
        );

        selectedSizes.add(
          inserted['name'].toString(),
        );
      });

      _message('Talla guardada correctamente');
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible guardar la talla: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          savingSize = false;
        });
      }
    }
  }

  Future<void> _deleteSize(
    Map<String, dynamic> size,
  ) async {
    final id = size['id'].toString();
    final name = (size['name'] ?? '').toString();

    final confirmed = await _confirmDelete(
      'Eliminar talla',
      name,
    );

    if (!confirmed) return;

    setState(() {
      deletingSizeId = id;
    });

    try {
      final used = await client
          .from('product_variants')
          .select('id')
          .eq('size', name)
          .limit(1);

      if (used.isNotEmpty) {
        if (!mounted) return;

        _message(
          'Esta talla está usada en productos y no se puede eliminar',
        );

        return;
      }

      await client.from('sizes').delete().eq('id', id);

      if (!mounted) return;

      setState(() {
        sizes.removeWhere(
          (item) => item['id'].toString() == id,
        );

        selectedSizes.remove(name);
      });

      _message('Talla eliminada correctamente');
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible eliminar la talla: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingSizeId = null;
        });
      }
    }
  }

  Future<void> _addColor() async {
    if (savingColor) return;

    final value = await _askValue(
      title: 'Agregar color',
      label: 'Color',
      hint: 'Ej. Negro, Azul, Café',
    );

    if (value == null || value.trim().isEmpty) return;

    final clean = value.trim();

    for (final color in colors) {
      final name =
          (color['name'] ?? '').toString().trim();

      if (name.toLowerCase() == clean.toLowerCase()) {
        setState(() {
          selectedColors.add(name);
        });

        _message(
          'El color ya existe y fue seleccionado',
        );

        return;
      }
    }

    final businessId = _businessId;

    if (businessId == null) {
      _message(
        'No se encontró el negocio de Modas Sophie',
      );

      return;
    }

    setState(() {
      savingColor = true;
    });

    try {
      final inserted = await client
          .from('colors')
          .insert({
            'business_id': businessId,
            'name': clean,
            'active': true,
          })
          .select('id,business_id,name,active')
          .single();

      if (!mounted) return;

      setState(() {
        colors.add(
          Map<String, dynamic>.from(inserted),
        );

        colors.sort(
          (a, b) => (a['name'] ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b['name'] ?? '')
                    .toString()
                    .toLowerCase(),
              ),
        );

        selectedColors.add(
          inserted['name'].toString(),
        );
      });

      _message('Color guardado correctamente');
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible guardar el color: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          savingColor = false;
        });
      }
    }
  }

  Future<void> _deleteColor(
    Map<String, dynamic> color,
  ) async {
    final id = color['id'].toString();
    final name = (color['name'] ?? '').toString();

    final confirmed = await _confirmDelete(
      'Eliminar color',
      name,
    );

    if (!confirmed) return;

    setState(() {
      deletingColorId = id;
    });

    try {
      final used = await client
          .from('product_variants')
          .select('id')
          .eq('color', name)
          .limit(1);

      if (used.isNotEmpty) {
        if (!mounted) return;

        _message(
          'Este color está usado en productos y no se puede eliminar',
        );

        return;
      }

      await client.from('colors').delete().eq('id', id);

      if (!mounted) return;

      setState(() {
        colors.removeWhere(
          (item) => item['id'].toString() == id,
        );

        selectedColors.remove(name);
      });

      _message('Color eliminado correctamente');
    } catch (e) {
      if (!mounted) return;

      _message(
        'No fue posible eliminar el color: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          deletingColorId = null;
        });
      }
    }
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

      _message('Producto guardado');

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      _message('No fue posible guardar: $e');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Widget _categoriesSection() {
    return Column(
      children: categories.map((category) {
        final id = category['id'].toString();
        final name = (category['name'] ?? '').toString();

        final selected =
            categoryController.text.trim().toLowerCase() ==
                name.trim().toLowerCase();

        final deleting = deletingCategoryId == id;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: deleting
                ? null
                : () => _selectCategory(category),
            leading: Icon(
              selected
                  ? Icons.check_circle
                  : Icons.category_outlined,
            ),
            title: Text(
              name,
              style: TextStyle(
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              'SKU: ${category['sku_prefix'] ?? ''}',
            ),
            trailing: deleting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    onPressed: () {
                      _deleteCategory(category);
                    },
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sizesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...sizes.map((size) {
          final id = size['id'].toString();
          final name = (size['name'] ?? '').toString();
          final deleting = deletingSizeId == id;

          return InputChip(
            label: Text(name),
            selected: selectedSizes.contains(name),
            onSelected: deleting
                ? null
                : (selected) {
                    setState(() {
                      if (selected) {
                        selectedSizes.add(name);
                      } else {
                        selectedSizes.remove(name);
                      }
                    });
                  },
            onDeleted: deleting
                ? null
                : () {
                    _deleteSize(size);
                  },
            deleteIcon: deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.close),
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add),
          label: Text(
            savingSize ? 'Guardando...' : 'Agregar talla',
          ),
          onPressed: savingSize ? null : _addSize,
        ),
      ],
    );
  }

  Widget _colorsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...colors.map((color) {
          final id = color['id'].toString();
          final name = (color['name'] ?? '').toString();
          final deleting = deletingColorId == id;

          return InputChip(
            label: Text(name),
            selected: selectedColors.contains(name),
            onSelected: deleting
                ? null
                : (selected) {
                    setState(() {
                      if (selected) {
                        selectedColors.add(name);
                      } else {
                        selectedColors.remove(name);
                      }
                    });
                  },
            onDeleted: deleting
                ? null
                : () {
                    _deleteColor(color);
                  },
            deleteIcon: deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.close),
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.add),
          label: Text(
            savingColor ? 'Guardando...' : 'Agregar color',
          ),
          onPressed: savingColor ? null : _addColor,
        ),
      ],
    );
  }

  Widget _variantsSection() {
    return Column(
      children: combinations.map((variant) {
        final size = variant['size'];
        final color = variant['color'];

        final description = [
          if (size != null) size,
          if (color != null) color,
        ].join(' · ');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    description.isEmpty
                        ? 'Sin talla ni color'
                        : description,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _stockController(
                      size,
                      color,
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo producto'),
      ),
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView(
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
                      const Expanded(
                        child: Text(
                          'Categorías',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadCatalogs,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  _categoriesSection(),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: savingCategory
                          ? null
                          : _addCategory,
                      icon: const Icon(Icons.add),
                      label: Text(
                        savingCategory
                            ? 'GUARDANDO...'
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
                  _sizesSection(),
                  const SizedBox(height: 28),
                  const Text(
                    'Colores',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _colorsSection(),
                  const SizedBox(height: 28),
                  const Text(
                    'Existencias por variante',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Indica cuántas piezas tienes de cada combinación.',
                  ),
                  const SizedBox(height: 16),
                  _variantsSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        saving
                            ? 'GUARDANDO...'
                            : 'GUARDAR PRODUCTO',
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
