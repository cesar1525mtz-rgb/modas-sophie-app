import 'package:flutter/material.dart';

import '../../data/sales_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final SalesRepository repo = SalesRepository();

  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.getSalesHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      future = repo.getSalesHistory();
    });

    await future;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatMoney(dynamic value) {
    return '\$${_toDouble(value).toStringAsFixed(2)}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString())?.toLocal();

    if (date == null) {
      return value.toString();
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }

  int _variantCount(Map<String, dynamic> sale) {
    final items = sale['sale_items'];

    if (items is List) {
      return items.length;
    }

    return 0;
  }

  String _paymentMethod(Map<String, dynamic> sale) {
    final payments = sale['payments'];

    if (payments is List && payments.isNotEmpty) {
      final payment = payments.first;

      if (payment is Map) {
        final method = payment['method']?.toString();

        if (method != null && method.isNotEmpty) {
          return method.toUpperCase();
        }
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de ventas'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'No se pudo cargar el historial de ventas',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final sales = snapshot.data ?? [];

            if (sales.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text('No hay ventas registradas'),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              itemBuilder: (context, index) {
                final sale = sales[index];

                final folio =
                    sale['folio']?.toString() ?? 'Venta sin folio';

                final total = _formatMoney(sale['total']);

                final sellerName =
                    sale['seller_name']?.toString().trim() ?? '';

                final paymentMethod = _paymentMethod(sale);

                final variants = _variantCount(sale);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(
                      folio,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(sale['created_at'])),
                          const SizedBox(height: 4),
                          Text(
                            sellerName.isEmpty
                                ? 'Sin vendedor'
                                : 'Vendedor: $sellerName',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$paymentMethod · $variants '
                            '${variants == 1 ? 'variante' : 'variantes'}',
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      total,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/sale-detail',
                        arguments: sale,
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
