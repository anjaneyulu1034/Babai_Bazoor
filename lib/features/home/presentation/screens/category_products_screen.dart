import 'dart:async';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/home_service.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/product_details_screen.dart';
import 'package:flutter/material.dart';

class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.language,
    required this.pincode,
    this.initialSubCategoryId,
  });

  final int categoryId;
  final String categoryName;
  final AppLanguage language;
  final String pincode;
  final int? initialSubCategoryId;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final HomeService _homeService = const HomeService();
  late AppLanguage _activeLanguage;

  bool _isLoading = true;
  String? _error;
  int? _selectedSubCategoryId;
  String? _selectedSort;
  String? _categoryBannerUrl;
  List<HomeSubCategory> _subCategories = const [];
  List<ProductSummary> _products = const [];

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.language;
    _selectedSubCategoryId = widget.initialSubCategoryId;
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scopedLanguage = AppLanguageScope.watch(context);
    if (scopedLanguage != _activeLanguage) {
      _activeLanguage = scopedLanguage;
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parsed = await _homeService.getCategoryProducts(
        language: _activeLanguage,
        categoryId: widget.categoryId,
        subCategoryId: _selectedSubCategoryId,
        sort: _selectedSort,
        pageNumber: 1,
        pageSize: 20,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _categoryBannerUrl = parsed.data?.categoryBannerUrl;
        _subCategories = parsed.data?.subCategories ?? const [];
        _products = parsed.data?.products?.items ?? const [];
        _error = parsed.isSuccess
            ? null
            : (parsed.message ?? 'Unable to load products');
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to load products.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSortLabel = _selectedSort == 'price'
        ? 'Price'
        : _selectedSort == 'newest'
        ? 'Newest'
        : 'Relevance';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                setState(() => _selectedSort = value);
                _loadProducts();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'price', child: Text('Price')),
                PopupMenuItem(value: 'newest', child: Text('Newest')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_vert,
                      size: 16,
                      color: Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedSortLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _loadProducts,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _products.isEmpty
          ? const Center(
              child: Text(
                'No products available in this category',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_categoryBannerUrl != null &&
                          _categoryBannerUrl!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 110,
                              width: double.infinity,
                              child: Image.network(
                                ApiConstants.resolveMediaUrl(
                                  _categoryBannerUrl,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const ColoredBox(
                                    color: Color(0xFFF3F4F6),
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Color(0xFF9CA3AF),
                                        size: 32,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _subCategories.length + 1,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final isAll = index == 0;
                                    final selected = isAll
                                        ? _selectedSubCategoryId == null
                                        : _selectedSubCategoryId ==
                                              _subCategories[index - 1].id;

                                    final label = isAll
                                        ? 'All'
                                        : _subCategories[index - 1].name;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        setState(() {
                                          _selectedSubCategoryId = isAll
                                              ? null
                                              : _subCategories[index - 1].id;
                                        });
                                        _loadProducts();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFF111827)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF111827)
                                                : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = _products[index];
                      final priceText = item.price != null
                          ? 'Rs ${item.price!.toStringAsFixed(0)}'
                          : 'Price unavailable';

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsScreen(
                                productId: item.id,
                                language: _activeLanguage,
                                pincode: widget.pincode,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child:
                                      (item.imageUrl != null &&
                                          item.imageUrl!.trim().isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.network(
                                            ApiConstants.resolveMediaUrl(
                                              item.imageUrl,
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => const Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: Color(0xFF9CA3AF),
                                                  size: 36,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.shopping_basket_outlined,
                                          color: Color(0xFF9CA3AF),
                                          size: 36,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                priceText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: _products.length),
                  ),
                ),
              ],
            ),
    );
  }
}
