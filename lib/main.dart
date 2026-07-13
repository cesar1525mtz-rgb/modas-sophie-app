import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/supabase_config.dart';
import 'data/auth_repository.dart';
import 'features/auth/login_page.dart';
import 'features/home/owner_dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  runApp(const ModasSophieApp());
}

class ModasSophieApp extends StatelessWidget {
  const ModasSophieApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Modas Sophie',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SessionGate(),
      );
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Widget> destination = _resolve();

  Future<Widget> _resolve() async {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      return const LoginPage();
    }

    try {
      final repo = AuthRepository(Supabase.instance.client);
      final profile = await repo.currentProfile();
      if (!profile.active) {
        await repo.signOut();
        return const LoginPage();
      }
      return OwnerDashboardPage(profile: profile);
    } catch (_) {
      await Supabase.instance.client.auth.signOut();
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
        future: destination,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data ?? const LoginPage();
        },
      );
}
