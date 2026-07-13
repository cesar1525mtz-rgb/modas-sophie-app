import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/dashboard_repository.dart';

class DashboardPage extends StatefulWidget {
  final String name;
  const DashboardPage({super.key, required this.name});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardRepository repo;
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    repo = DashboardRepository(Supabase.instance.client);
    future = repo.today();
  }

  String money(dynamic value) =>
      ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Hola, ${widget.name}')),
    body: RefreshIndicator(
      onRefresh: () async => setState(() => future = repo.today()),
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: const [
              SizedBox(height: 220),
              Center(child: Text('No fue posible cargar el resumen.')),
            ]);
          }

          final data = snapshot.data ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Metric(title: 'Ventas hoy', value: '\$${money(data['sales_total'])}'),
              _Metric(title: 'Utilidad neta', value: '\$${money(data['net_profit'])}'),
              _Metric(title: 'Gastos', value: '\$${money(data['expenses'])}'),
              _Metric(title: 'Ventas realizadas', value: '${data['sales_count'] ?? 0}'),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    data['cash_open'] == true ? Icons.lock_open : Icons.lock_outline,
                  ),
                  title: Text(
                    data['cash_open'] == true ? 'Caja abierta' : 'Caja cerrada',
                  ),
                  subtitle: const Text('Desliza hacia abajo para actualizar'),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  final String title;
  final String value;
  const _Metric({required this.title, required this.value});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}
