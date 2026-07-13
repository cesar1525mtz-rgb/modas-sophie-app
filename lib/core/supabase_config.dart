class SupabaseConfig {
  static const url = 'https://elutnrrgicnxdroswgve.supabase.co';
  static const anonKey = 'sb_publishable_XKyHyjzlVdLBNQS2JzVetQ_G9KCg4SY';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
