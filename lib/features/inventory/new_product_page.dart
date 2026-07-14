import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewProductPage extends StatefulWidget {
  const NewProductPage({super.key});

  @override
  State<NewProductPage> createState() => _NewProductPageState();
}

class _NewProductPageState extends State<NewProductPage> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final costController = TextEditingController();
  final priceController = TextEditingController();
  final minimumController = TextEditingController(text: '2');

  final client = Supabase.instance.client;

  bool saving = false;

  String category = 'Blusas';

  final categories = const [
    'Blusas',
    'Vestidos',
    'Pantalón dama',
    'Playera caballero',
    'Bóxer',
    'Calcetines',
    'Bolsas',
    'Mochilas',
    'Fundas celular',
    'Cables',
  ];

  final sizes = const [
    'CH',
    'M',
    'G',
    'XG',
  ];

  final colors = const [
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

    return stockControllers.putIfAbsent(
      key,
      () => TextEditingController(text: '0'),
    );
  }

  List<Map<String, dynamic>> get variants {
    final result = <Map<String, dynamic>>[];

    for (final color in selectedColors) {
      for (final size in selectedSizes) {
        final stock = int.tryParse(
              stockController(size, color).text.trim(),
            ) ??
            0;

        result.add({
          'size': size,
          'color': color,
          'stock': stock,
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
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
              ),
              validator: requiredField,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Categoría',
              ),
              items: categories
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  category = value;
                });
              },
            ),
            TextFormField(
              controller: costController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Costo de compra',
              ),
              validator: requiredField,
            ),
            TextFormField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio de venta',
              ),
              validator: requiredField,
            ),
            TextFormField(
              controller: minimumController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock mínimo',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Selecciona tallas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  onSelected: (
