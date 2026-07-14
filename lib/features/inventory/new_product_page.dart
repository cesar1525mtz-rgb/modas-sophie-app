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

  bool saving = false;

  SupabaseClient get client => Supabase.instance.client;

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
    final key = _variantKey(size, color);

    return stockControllers.putIfAbsent(
      key,
      () => TextEditingController(text: '0'),
    );
  }

  List<Map<String, String?>> get combinations {
    final activeSizes = selectedSizes.isEmpty
        ? <String?>[null]
        : selectedSizes.map<String?>((value) => value).toList();

    final activeColors = selectedColors.isEmpty
        ? <String?>[null]
        : selectedColors.map<String?>((value) => value).toList();

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

  Future<void> _addSize() async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Agregar talla'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Talla',
              hintText: 'Ej. 28, 32, CH, M, G',
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

    if (value == null || value.trim().isEmpty) return;

    final clean = value.trim();

    if (sizes.any(
      (size) => size.toLowerCase() == clean.toLowerCase(),
    )) {
      return;
    }

    setState(() {
      sizes.add(clean);
      selectedSizes.add(clean);
    });
  }

  Future<void> _addColor() async {
    final controller = TextEditingController();

    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Agregar color'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Color',
              hintText: 'Ej. Negro, Azul, Café',
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

    if (value == null || value.trim().isEmpty) return;

    final clean = value.trim();

    if (colors.any(
      (color) => color.toLowerCase() == clean.toLowerCase(),
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
      costController.text.trim().replaceAll(',', '.'),
    );

    final price = double.tryParse(
      priceController.text.trim().replaceAll(',', '.'),
    );

    final minimum = int.tryParse(
      minimumController.text.trim(),
    );

    if (name.isEmpty ||
        category.isEmpty ||
        cost == null ||
        price == null ||
        minimum == null) {
      _message('Completa correctamente todos los datos');
      return;
    }

    if (cost < 0 || price < 0 || minimum < 0) {
      _message('Los valores no pueden ser negativos');
      return;
    }

    final variants = combinations.map((variant) {
      final size = variant['size'];
      final color = variant['color'];

      final stock = int.tryParse(
            _stockController(size, color).text.trim(),
          ) ??
          0;

      return {
        'size': size,
        'color': color,
        'stock': stock,
      };
    }).toList();

    if (variants.any(
      (variant) => (variant['stock'] as int) < 0,
    )) {
      _message('La existencia no puede ser negativa');
      return;
    }

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

      _message('No fue posible guardar: $e');
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
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: categoryController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                hintText: 'Ej. Pantalón dama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(
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
              keyboardType: const TextInputType.numberWithOptions(
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
                    selected: selectedSizes.contains(size),
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
                  onPressed: _addSize,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Colores',
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
                ...colors.map((color) {
                  return FilterChip(
                    label: Text(color),
                    selected: selectedColors.contains(color),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedColors.add(color);
                        } else {
                          selectedColors.remove(color);
                        }
                      });
                    },
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('Agregar color'),
                  onPressed: _addColor,
                ),
              ],
            ),
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
            ...combinations.map((variant) {
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
            }),
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
                  saving ? 'GUARDANDO...' : 'GUARDAR PRODUCTO',
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
