import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewProductPage extends StatefulWidget {
  const NewProductPage({super.key});

  @override
  State<NewProductPage> createState() => _NewProductPageState();
}

class _NewProductPageState extends State<NewProductPage> {
  final nameController = TextEditingController();
  final costController = TextEditingController();
  final priceController = TextEditingController();
  final minimumController = TextEditingController(text: '2');

  final SupabaseClient client = Supabase.instance.client;

  bool saving = false;
  String category = 'Blusas';

  final List<String> categories = [
    'Blusas',
    'Pantalón dama',
    'Vestidos',
    'Faldas',
    'Shorts',
    'Conjuntos',
    'Otros',
  ];

  final List<String> sizes = ['Unitalla'];
  final List<String> colors = [];

  final Set<String> selectedSizes = {};
  final Set<String> selectedColors = {};

  final Map<String, TextEditingController> stockControllers = {};

  @override
  void dispose() {
    nameController.dispose();
    costController.dispose();
    priceController.dispose();
    minimumController.dispose();

    for (final controller in stockControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  String variantKey(String size, String color) {
    return '$size|$color';
  }

  TextEditingController stockController(
    String size,
    String color,
  ) {
    final key = variantKey(size, color);

    return stockControllers.putIfAbsent(
      key,
      () => TextEditingController(text: '0'),
    );
  }

  List<Map<String, dynamic>> get variants {
    final result = <Map<String, dynamic>>[];

    for (final size in selectedSizes) {
      for (final color in selectedColors) {
        result.add({
          'size': size,
          'color': color,
          'stock': int.tryParse(
                stockController(size, color).text.trim(),
              ) ??
              0,
        });
      }
    }

    return result;
  }

  Future<void> addSize() async {
    final value = await askValue(
      'Agregar talla',
      'Nombre de la talla',
    );

    if (value == null || value.trim().isEmpty) return;

    final size = value.trim();

    final exists = sizes.any(
      (item) => item.toLowerCase() == size.toLowerCase(),
    );

    if (exists) {
      showMessage('La talla ya existe');
      return;
    }

    setState(() {
      sizes.add(size);
      selectedSizes.add(size);
    });
  }

  Future<void> addColor() async {
    final value = await askValue(
      'Agregar color',
      'Nombre del color',
    );

    if (value == null || value.trim().isEmpty) return;

    final color = value.trim();

    final exists = colors.any(
      (item) => item.toLowerCase() == color.toLowerCase(),
    );

    if (exists) {
      showMessage('El color ya existe');
      return;
    }

    setState(() {
      colors.add(color);
      selectedColors.add(color);
    });
  }

  Future<String?> askValue(
    String title,
    String label,
  ) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
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
                  controller.text,
                );
              },
              child: const Text('AGREGAR'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo producto'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    category = value;
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
                  fontSize: 20,
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
                    label: const Text('AGREGAR TALLA'),
                    onPressed: addSize,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Colores',
                style: TextStyle(
                  fontSize: 20,
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
                    label: const Text('AGREGAR COLOR'),
                    onPressed: addColor,
                  ),
                ],
              ),
              if (selectedSizes.isNotEmpty &&
                  selectedColors.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  'Existencias por variante',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...buildVariantFields(),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        )
                      : const Text('GUARDAR PRODUCTO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> buildVariantFields() {
    final widgets = <Widget>[];

    for (final color in selectedColors) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 8,
          ),
          child: Text(
            color.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      for (final size in selectedSizes) {
        widgets.add(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Talla $size',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: stockController(
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
          ),
        );
      }
    }

    return widgets;
  }

  Future<void> save() async {
    final name = nameController.text.trim();

    final cost = double.tryParse(
      costController.text.trim(),
    );

    final price = double.tryParse(
      priceController.text.trim(),
    );

    final minimum = int.tryParse(
      minimumController.text.trim(),
    );

    if (name.isEmpty ||
        cost == null ||
        price == null ||
        minimum == null) {
      showMessage('Completa todos los datos del producto');
      return;
    }

    if (selectedSizes.isEmpty) {
      showMessage('Selecciona una talla');
      return;
    }

    if (selectedColors.isEmpty) {
      showMessage('Agrega y selecciona un color');
      return;
    }

    if (variants.every(
      (variant) => variant['stock'] == 0,
    )) {
      showMessage(
        'Agrega existencia a por lo menos una variante',
      );
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

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'No fue posible guardar el producto: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
