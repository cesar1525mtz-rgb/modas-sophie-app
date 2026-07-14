import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sales_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() =>
      _SalesHistoryPageState();
}

class _SalesHistoryPageState
    extends State<SalesHistoryPage> {
  late final SalesRepository repo;
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();

    repo = SalesRepository(
      Supabase.instance.client,
    );

    refresh();
  }

  void refresh() {
    setState(() {
      future = repo.listSales();
    });
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;

    return '\$${amount.toStringAsFixed(2)}';
  }

  String saleDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return value.toString();
    }

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month =
        local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour =
        local.hour.toString().padLeft(2, '0');
    final minute =
        local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de ventas'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refresh();

          await future;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState !=
                ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.error_outline,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No se pudo cargar el historial de ventas.',
                    ),
                  ),
                ],
              );
            }

            final sales = snapshot.data ?? [];

            if (sales.isEmpty) {
              return ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 56,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Todavía no hay ventas registradas.',
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];

                final payments =
                    (sale['sale_payments'] as List?) ??
                        [];

                final items =
                    (sale['sale_items'] as List?) ?? [];

                final paymentMethod = payments.isEmpty
                    ? 'SIN PAGO'
                    : payments.first['method']
                            ?.toString() ??
                        'SIN PAGO';

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(
                        Icons.receipt_long_outlined,
                      ),
                    ),
                    title: Text(
                      sale['folio']?.toString() ??
                          'Venta',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding:
                          const EdgeInsets.only(top: 6),
                      child: Text(
                        '${saleDate(sale['created_at'])}\n'
                        '$paymentMethod · '
                        '${items.length} variante'
                        '${items.length == 1 ? '' : 's'}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(sale['total']),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sale['status']?.toString() ??
                              '',
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SaleDetailPage(
                            sale: sale,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class SaleDetailPage extends StatelessWidget {
  final Map<String, dynamic> sale;

  const SaleDetailPage({
    super.key,
    required this.sale,
  });

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;

    return '\$${amount.toStringAsFixed(2)}';
  }

  String valueOrDash(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? '—' : text;
  }

  @override
  Widget build(BuildContext context) {
    final items =
        (sale['sale_items'] as List?) ?? [];

    final payments =
        (sale['sale_payments'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sale['folio']?.toString() ??
              'Detalle de venta',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    label: 'Estado',
                    value: valueOrDash(
                      sale['status'],
                    ),
                  ),
                  _DetailRow(
                    label: 'Total',
                    value: money(
                      sale['total'],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4,
            ),
            child: Text(
              'Productos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            return Card(
              child: ListTile(
                title: Text(
                  item['historical_name']
                          ?.toString() ??
                      'Producto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    valueOrDash(
                      item['historical_sku'],
                    ),
                    if (item['historical_color'] !=
                        null)
                      item['historical_color']
                          .toString(),
                    if (item['historical_size'] !=
                        null)
                      item['historical_size']
                          .toString(),
                  ].join(' · '),
                ),
                trailing: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item['quantity']} pza.',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(item['total']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4,
            ),
            child: Text(
              'Pago',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...payments.map((payment) {
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.payments_outlined,
                ),
                title: Text(
                  valueOrDash(
                    payment['method'],
                  ),
                ),
                subtitle: payment['reference'] == null
                    ? null
                    : Text(
                        'Referencia: '
                        '${payment['reference']}',
                      ),
                trailing: Text(
                  money(payment['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
