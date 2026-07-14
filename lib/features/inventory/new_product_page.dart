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
  final minimumController = TextEditingController();

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

  final List<String> sizes = [
    'CH',
    'M',
    'G',
    'XG',
  ];

  final List<String> colors = [
    'Azul',
    'Verde',
    'Rojo',
    'Negro',
    'Café',
    'Blanco',
    'Rosa',
    'Beige',
  ];

  final Set<String> selectedSizes = {};
  final Set<String> selectedColors = {};

  final Map<String, TextEditingController> stockControllers = {};

  String variantKey(String size, String color) {
    return '$size|$color';
  }

  TextEditingController stockController(
    String size,
    String color,
  ) {
    final key = variantKey(size, color);

    if (!stockControllers.containsKey(key)) {
      stockControllers[key] = TextEditingController(text: '0');
    }

    return stockControllers[key]!;
  }

  List<Map<String, dynamic>> get variants {
    final result = <Map<String, dynamic>>[];

    for (final size in selectedSizes) {
      for (final color in selectedColors) {
        final controller = stockController(size, color);

        result.add({
          'size': size,
          'color': color,
          'stock': int.tryParse(controller.text.trim()) ?? 0,
        });
      }
    }

    return result;
  }

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
                keyboardType: const TextInputType.numberWithOptions(
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
                keyboardType: const TextInputType.numberWithOptions(
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
              const SizedBox(height: 24),
              const Text(
                'Tallas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sizes.map((size) {
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
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Colores',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
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
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (selectedSizes.isNotEmpty &&
                  selectedColors.isNotEmpty) ...[
                const Text(
                  'Existencias por variante',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildVariantFields(),
              ],
              const SizedBox(height: 24),
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

  List<Widget> _buildVariantFields() {
    final widgets = <Widget>[];

    for (final size in selectedSizes) {
      for (final color in selectedColors) {
        widgets.add(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Talla $size · $color',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: stockController(size, color),
                      keyboardType: TextInputType.number,
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
    final cost = double.tryParse(costController.text.trim());
    final price = double.tryParse(priceController.text.trim());
    final minimum = int.tryParse(minimumController.text.trim());

    if (name.isEmpty ||
        cost == null ||
        price == null ||
        minimum == null) {
      showMessage('Completa todos los datos del producto');
      return;
    }

    if (selectedSizes.isEmpty) {
      showMessage('Selecciona al menos una talla');
      return;
    }

    if (selectedColors.isEmpty) {
      showMessage('Selecciona al menos un color');
      return;
    }

    if (variants.every((variant) => variant['stock'] == 0)) {
      showMessage('Agrega existencia a por lo menos una variante');
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
