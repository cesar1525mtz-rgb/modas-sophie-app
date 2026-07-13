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
  bool actionBusy = false;

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

    if (mounted) {
      setState(() => loading = false);
    }
  }

  double number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String money(dynamic value) {
    return number(value).toStringAsFixed(2);
  }

  dynamic sessionValue(List<String> keys) {
    if (session == null) return null;

    for (final key in keys) {
      if (session!.containsKey(key) && session![key] != null) {
        return session![key];
      }
    }

    return null;
  }

  double get initialFund => number(
        sessionValue([
          'initial_fund',
          'opening_amount',
          'initial_cash',
        ]),
      );

  double get cashSales => number(
        sessionValue([
          'cash_sales',
          'sales_cash',
          'cash_sales_total',
        ]),
      );

  double get cashExpenses => number(
        sessionValue([
          'cash_expenses',
          'expenses_cash',
          'cash_expenses_total',
        ]),
      );

  double get withdrawals => number(
        sessionValue([
          'withdrawals',
          'cash_withdrawals',
          'withdrawals_total',
        ]),
      );

  double get expectedCash {
    final direct = sessionValue([
      'expected_cash',
      'expected_amount',
      'cash_expected',
    ]);

    if (direct != null) {
      return number(direct);
    }

    return initialFund + cashSales - cashExpenses - withdrawals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Esta semana',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _metric(
                    'Ventas',
                    week?['sales_total'],
                  ),
                  _metric(
                    'Costo vendido',
                    week?['sold_cost'],
                  ),
                  _metric(
                    'Ganancia bruta',
                    week?['gross_profit'],
                  ),
                  _metric(
                    'Gastos',
                    week?['expenses'],
                  ),
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
                      onPressed: actionBusy ? null : _openCash,
                      child: const Text('ABRIR CAJA'),
                    )
                  else ...[
                    Card(
                      child: ListTile(
                        title: const Text('Caja abierta'),
                        subtitle: Text(
                          'Fondo inicial: \$${money(initialFund)}',
                        ),
                        trailing: const Icon(Icons.lock_open),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen de caja',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _cashRow(
                              'Fondo inicial',
                              initialFund,
                            ),
                            _cashRow(
                              'Ventas en efectivo',
                              cashSales,
                            ),
                            _cashRow(
                              'Gastos de caja',
                              -cashExpenses,
                            ),
                            _cashRow(
                              'Retiros',
                              -withdrawals,
                            ),
                            const Divider(height: 24),
                            _cashRow(
                              'EFECTIVO ESPERADO',
                              expectedCash,
                              strong: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: actionBusy ? null : _expense,
                      child: const Text('REGISTRAR GASTO'),
                    ),
                    OutlinedButton(
                      onPressed: actionBusy ? null : _withdrawal,
                      child: const Text('REGISTRAR RETIRO'),
                    ),
                    FilledButton(
                      onPressed: actionBusy ? null : _closeCash,
                      child: const Text('CERRAR CAJA'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _metric(
    String title,
    dynamic value, {
    bool strong = false,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          '\$${money(value)}',
          style: TextStyle(
            fontWeight:
                strong ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _cashRow(
    String title,
    double value, {
    bool strong = false,
  }) {
    final prefix = value < 0 ? '-\$' : '\$';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight:
                    strong ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '$prefix${money(value.abs())}',
            style: TextStyle(
              fontWeight:
                  strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> ask(
    String title,
    String label, {
    TextInputType keyboardType = TextInputType.number,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                controller.text,
              );
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _runAction(
    Future<void> Function() action,
  ) async {
    if (actionBusy) return;

    setState(() => actionBusy = true);

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => actionBusy = false);
      }
    }
  }

  Future<void> _openCash() async {
    final value = await ask(
      'Abrir caja',
      'Fondo inicial',
    );

    final amount = double.tryParse(value ?? '');

    if (amount == null || amount < 0) return;

    await _runAction(() async {
      await repo.openCash(amount);
      await refresh();
    });
  }

  Future<void> _expense() async {
    final concept = await ask(
      'Nuevo gasto',
      'Concepto',
      keyboardType: TextInputType.text,
    );

    if (concept == null || concept.trim().isEmpty) {
      return;
    }

    final value = await ask(
      'Nuevo gasto',
      'Importe',
    );

    final amount = double.tryParse(value ?? '');

    if (amount == null || amount <= 0) return;

    await _runAction(() async {
      await repo.addExpense(
        concept: concept.trim(),
        amount: amount,
        paymentMethod: 'EFECTIVO',
        paidFromCash: true,
      );

      await refresh();
    });
  }

  Future<void> _withdrawal() async {
    final reason = await ask(
      'Retiro de efectivo',
      'Motivo',
      keyboardType: TextInputType.text,
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    final value = await ask(
      'Retiro de efectivo',
      'Importe',
    );

    final amount = double.tryParse(value ?? '');

    if (amount == null || amount <= 0) return;

    await _runAction(() async {
      await repo.addWithdrawal(
        amount,
        reason.trim(),
      );

      await refresh();
    });
  }

  Future<void> _closeCash() async {
    final value = await ask(
      'Cerrar caja',
      'Efectivo contado',
    );

    final amount = double.tryParse(value ?? '');

    if (amount == null || amount < 0) return;

    await _runAction(() async {
      final result = await repo.closeCash(
        amount,
        null,
      );

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
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('LISTO'),
            ),
          ],
        ),
      );

      await refresh();
    });
  }
}
