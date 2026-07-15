import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sales_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() =>
      _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  late final SalesRepository repo;
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();

    repo = SalesRepository(
      Supabase.instance.client,
    );

    _loadSales();
  }

  void _loadSales() {
    future = repo.listSales();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadSales();
    });

    await future;
  }

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  String _formatMoney(dynamic value) {
    return '\$${_toDouble(value).toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

    if (date == null) {
      return value.toString();
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }

  String _sellerName(
    Map<String, dynamic> sale,
  ) {
    final sellerName =
        sale['seller_name']?.toString().trim();

    if (sellerName != null &&
        sellerName.isNotEmpty) {
      return sellerName;
    }

    final profile = sale['user_profiles'];

    if (profile is Map) {
      final name =
          profile['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    return 'Sin vendedor';
  }

  String _paymentMethod(
    Map<String, dynamic> sale,
  ) {
    final payments = sale['sale_payments'];

    if (payments is List &&
        payments.isNotEmpty) {
      final payment = payments.first;

      if (payment is Map) {
        final method =
            payment['method']?.toString().trim();

        if (method != null &&
            method.isNotEmpty) {
          return method.toUpperCase();
        }
      }
    }

    return 'SIN PAGO';
  }

  int _variantCount(
    Map<String, dynamic> sale,
  ) {
    final items = sale['sale_items'];

    if (items is List) {
      return items.length;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de ventas',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child:
            FutureBuilder<List<Map<String, dynamic>>>(
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
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.error_outline,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'No se pudo cargar el historial de ventas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ERROR REAL DE SUPABASE:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    snapshot.error.toString(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadSales();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'VOLVER A INTENTAR',
                    ),
                  ),
                ],
              );
            }

            final sales =
                snapshot.data ?? [];

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

                final seller =
                    _sellerName(sale);

                final paymentMethod =
                    _paymentMethod(sale);

                final variants =
                    _variantCount(sale);

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
                        '${_formatDate(sale['created_at'])}\n'
                        'Vendedor: $seller\n'
                        '$paymentMethod · '
                        '$variants variante'
                        '${variants == 1 ? '' : 's'}',
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatMoney(
                            sale['total'],
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sale['status']
                                  ?.toString() ??
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

  double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  String _money(dynamic value) {
    return '\$${_toDouble(value).toStringAsFixed(2)}';
  }

  String _valueOrDash(dynamic value) {
    final text =
        value?.toString().trim() ?? '';

    return text.isEmpty ? '—' : text;
  }

  String _saleDate(dynamic value) {
    if (value == null) {
      return '—';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

    if (date == null) {
      return value.toString();
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }

  String _sellerName() {
    final sellerName =
        sale['seller_name']?.toString().trim();

    if (sellerName != null &&
        sellerName.isNotEmpty) {
      return sellerName;
    }

    final profile = sale['user_profiles'];

    if (profile is Map) {
      final name =
          profile['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    return 'Sin vendedor';
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
                    label: 'Fecha y hora',
                    value: _saleDate(
                      sale['created_at'],
                    ),
                  ),
                  _DetailRow(
                    label: 'Vendedor',
                    value: _sellerName(),
                  ),
                  _DetailRow(
                    label: 'Estado',
                    value: _valueOrDash(
                      sale['status'],
                    ),
                  ),
                  _DetailRow(
                    label: 'Total',
                    value: _money(
                      sale['total'],
                    ),
                  ),
                  _DetailRow(
                    label: 'Costo vendido',
                    value: _money(
                      sale['sold_cost'],
                    ),
                  ),
                  _DetailRow(
                    label: 'Utilidad bruta',
                    value: _money(
                      sale['gross_profit'],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4),
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
                    _valueOrDash(
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
                      _money(item['total']),
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
            padding:
                EdgeInsets.symmetric(horizontal: 4),
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
                  _valueOrDash(
                    payment['method'],
                  ),
                ),
                subtitle:
                    payment['reference'] == null
                        ? null
                        : Text(
                            'Referencia: '
                            '${payment['reference']}',
                          ),
                trailing: Text(
                  _money(payment['amount']),
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
