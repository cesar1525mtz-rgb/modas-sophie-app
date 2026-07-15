import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<String?> getBusinessId() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final profile = await supabase
        .from('user_profiles')
        .select('business_id')
        .eq('id', user.id)
        .maybeSingle();

    return profile?['business_id']?.toString();
  }

  Future<void> loadCategories() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final businessId = await getBusinessId();

      if (businessId == null) {
        throw Exception('No se encontró el negocio del usuario.');
      }

      final categoryRows = await supabase
          .from('categories')
          .select('id, name, sku_prefix')
          .eq('business_id', businessId)
          .order('name');

      final productRows = await supabase
          .from('products')
          .select('id, name, category_id')
          .eq('business_id', businessId)
          .order('name');

      final List<Map<String, dynamic>> loadedCategories = [];

      for (final categoryRow in categoryRows) {
        final category = Map<String, dynamic>.from(categoryRow);

        final categoryProducts = productRows
            .where(
              (product) =>
                  product['category_id']?.toString() ==
                  category['id']?.toString(),
            )
            .map((product) => Map<String, dynamic>.from(product))
            .toList();

        category['products'] = categoryProducts;
        category['product_count'] = categoryProducts.length;

        loadedCategories.add(category);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        categories = loadedCategories;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  void openCategory(Map<String, dynamic> category) {
    final products = List<Map<String, dynamic>>.from(
      category['products'] ?? [],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryName: category['name']?.toString() ?? 'Categoría',
          skuPrefix: category['sku_prefix']?.toString(),
          products: products,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Categorías',
          style: TextStyle(
            color: Color(0xFF211D1E),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF211D1E),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadCategories,
        child: buildBody(),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Color(0xFF8F4D62),
          ),
          const SizedBox(height: 16),
          const Text(
            'No se pudieron cargar las categorías',
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
            onPressed: loadCategories,
            child: const Text('REINTENTAR'),
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
            color: Color(0xFF8F4D62),
          ),
          SizedBox(height: 20),
          Text(
            'Sin categorías',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Las categorías que registres al crear productos aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF62585B),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final category = categories[index];

        final name = category['name']?.toString() ?? 'Sin nombre';
        final skuPrefix = category['sku_prefix']?.toString() ?? '';
        final productCount = category['product_count'] as int? ?? 0;

        return Material(
          color: const Color(0xFFFFF0F4),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => openCategory(category),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDDE8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF8F4D62),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF211D1E),
                          ),
                        ),
                        if (skuPrefix.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'SKU: $skuPrefix',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF62585B),
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          productCount == 1
                              ? '1 producto'
                              : '$productCount productos',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF8F4D62),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF62585B),
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CategoryProductsPage extends StatelessWidget {
  final String categoryName;
  final String? skuPrefix;
  final List<Map<String, dynamic>> products;

  const CategoryProductsPage({
    super.key,
    required this.categoryName,
    required this.skuPrefix,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF3F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          categoryName,
          style: const TextStyle(
            color: Color(0xFF211D1E),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF211D1E),
        ),
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
                      color: Color(0xFF8F4D62),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Sin productos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Esta categoría todavía no tiene productos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF62585B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                final productName =
                    product['name']?.toString() ?? 'Sin nombre';

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDDE8),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF8F4D62),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF211D1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
