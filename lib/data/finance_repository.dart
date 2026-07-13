import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceRepository {
  final SupabaseClient client;
  FinanceRepository(this.client);

  Future<Map<String, dynamic>?> openSession() async {
    return await client.rpc('get_open_cash_session');
  }

  Future<void> openCash(double initialFund) async {
    await client.rpc('open_cash_session', params: {
      'p_initial_fund': initialFund,
    });
  }

  Future<void> addExpense({
    required String concept,
    required double amount,
    required String paymentMethod,
    required bool paidFromCash,
    String? notes,
  }) async {
    await client.rpc('register_expense', params: {
      'p_concept': concept,
      'p_amount': amount,
      'p_payment_method': paymentMethod,
      'p_paid_from_cash': paidFromCash,
      'p_notes': notes,
    });
  }

  Future<void> addWithdrawal(double amount, String reason) async {
    await client.rpc('register_cash_withdrawal', params: {
      'p_amount': amount,
      'p_reason': reason,
    });
  }

  Future<Map<String, dynamic>> closeCash(double countedCash, String? notes) async {
    final result = await client.rpc('close_cash_session', params: {
      'p_counted_cash': countedCash,
      'p_notes': notes,
    });
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> weeklySummary() async {
    final result = await client.rpc('weekly_financial_summary');
    return Map<String, dynamic>.from(result);
  }
}
