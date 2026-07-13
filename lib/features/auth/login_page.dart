import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../data/auth_repository.dart';
import '../home/owner_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  String _messageFor(Object exception) {
    if (exception is AuthException) {
      final message = exception.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Correo o contraseña incorrectos.';
      }
      if (message.contains('email not confirmed')) {
        return 'El correo todavía no está confirmado.';
      }
      return 'Error de acceso: ${exception.message}';
    }

    final message = exception.toString();
    if (message.contains('PROFILE_NOT_FOUND')) {
      return 'El acceso fue correcto, pero falta enlazar tu perfil OWNER.';
    }
    if (message.contains('AUTH_SESSION_MISSING')) {
      return 'Supabase no devolvió una sesión válida.';
    }
    if (message.toLowerCase().contains('socket') ||
        message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('clientexception')) {
      return 'No se pudo conectar con Supabase. Revisa tu internet.';
    }
    return 'Error inesperado: $message';
  }

  Future<void> login() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() => error = 'La conexión con Supabase no está configurada.');
      return;
    }

    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Escribe correo y contraseña.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    final repo = AuthRepository(Supabase.instance.client);
    try {
      final response = await repo.signIn(
        email: email.text.trim(),
        password: password.text,
      );

      if (response.session == null || response.user == null) {
        throw StateError('AUTH_SESSION_MISSING');
      }

      final profile = await repo.currentProfile();
      if (!profile.active) {
        await repo.signOut();
        throw StateError('Tu usuario está inactivo.');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerDashboardPage(profile: profile),
        ),
      );
    } catch (exception) {
      if (mounted) setState(() => error = _messageFor(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo_modas_sophie.png',
                    width: 190,
                    height: 190,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'MODAS SOPHIE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Text('Estilo que te define', textAlign: TextAlign.center),
              const SizedBox(height: 40),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => loading ? null : login(),
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: loading ? null : login,
                child: Text(loading ? 'ENTRANDO...' : 'INICIAR SESIÓN'),
              ),
            ],
          ),
        ),
      );
}
