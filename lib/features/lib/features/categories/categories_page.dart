import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  SupabaseClient get client => Supabase.instance.client;

  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final categoriesResponse = await client
          .from('categories')
          .select('id,name,sku_prefix,active')
          .eq('active', true)
          .order('name');

      final productsResponse = await client
          .from('products')
          .select('id,name,category_id')
          .order('name');

      if (!mounted) return;

      setState(() {
        categories =
            List<Map<String, dynamic>>.from(categoriesResponse);

        products =
            List<Map<String, dynamic>>.from(productsResponse);

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  int _productCount(String categoryId) {
    return products
        .where(
          (product) =>
              product['category_id']?.toString() == categoryId,
        )
        .length;
  }

  List<Map<String, dynamic>> _productsForCategory(
    String categoryId,
  ) {
    return products
        .where(
          (product) =>
              product['category_id']?.toString() == categoryId,
        )
        .toList();
  }

  void _openCategory(Map<String, dynamic> category) {
    final categoryId = category['id'].toString();
    final categoryName =
        (category['name'] ?? 'Categoría').toString();

    final categoryProducts =
        _productsForCategory(categoryId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryName: categoryName,
          products: categoryProducts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            onPressed: loading ? null : _loadCategories,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCategories,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.error_outline,
            size: 64,
          ),
          const SizedBox(height: 20),
          const Text(
            'No fue posible cargar las categorías',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loadCategories,
            child: const Text('INTENTAR DE NUEVO'),
          ),
        ],
      );
    }

    if (categories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 100),
          Icon(
            Icons.category_outlined,
            size: 72,
          ),
          SizedBox(height: 20),
          Text(
            'No hay categorías',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Las categorías que agregues al crear productos aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        32,
      ),
      children: [
        Text(
          '${categories.length} categorías',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...categories.map((category) {
          final categoryId = category['id'].toString();

          final categoryName =
              (category['name'] ?? 'Sin nombre').toString();

          final skuPrefix =
              (category['sku_prefix'] ?? '').toString();

          final count = _productCount(categoryId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openCategory(category),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 34,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (skuPrefix.isNotEmpty)
                              Text(
                                'SKU: $skuPrefix',
                                style: const TextStyle(
                                  fontSize: 15,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              count == 1
                                  ? '1 producto'
                                  : '$count productos',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class CategoryProductsPage extends StatelessWidget {
  final String categoryName;
  final List<Map<String, dynamic>> products;

  const CategoryProductsPage({
    super.key,
    required this.categoryName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
      ),
      body: products.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No hay productos en esta categoría',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];

                final productName =
                    (product['name'] ?? 'Sin nombre').toString();

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                    ),
                    title: Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
