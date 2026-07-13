    import 'package:flutter/material.dart';
    import 'package:supabase_flutter/supabase_flutter.dart';

    import '../../data/finance_repository.dart';

    class FinancePage extends StatefulWidget {
      const FinancePage({super.key});

      @override
      State<FinancePage> createState() => _FinancePageState();
    }

    class _FinancePageState extends State<FinancePage> {
      late final FinanceRepository repo;
      Map<String, dynamic>? session;
      Map<String, dynamic>? week;
      bool loading = true;

      @override
      void initState() {
        super.initState();
        repo = FinanceRepository(Supabase.instance.client);
        refresh();
      }

      Future<void> refresh() async {
        setState(() => loading = true);
        session = await repo.openSession();
        week = await repo.weeklySummary();
        if (mounted) setState(() => loading = false);
      }

      @override
      Widget build(BuildContext context) => Scaffold(
            appBar: AppBar(title: const Text('Finanzas')),
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Esta semana',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _metric('Ventas', week?['sales_total']),
                      _metric('Costo vendido', week?['sold_cost']),
                      _metric('Ganancia bruta', week?['gross_profit']),
                      _metric('Gastos', week?['expenses']),
                      _metric(
                        'UTILIDAD NETA',
                        week?['net_profit'],
                        strong: true,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Caja de hoy',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (session == null)
                        FilledButton(
                          onPressed: _openCash,
                          child: const Text('ABRIR CAJA'),
                        )
                      else ...[
                        Card(
                          child: ListTile(
                            title: const Text('Caja abierta'),
                            subtitle: Text(
                              'Fondo inicial: \$${money(session?['initial_fund'])}',
                            ),
                            trailing: const Icon(Icons.lock_open),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _expense,
                          child: const Text('REGISTRAR GASTO'),
                        ),
                        OutlinedButton(
                          onPressed: _withdrawal,
                          child: const Text('REGISTRAR RETIRO'),
                        ),
                        FilledButton(
                          onPressed: _closeCash,
                          child: const Text('CERRAR CAJA'),
                        ),
                      ],
                    ],
                  ),
          );

      Widget _metric(
        String title,
        dynamic value, {
        bool strong = false,
      }) =>
          Card(
            child: ListTile(
              title: Text(title),
              trailing: Text(
                '\$${money(value)}',
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          );

      String money(dynamic value) =>
          ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);

      Future<String?> ask(
        String title,
        String label, {
        TextInputType keyboardType = TextInputType.text,
      }) async {
        final controller = TextEditingController();

        final result = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(labelText: label),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCELAR'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  controller.text,
                ),
                child: const Text('GUARDAR'),
              ),
            ],
          ),
        );

        controller.dispose();
        return result;
      }

      Future<void> _openCash() async {
        final value = await ask(
          'Abrir caja',
          'Fondo inicial',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
        final amount = double.tryParse(value ?? '');
        if (amount == null || amount < 0) return;

        await repo.openCash(amount);
        await refresh();
      }

      Future<void> _expense() async {
        final concept = await ask('Nuevo gasto', 'Concepto');
        if (concept == null || concept.trim().isEmpty) return;

        final value = await ask(
          'Nuevo gasto',
          'Importe',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
        final amount = double.tryParse(value ?? '');
        if (amount == null || amount <= 0) return;

        await repo.addExpense(
          concept: concept.trim(),
          amount: amount,
          paymentMethod: 'EFECTIVO',
          paidFromCash: true,
        );
        await refresh();
      }

      Future<void> _withdrawal() async {
        final reason = await ask('Retiro de efectivo', 'Motivo');
        if (reason == null || reason.trim().isEmpty) return;

        final value = await ask(
          'Retiro de efectivo',
          'Importe',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
        final amount = double.tryParse(value ?? '');
        if (amount == null || amount <= 0) return;

        await repo.addWithdrawal(amount, reason.trim());
        await refresh();
      }

      Future<void> _closeCash() async {
        final value = await ask(
          'Cerrar caja',
          'Efectivo contado',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
        final amount = double.tryParse(value ?? '');
        if (amount == null || amount < 0) return;

        final result = await repo.closeCash(amount, null);
        if (!mounted) return;

        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Caja cerrada'),
            content: Text(
              'Esperado: \$${money(result['expected_cash'])}\n'
              'Contado: \$${money(result['counted_cash'])}\n'
              'Diferencia: \$${money(result['difference'])}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('LISTO'),
              ),
            ],
          ),
        );

        await refresh();
      }
    }
