import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../finance/finance_page.dart';
import '../inventory/inventory_page.dart';
import '../sales/pos_page.dart';
import '../sales/sales_history_page.dart';
import '../users/users_page.dart';
import 'dashboard_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  final AppUser profile;

  const OwnerDashboardPage({
    super.key,
    required this.profile,
  });

  @override
  State<OwnerDashboardPage> createState() =>
      _OwnerDashboardPageState();
}

class _OwnerDashboardPageState
    extends State<OwnerDashboardPage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final owner = widget.profile.role == UserRole.owner;

    final pages = [
      DashboardPage(name: widget.profile.name),
      const PosPage(),
      const InventoryPage(),
      const FinancePage(),
      _MorePage(owner: owner),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Ventas',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.account_balance_wallet_outlined,
            ),
            label: 'Finanzas',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}

class _MorePage extends StatelessWidget {
  final bool owner;

  const _MorePage({
    required this.owner,
  });

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text(
            '¿Seguro que deseas cerrar sesión?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('CERRAR SESIÓN'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cerrar sesión: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Más'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.receipt_long_outlined,
              ),
              title: const Text(
                'Historial de ventas',
              ),
              subtitle: const Text(
                'Consultar ventas y sus detalles',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SalesHistoryPage(),
                  ),
                );
              },
            ),
          ),
          if (owner)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.people_outline,
                ),
                title: const Text('Usuarios'),
                subtitle: const Text(
                  'Administrar usuarios y vendedores',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const UsersPage(),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.logout,
              ),
              title: const Text(
                'Cerrar sesión',
              ),
              subtitle: const Text(
                'Salir de Modas Sophie',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () {
                _cerrarSesion(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
