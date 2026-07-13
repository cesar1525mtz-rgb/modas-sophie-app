import 'package:flutter/material.dart';
import '../../core/sku_service.dart';
import '../../models/product.dart';

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

  String category = 'Blusas';

  final prefixes = const {
    'Blusas': 'BLU',
    'Vestidos': 'VES',
    'Pantalón dama': 'PDA',
    'Playera caballero': 'PLC',
    'Bóxer': 'BOX',
    'Calcetines': 'CAL',
    'Bolsas': 'BOL',
    'Mochilas': 'MOC',
    'Fundas celular': 'FUN',
    'Cables': 'CAB',
  };

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
              items: prefixes.keys
                  .map((item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => category = value!),
            ),
            TextFormField(
              controller: cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Costo de compra'),
              validator: _required,
            ),
            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio de venta'),
              validator: _required,
            ),
            TextFormField(
              controller: minimumStock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock mínimo'),
            ),
            const Divider(height: 32),
            Text('Primera variante',
                style: Theme.of(context).textTheme.titleMedium),
            TextFormField(
              controller: size,
              decoration: const InputDecoration(labelText: 'Talla (opcional)'),
            ),
            TextFormField(
              controller: color,
              decoration: const InputDecoration(labelText: 'Color (opcional)'),
            ),
            TextFormField(
              controller: stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad inicial'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('GUARDAR PRODUCTO'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;

  void _save() {
    if (!formKey.currentState!.validate()) return;

    // Consecutivo temporal del prototipo. Supabase lo generará de forma atómica.
    final base = SkuService.baseSku(
      prefix: prefixes[category]!,
      consecutive: DateTime.now().millisecondsSinceEpoch % 10000,
    );

    final variant = ProductVariant(
      sku: SkuService.variantSku(
        baseSku: base,
        size: size.text,
        color: color.text,
      ),
      size: size.text.isEmpty ? null : size.text,
      color: color.text.isEmpty ? null : color.text,
      stock: int.tryParse(stock.text) ?? 0,
    );

    Navigator.pop(
      context,
      Product(
        skuBase: base,
        name: name.text.trim(),
        category: category,
        cost: double.parse(cost.text),
        salePrice: double.parse(price.text),
        minimumStock: int.tryParse(minimumStock.text) ?? 0,
        variants: [variant],
      ),
    );
  }
}
