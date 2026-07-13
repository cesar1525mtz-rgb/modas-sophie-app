import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceRepository {
  final SupabaseClient client;

  FinanceRepository(this.client);

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<Map<String, dynamic>?> openSession() async {
    final result = await client.rpc('get_open_cash_session');

    if (result == null) return null;

    final session = Map<String, dynamic>.from(result as Map);
    final sessionId = session['id']?.toString();

    if (sessionId == null || sessionId.isEmpty) {
      return session;
    }

    double cashSales = 0;
    double cashExpenses = 0;
    double withdrawals = 0;

    final salesRows = await client
        .from('sales')
        .select('id')
        .eq('cash_session_id', sessionId)
        .eq('status', 'COMPLETADA');

    final saleIds = (salesRows as List)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();

    if (saleIds.isNotEmpty) {
      final paymentRows = await client
          .from('sale_payments')
          .select('amount')
          .inFilter('sale_id', saleIds)
          .eq('method', 'EFECTIVO');

      for (final row in paymentRows as List) {
        cashSales += _number(row['amount']);
      }
    }

    final movementRows = await client
        .from('cash_movements')
        .select('movement_type, amount')
        .eq('cash_session_id', sessionId);

    for (final row in movementRows as List) {
      final type = row['movement_type']?.toString();
      final amount = _number(row['amount']);

      if (type == 'SALIDA') {
        cashExpenses += amount;
      } else if (type == 'RETIRO') {
        withdrawals += amount;
      }
    }

    final initialFund = _number(session['initial_fund']);

    session['cash_sales'] = cashSales;
    session['cash_expenses'] = cashExpenses;
    session['withdrawals'] = withdrawals;
    session['expected_cash'] =
        initialFund + cashSales - cashExpenses - withdrawals;

    return session;
  }

  Future<void> openCash(double initialFund) async {
    await client.rpc(
      'open_cash_session',
      params: {
        'p_initial_fund': initialFund,
      },
    );
  }

  Future<void> addExpense({
    required String concept,
    required double amount,
    required String paymentMethod,
    required bool paidFromCash,
    String? notes,
  }) async {
    await client.rpc(
      'register_expense',
      params: {
        'p_concept': concept,
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_paid_from_cash': paidFromCash,
        'p_notes': notes,
      },
    );
  }

  Future<void> addWithdrawal(
    double amount,
    String reason,
  ) async {
    await client.rpc(
      'register_cash_withdrawal',
      params: {
        'p_amount': amount,
        'p_reason': reason,
      },
    );
  }

  Future<Map<String, dynamic>> closeCash(
    double countedCash,
    String? notes,
  ) async {
    final result = await client.rpc(
      'close_cash_session',
      params: {
        'p_counted_cash': countedCash,
        'p_notes': notes,
      },
    );

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> weeklySummary() async {
    final result = await client.rpc(
      'weekly_financial_summary',
    );

    return Map<String, dynamic>.from(result as Map);
  }
}
