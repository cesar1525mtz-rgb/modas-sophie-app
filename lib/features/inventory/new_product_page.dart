import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/inventory_repository.dart';

class NewProductPage extends StatefulWidget {
  const NewProductPage({super.key});

  @override
  State<NewProductPage> createState() => _NewProductPageState();
}

class _NewProductPageState extends State<NewProductPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final cost = TextEditingController();
  final price = TextEditingController();
  final minimumStock = TextEditingController(text: '2');
  final size = TextEditingController();
  final color = TextEditingController();
  final stock = TextEditingController(text: '1');

  late final InventoryRepository repository;
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

  @override
  void initState() {
    super.initState();
    repository = InventoryRepository(Supabase.instance.client);
  }

  @override
  void dispose() {
    name.dispose();
    cost.dispose();
    price.dispose();
    minimumStock.dispose();
    size.dispose();
    color.dispose();
    stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo producto')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _required,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: categories
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: saving
                  ? null
                  : (value) => setState(() => category = value!),
            ),
            TextFormField(
              controller: cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Costo de compra'),
              validator: _required,
            ),
            TextFormField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Precio de venta'),
              validator: _required,
            ),
            TextFormField(
              controller: minimumStock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock mínimo'),
            ),
            const Divider(height: 32),
            Text(
              'Primera variante',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextFormField(
              controller: size,
              decoration:
                  const InputDecoration(labelText: 'Talla (opcional)'),
            ),
            TextFormField(
              controller: color,
              decoration:
                  const InputDecoration(labelText: 'Color (opcional)'),
            ),
            TextFormField(
              controller: stock,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Cantidad inicial'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('GUARDAR PRODUCTO'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'Campo obligatorio'
        : null;
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;

    final parsedCost = double.tryParse(cost.text.trim());
    final parsedPrice = double.tryParse(price.text.trim());

    if (parsedCost == null || parsedPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa costo y precio de venta')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await repository.createProduct(
        categoryName: category,
        name: name.text.trim(),
        cost: parsedCost,
        salePrice: parsedPrice,
        minimumStock: int.tryParse(minimumStock.text.trim()) ?? 0,
        size: size.text.trim().isEmpty ? null : size.text.trim(),
        color: color.text.trim().isEmpty ? null : color.text.trim(),
        initialStock: int.tryParse(stock.text.trim()) ?? 0,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
