import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../inventory/inventory_page.dart';
import '../sales/pos_page.dart';
import '../finance/finance_page.dart';
import 'dashboard_page.dart';
import '../users/users_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  final AppUser profile;
  const OwnerDashboardPage({super.key, required this.profile});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final owner = widget.profile.role == UserRole.owner;
    final pages = [
      DashboardPage(name: widget.profile.name),
      const PosPage(),
      const InventoryPage(),
      const FinancePage(),
      owner ? const UsersPage() : const _Placeholder(title: 'Más'),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Ventas'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Finanzas'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)));
}
