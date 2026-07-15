import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/users_repository.dart';
import '../../models/app_user.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final UsersRepository repo;
  late Future<List<AppUser>> future;

  @override
  void initState() {
    super.initState();
    repo = UsersRepository(Supabase.instance.client);
    refresh();
  }

  void refresh() => setState(() => future = repo.listUsers());

  Future<void> _createSeller() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    bool saving = false;
    bool hidePassword = true;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo vendedor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Contraseña temporal',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setDialogState(
                          () => hidePassword = !hidePassword,
                        );
                      },
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text;

                      if (name.isEmpty ||
                          email.isEmpty ||
                          password.length < 6) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Completa nombre, correo y una contraseña de mínimo 6 caracteres.',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);

                      try {
                        await repo.createSeller(
                          name: name,
                          email: email,
                          password: password,
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);

                        if (this.context.mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No se pudo crear el vendedor: $error',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('CREAR'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    if (created == true && mounted) {
      refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendedor creado correctamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Usuarios'),
        ),
        body: FutureBuilder<List<AppUser>>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'No se pudieron cargar los usuarios.',
                ),
              );
            }

            final users = snapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                110,
              ),
              itemCount: users.length,
              itemBuilder: (_, i) {
                final user = users[i];
                final seller = user.role == UserRole.seller;

                return Card(
                  child: SwitchListTile(
                    value: user.active,
                    onChanged: seller
                        ? (value) async {
                            await repo.setActive(
                              user.id,
                              value,
                            );

                            refresh();
                          }
                        : null,
                    title: Text(user.name),
                    subtitle: Text(
                      seller ? 'Vendedor' : 'Dueño',
                    ),
                    secondary: Icon(
                      seller
                          ? Icons.person_outline
                          : Icons.workspace_premium,
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createSeller,
          icon: const Icon(
            Icons.person_add_alt_1,
          ),
          label: const Text(
            'NUEVO VENDEDOR',
          ),
        ),
      );
}
