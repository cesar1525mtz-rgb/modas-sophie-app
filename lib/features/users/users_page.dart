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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Usuarios')),
    body: FutureBuilder<List<AppUser>>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudieron cargar los usuarios.'));
        }

        final users = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final user = users[i];
            final seller = user.role == UserRole.seller;
            return Card(
              child: SwitchListTile(
                value: user.active,
                onChanged: seller ? (value) async {
                  await repo.setActive(user.id, value);
                  refresh();
                } : null,
                title: Text(user.name),
                subtitle: Text(seller ? 'Vendedor' : 'Dueño'),
                secondary: Icon(seller ? Icons.person_outline : Icons.workspace_premium),
              ),
            );
          },
        );
      },
    ),
  );
}
