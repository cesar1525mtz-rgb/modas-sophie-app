import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../../models/app_user.dart';
import '../sales/pos_page.dart';

class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({
    super.key,
    required this.profile,
  });

  final AppUser profile;

  @override
  State<SellerDashboardPage> createState() =>
      _SellerDashboardPageState();
}

class _SellerDashboardPageState
    extends State<SellerDashboardPage> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  bool _cashOpen = false;
  double _salesToday = 0;
  int _salesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final now = DateTime.now();

      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc();

      final sales = await _client
          .from('sales')
          .select('id,total')
          .eq('created_by', widget.profile.id)
          .eq('status', 'COMPLETADA')
          .gte(
            'created_at',
            startOfDay.toIso8601String(),
          );

      double total = 0;

      for (final sale in sales) {
        total +=
            (sale['total'] as num?)?.toDouble() ?? 0;
      }

      final cashSession = await _client.rpc(
        'get_open_cash_session',
      );

      if (!mounted) return;

      setState(() {
        _salesToday = total;
        _salesCount = sales.length;
        _cashOpen = cashSession != null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el panel: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openSales() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PosPage(),
      ),
    );

    await _loadData();
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Seguro que deseas cerrar sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthRepository(_client).signOut();
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              icon,
              size: 34,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modas Sophie'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Hola, ${widget.profile.name}',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Panel de vendedor',
              style:
                  Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 28),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _infoCard(
                title: 'Mis ventas hoy',
                value:
                    '\$${_salesToday.toStringAsFixed(2)}',
                icon: Icons.point_of_sale,
              ),
              const SizedBox(height: 16),
              _infoCard(
                title: 'Ventas realizadas',
                value: '$_salesCount',
                icon: Icons.receipt_long,
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(
                        _cashOpen
                            ? Icons.lock_open_outlined
                            : Icons.lock_outline,
                        size: 34,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _cashOpen
                                  ? 'Caja abierta'
                                  : 'Caja cerrada',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _cashOpen
                                  ? 'Puedes realizar ventas'
                                  : 'El dueño debe abrir la caja',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed:
                      _cashOpen ? _openSales : null,
                  icon: const Icon(
                    Icons.shopping_cart_checkout,
                  ),
                  label: const Text('IR A VENTAS'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
