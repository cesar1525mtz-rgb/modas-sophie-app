import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/pos_repository.dart';
import '../../models/cart_item.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final PosRepository repo;
  final search = TextEditingController();
  final cart = <CartItem>[];
  List<Map<String, dynamic>> products = [];
  bool loading = false;

  double get total => cart.fold(0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    repo = PosRepository(Supabase.instance.client);
    find('');
  }

  Future<void> find(String value) async {
    setState(() => loading = true);
    try {
      products = await repo.searchProducts(value);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void add(Map<String, dynamic> row) {
    final id = row['variant_id'] as String;
    final existing = cart.where((item) => item.variantId == id).firstOrNull;
    final stock = row['stock'] as int;

    setState(() {
      if (existing != null) {
        if (existing.quantity < stock) existing.quantity++;
      } else if (stock > 0) {
        cart.add(CartItem(
          variantId: id,
          name: row['name'],
          sku: row['sku'],
          size: row['size'],
          color: row['color'],
          unitPrice: (row['sale_price'] as num).toDouble(),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nueva venta')),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: search,
          onChanged: find,
          decoration: const InputDecoration(
            hintText: 'Buscar producto o SKU',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      Expanded(
        child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                return ListTile(
                  title: Text(p['name']),
                  subtitle: Text(
                    '${p['sku']} · ${p['size'] ?? '-'} · ${p['color'] ?? '-'} · Stock ${p['stock']}'
                  ),
                  trailing: Text('\$${(p['sale_price'] as num).toStringAsFixed(2)}'),
                  onTap: () => add(p),
                );
              },
            ),
      ),
      if (cart.isNotEmpty)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                final paid = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutPage(repo: repo, cart: cart),
                  ),
                );
                if (paid == true) {
                  setState(() => cart.clear());
                  find(search.text);
                }
              },
              child: Text('VER CARRITO · \$${total.toStringAsFixed(2)}'),
            ),
          ),
        ),
    ]),
  );
}

class CheckoutPage extends StatefulWidget {
  final PosRepository repo;
  final List<CartItem> cart;
  const CheckoutPage({super.key, required this.repo, required this.cart});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String method = 'EFECTIVO';
  final received = TextEditingController();
  final reference = TextEditingController();
  bool saving = false;

  double get total => widget.cart.fold(0, (sum, item) => sum + item.total);

  Future<void> charge() async {
    final amount = method == 'EFECTIVO'
        ? (double.tryParse(received.text) ?? 0)
        : total;

    if (amount < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El importe recibido es insuficiente.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final folio = await widget.repo.completeSale(
        items: widget.cart.map((item) => {
          'variant_id': item.variantId,
          'quantity': item.quantity,
        }).toList(),
        paymentMethod: method,
        paymentAmount: total,
        reference: reference.text.trim().isEmpty ? null : reference.text.trim(),
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Venta completada'),
          content: Text('Folio: $folio'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('LISTO'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fue posible completar la venta.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cash = double.tryParse(received.text) ?? 0;
    final change = cash > total ? cash - total : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Cobrar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...widget.cart.map((item) => ListTile(
            title: Text(item.name),
            subtitle: Text('${item.sku} · ${item.quantity} pza.'),
            trailing: Text('\$${item.total.toStringAsFixed(2)}'),
          )),
          const Divider(),
          Text('TOTAL  \$${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'EFECTIVO', label: Text('Efectivo')),
              ButtonSegment(value: 'TRANSFERENCIA', label: Text('Transferencia')),
            ],
            selected: {method},
            onSelectionChanged: (value) => setState(() => method = value.first),
          ),
          const SizedBox(height: 16),
          if (method == 'EFECTIVO')
            TextField(
              controller: received,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Dinero recibido',
                helperText: 'Cambio: \$${change.toStringAsFixed(2)}',
                border: const OutlineInputBorder(),
              ),
            )
          else
            TextField(
              controller: reference,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving ? null : charge,
            child: Text(saving ? 'COBRANDO...' : 'COBRAR \$${total.toStringAsFixed(2)}'),
          ),
        ],
      ),
    );
  }
}
