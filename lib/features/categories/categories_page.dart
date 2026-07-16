import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../inventory/new_product_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSaving = false;
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
        throw Exception(
          'No se encontró el negocio del usuario.',
        );
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
          .eq('active', true)
          .order('name');

      final List<Map<String, dynamic>>
          loadedCategories = [];

      for (final categoryRow in categoryRows) {
        final category =
            Map<String, dynamic>.from(categoryRow);

        final categoryProducts = productRows
            .where(
              (product) =>
                  product['category_id']?.toString() ==
                  category['id']?.toString(),
            )
            .map(
              (product) =>
                  Map<String, dynamic>.from(product),
            )
            .toList();

        category['products'] = categoryProducts;
        category['product_count'] =
            categoryProducts.length;

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

  Future<void> showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    var isDialogSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveCategory() async {
              final name = nameController.text.trim();
              final sku = skuController.text.trim().toUpperCase();

              if (name.isEmpty || sku.isEmpty) {
                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Escribe el nombre y el SKU de la categoría.',
                    ),
                  ),
                );

                return;
              }

              setDialogState(() {
                isDialogSaving = true;
              });

              try {
                final businessId = await getBusinessId();

                if (businessId == null) {
                  throw Exception(
                    'No se encontró el negocio del usuario.',
                  );
                }

                await supabase.from('categories').insert({
                  'business_id': businessId,
                  'name': name,
                  'sku_prefix': sku,
                });

                if (!mounted || !dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                await Future<void>.delayed(
                  const Duration(milliseconds: 400),
                );

                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Categoría creada correctamente',
                    ),
                  ),
                );

                await loadCategories();
              } catch (error) {
                if (!mounted || !dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isDialogSaving = false;
                });

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo crear la categoría: $error',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFFFFF9F7),
              title: const Text(
                'Nueva categoría',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la categoría',
                      hintText: 'Ej. Bolsas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: skuController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'SKU de categoría',
                      hintText: 'Ej. BOL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDialogSaving
                      ? null
                      : () {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: const Text('CANCELAR'),
                ),
                FilledButton(
                  onPressed: isDialogSaving ? null : saveCategory,
                  child: isDialogSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('GUARDAR'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    skuController.dispose();
  }

  Future<void> openCategory(
    Map<String, dynamic> category,
  ) async {
    final products =
        List<Map<String, dynamic>>.from(
      category['products'] ?? [],
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryName:
              category['name']?.toString() ??
                  'Categoría',
          products: products,
        ),
      ),
    );

    await loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF9F7),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFFFF3F5),
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
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: showAddCategoryDialog,
        backgroundColor:
            const Color(0xFFFFDDE8),
        foregroundColor:
            const Color(0xFF8F4D62),
        icon: const Icon(Icons.add),
        label: const Text(
          'AGREGAR CATEGORÍA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
        physics:
            const AlwaysScrollableScrollPhysics(),
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
        physics:
            const AlwaysScrollableScrollPhysics(),
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
            'Crea tu primera categoría con el botón de abajo.',
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
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        100,
      ),
      itemCount: categories.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final category = categories[index];

        final name =
            category['name']?.toString() ??
                'Sin nombre';

        final skuPrefix =
            category['sku_prefix']?.toString() ??
                '';

        final productCount =
            category['product_count'] as int? ?? 0;

        return Material(
          color: const Color(0xFFFFF0F4),
          borderRadius:
              BorderRadius.circular(22),
          child: InkWell(
            borderRadius:
                BorderRadius.circular(22),
            onTap: () {
              openCategory(category);
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFFDDE8),
                      borderRadius:
                          BorderRadius.circular(16),
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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style:
                              const TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Color(0xFF211D1E),
                          ),
                        ),
                        if (skuPrefix.isNotEmpty)
                          ...[
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              'SKU: $skuPrefix',
                              style:
                                  const TextStyle(
                                fontSize: 15,
                                color:
                                    Color(0xFF62585B),
                              ),
                            ),
                          ],
                        const SizedBox(height: 5),
                        Text(
                          productCount == 1
                              ? '1 producto'
                              : '$productCount productos',
                          style:
                              const TextStyle(
                            fontSize: 15,
                            color:
                                Color(0xFF8F4D62),
                            fontWeight:
                                FontWeight.w600,
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

class CategoryProductsPage
    extends StatefulWidget {
  final String categoryName;

  final List<Map<String, dynamic>> products;

  const CategoryProductsPage({
    super.key,
    required this.categoryName,
    required this.products,
  });

  @override
  State<CategoryProductsPage> createState() =>
      _CategoryProductsPageState();
}

class _CategoryProductsPageState
    extends State<CategoryProductsPage> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  late List<Map<String, dynamic>> products;

  @override
  void initState() {
    super.initState();

    products =
        List<Map<String, dynamic>>.from(
      widget.products,
    );
  }

  Future<void> openNewProduct() async {
    final productSaved =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewProductPage(
          initialCategoryName:
              widget.categoryName,
        ),
      ),
    );

    if (productSaved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> openProduct(
    Map<String, dynamic> product,
  ) async {
    try {
      final productId =
          product['id'].toString();

      final productRow = await supabase
          .from('products')
          .select(
            'id, name, sku_base, current_cost, sale_price, minimum_stock',
          )
          .eq('id', productId)
          .single();

      final variantRows = await supabase
          .from('product_variants')
          .select(
            'sku, size, color, current_stock',
          )
          .eq('product_id', productId)
          .eq('active', true)
          .order('sku');

      if (!mounted) {
        return;
      }

      final variants = (variantRows as List)
          .map(
            (row) =>
                Map<String, dynamic>.from(row),
          )
          .toList();

      final totalStock = variants.fold<int>(
        0,
        (sum, variant) =>
            sum +
            ((variant['current_stock'] as num?)
                    ?.toInt() ??
                0),
      );

      final minimumStock =
          (productRow['minimum_stock'] as num?)
                  ?.toInt() ??
              0;

      final lowStock =
          totalStock <= minimumStock;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    productRow['name']
                            ?.toString() ??
                        'Producto',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    productRow['sku_base']
                            ?.toString() ??
                        '',
                  ),
                  const SizedBox(height: 18),
                  if (lowStock)
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFFFE8E8),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .warning_amber_rounded,
                            color:
                                Color(0xFFB3261E),
                            size: 30,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'STOCK BAJO — Reabastecer producto',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Color(0xFFB3261E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFEAF5ED),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .check_circle_outline,
                            color:
                                Color(0xFF2E6B3E),
                            size: 30,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Stock disponible',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFF2E6B3E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  detailRow(
                    'Categoría',
                    widget.categoryName,
                  ),
                  detailRow(
                    'Costo',
                    '\$${((productRow['current_cost'] as num?) ?? 0).toDouble().toStringAsFixed(2)}',
                  ),
                  detailRow(
                    'Precio',
                    '\$${((productRow['sale_price'] as num?) ?? 0).toDouble().toStringAsFixed(2)}',
                  ),
                  detailRow(
                    'Stock total',
                    totalStock.toString(),
                  ),
                  detailRow(
                    'Stock mínimo',
                    minimumStock.toString(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Existencias por variante',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...variants.map((variant) {
                    final details = <String>[];

                    final size =
                        variant['size']?.toString();

                    final color =
                        variant['color']?.toString();

                    if (size != null &&
                        size.isNotEmpty) {
                      details.add(
                        'Talla: $size',
                      );
                    }

                    if (color != null &&
                        color.isNotEmpty) {
                      details.add(
                        'Color: $color',
                      );
                    }

                    final description =
                        details.isEmpty
                            ? 'Sin talla ni color'
                            : details.join(' · ');

                    final stock =
                        (variant['current_stock']
                                    as num?)
                                ?.toInt() ??
                            0;

                    return Card(
                      child: ListTile(
                        title: Text(
                          variant['sku']
                                  ?.toString() ??
                              '',
                        ),
                        subtitle: Text(
                          description,
                        ),
                        trailing: Text(
                          '$stock pzas.',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No fue posible abrir el producto: $error',
          ),
        ),
      );
    }
  }

  Widget detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF9F7),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFFFF3F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Color(0xFF211D1E),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF211D1E),
        ),
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: openNewProduct,
        backgroundColor:
            const Color(0xFFFFDDE8),
        foregroundColor:
            const Color(0xFF8F4D62),
        icon: const Icon(Icons.add),
        label: const Text(
          'AGREGAR PRODUCTO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: products.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
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
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Esta categoría todavía no tiene productos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            Color(0xFF62585B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                100,
              ),
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product =
                    products[index];

                final productName =
                    product['name']?.toString() ??
                        'Sin nombre';

                return Material(
                  color:
                      const Color(0xFFFFF0F4),
                  borderRadius:
                      BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(20),
                    onTap: () {
                      openProduct(product);
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFDDE8,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                15,
                              ),
                            ),
                            child: const Icon(
                              Icons
                                  .inventory_2_outlined,
                              color:
                                  Color(0xFF8F4D62),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              productName,
                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    Color(0xFF211D1E),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color:
                                Color(0xFF62585B),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
