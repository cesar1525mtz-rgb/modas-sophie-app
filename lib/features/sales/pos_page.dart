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

  final List<CartItem> cart = [];
  List<Map<String, dynamic>> products = [];

  bool loading = false;

  double get total =>
      cart.fold(0.0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();

    repo = PosRepository(
      Supabase.instance.client,
    );

    find('');
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> find(String value) async {
    setState(() => loading = true);

    try {
      products = await repo.searchProducts(value);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  int stockFor(String variantId) {
    for (final product in products) {
      if (product['variant_id'] == variantId) {
        return (product['stock'] as num).toInt();
      }
    }

    return 0;
  }

  void add(Map<String, dynamic> row) {
    final id = row['variant_id'] as String;

    final stock = (row['stock'] as num).toInt();

    CartItem? existing;

    for (final item in cart) {
      if (item.variantId == id) {
        existing = item;
        break;
      }
    }

    setState(() {
      if (existing != null) {
        if (existing!.quantity < stock) {
          existing!.quantity++;
        }
      } else if (stock > 0) {
        cart.add(
          CartItem(
            variantId: id,
            name: row['name'] as String,
            sku: row['sku'] as String,
            size: row['size'] as String?,
            color: row['color'] as String?,
            unitPrice:
                (row['sale_price'] as num).toDouble(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
      ),
      body: Column(
        children: [
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
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (_, i) {
                      final p = products[i];

                      return ListTile(
                        title: Text(
                          p['name'] as String,
                        ),
                        subtitle: Text(
                          '${p['sku']} · '
                          '${p['size'] ?? '-'} · '
                          '${p['color'] ?? '-'} · '
                          'Stock ${p['stock']}',
                        ),
                        trailing: Text(
                          '\$${(p['sale_price'] as num).toStringAsFixed(2)}',
                        ),
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
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final stockByVariant = <String, int>{};

                      for (final item in cart) {
                        stockByVariant[item.variantId] =
                            stockFor(item.variantId);
                      }

                      final paid = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutPage(
                            repo: repo,
                            cart: cart,
                            stockByVariant: stockByVariant,
                          ),
                        ),
                      );

                      if (paid == true) {
                        setState(() {
                          cart.clear();
                        });

                        await find(search.text);
                      } else {
                        setState(() {});
                      }
                    },
                    child: Text(
                      'VER CARRITO · \$${total.toStringAsFixed(2)}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  final PosRepository repo;
  final List<CartItem> cart;
  final Map<String, int> stockByVariant;

  const CheckoutPage({
    super.key,
    required this.repo,
    required this.cart,
    required this.stockByVariant,
  });

  @override
  State<CheckoutPage> createState() =>
      _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String method = 'EFECTIVO';

  final received = TextEditingController();
  final reference = TextEditingController();

  bool saving = false;

  double get total => widget.cart.fold(
        0.0,
        (sum, item) => sum + item.total,
      );

  @override
  void dispose() {
    received.dispose();
    reference.dispose();
    super.dispose();
  }

  void increase(CartItem item) {
    final stock =
        widget.stockByVariant[item.variantId] ?? 0;

    if (item.quantity >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay más existencia disponible',
          ),
        ),
      );

      return;
    }

    setState(() {
      item.quantity++;
    });
  }

  void decrease(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        widget.cart.remove(item);
      }
    });

    if (widget.cart.isEmpty) {
      Navigator.pop(context);
    }
  }

  Future<void> charge() async {
    final amount = method == 'EFECTIVO'
        ? (double.tryParse(received.text) ?? 0)
        : total;

    if (amount < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El importe recibido es insuficiente.',
          ),
        ),
      );

      return;
    }

    setState(() => saving = true);

    try {
      final folio = await widget.repo.completeSale(
        items: widget.cart
            .map(
              (item) => {
                'variant_id': item.variantId,
                'quantity': item.quantity,
              },
            )
            .toList(),
        paymentMethod: method,
        paymentAmount: total,
        reference: reference.text.trim().isEmpty
            ? null
            : reference.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Venta completada'),
          content: Text('Folio: $folio'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('LISTO'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No fue posible completar la venta: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cash =
        double.tryParse(received.text) ?? 0;

    final change =
        cash > total ? cash - total : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobrar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...widget.cart.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(item.sku),
                          const SizedBox(height: 4),
                          Text(
                            '\$${item.unitPrice.toStringAsFixed(2)} c/u',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: saving
                          ? null
                          : () => decrease(item),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: saving
                          ? null
                          : () => increase(item),
                      icon: const Icon(
                        Icons.add_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Text(
            'TOTAL \$${total.toStringAsFixed(2)}',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'EFECTIVO',
                label: Text('Efectivo'),
              ),
              ButtonSegment<String>(
                value: 'TRANSFERENCIA',
                label: Text('Transferencia'),
              ),
            ],
            selected: {method},
            onSelectionChanged: saving
                ? null
                : (value) {
                    setState(() {
                      method = value.first;
                    });
                  },
          ),
          const SizedBox(height: 16),
          if (method == 'EFECTIVO')
            TextField(
              controller: received,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Dinero recibido',
                helperText:
                    'Cambio: \$${change.toStringAsFixed(2)}',
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : charge,
              child: Text(
                saving
                    ? 'COBRANDO...'
                    : 'COBRAR \$${total.toStringAsFixed(2)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
