import 'dart:async';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:babai_bazor_app/core/services/category_service.dart';
import 'package:babai_bazor_app/core/services/cart_service.dart';
import 'package:babai_bazor_app/core/services/home_service.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/login_required_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/cart_screen.dart';
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
  final CategoryService _categoryService = const CategoryService();
  final CartService _cartService = const CartService();
  final HomeService _homeService = const HomeService();
  late AppLanguage _activeLanguage;

  bool _isLoading = true;
  String? _error;
  int? _selectedSubCategoryId;
  int? _addingProductId;
  String? _selectedSort;
  String? _categoryBannerUrl;
  int _cartItemCount = 0;
  double _cartTotal = 0;
  List<HomeSubCategory> _subCategories = const [];
  List<ProductSummary> _products = const [];

  String get _effectivePincode {
    final p = widget.pincode.trim();
    if (p.isEmpty) {
      return '500001';
    }
    return p;
  }

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.language;
    _selectedSubCategoryId = widget.initialSubCategoryId;
    _loadProducts();
    _loadCartSummary();
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

      final subCategories =
          parsed.data?.subCategories ?? const <HomeSubCategory>[];
      var resolvedSubCategories = subCategories;
      if (resolvedSubCategories.isEmpty) {
        final categoriesResponse = await _categoryService.getCategories(
          language: _activeLanguage,
          type: 'grocery',
        );
        final currentCategory = categoriesResponse.data
            .where((category) => category.id == widget.categoryId)
            .cast<CategorySummary?>()
            .firstWhere((category) => category != null, orElse: () => null);
        if (currentCategory != null &&
            currentCategory.subCategoryItems.isNotEmpty) {
          resolvedSubCategories = currentCategory.subCategoryItems;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _categoryBannerUrl = parsed.data?.categoryBannerUrl;
        _subCategories = resolvedSubCategories;
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

  String _emojiForLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('vegetable')) return '🥦';
    if (normalized.contains('fruit')) return '🍎';
    if (normalized.contains('dairy') || normalized.contains('milk')) {
      return '🥛';
    }
    if (normalized.contains('grocery')) return '🛒';
    return '🛍️';
  }

  String _badgeForProduct(ProductSummary item, int index) {
    if (item.brand != null && item.brand!.trim().isNotEmpty) {
      return item.brand!.trim().toUpperCase();
    }
    if (item.isFeatured == true) {
      return 'FRESH';
    }
    const tags = ['ORGANIC', 'FRESH', 'PREMIUM', 'SEASONAL'];
    return tags[index % tags.length];
  }

  int? _discountPercent(ProductSummary item) {
    final price = item.price;
    final mrp = item.mrpPrice;
    if (price == null || mrp == null || mrp <= 0 || price >= mrp) {
      return null;
    }
    return (((mrp - price) / mrp) * 100).round();
  }

  Future<void> _addToCart(ProductSummary item) async {
    if (_addingProductId == item.id) {
      return;
    }

    final token = await AuthSessionService.instance.getToken();
    if (token == null || token.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoginRequiredScreen(
            language: _activeLanguage,
            message: 'Login is required to add products to cart.',
          ),
        ),
      );
      await _loadCartSummary();
      return;
    }

    setState(() {
      _addingProductId = item.id;
    });

    // Add button should always add exactly one unit.
    final response = await _cartService.addToCart(
      language: _activeLanguage,
      pincode: _effectivePincode,
      request: CartUpdateRequest(productId: item.id, quantity: 1),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _addingProductId = null;
    });

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final itemCount =
          data.totalItems ??
          data.items.fold<int>(0, (sum, entry) => sum + (entry.quantity ?? 0));
      final total =
          data.totalAmount ??
          data.subTotal ??
          data.items.fold<double>(
            0,
            (sum, entry) =>
                sum +
                (entry.totalPrice ??
                    ((entry.unitPrice ?? 0) * (entry.quantity ?? 0))),
          );
      setState(() {
        _cartItemCount = itemCount;
        _cartTotal = total;
      });
    }

    final updatedQty = response.data?.items
        .where((entry) => entry.productId == item.id)
        .cast<CartItemModel?>()
        .firstWhere((entry) => entry != null, orElse: () => null)
        ?.quantity;

    final msg = response.isSuccess
        ? (response.message ??
              (updatedQty != null
                  ? 'Added to cart (Qty: $updatedQty)'
                  : 'Added to cart'))
        : (response.message ??
              (response.errors.isNotEmpty
                  ? response.errors.first
                  : 'Unable to add to cart'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadCartSummary() async {
    final response = await _cartService.getCart(
      language: _activeLanguage,
      pincode: _effectivePincode,
    );

    if (!mounted) {
      return;
    }

    if (!response.isSuccess || response.data == null) {
      setState(() {
        _cartItemCount = 0;
        _cartTotal = 0;
      });
      return;
    }

    final data = response.data!;
    final itemCount =
        data.totalItems ??
        data.items.fold<int>(0, (sum, entry) => sum + (entry.quantity ?? 0));
    final total =
        data.totalAmount ??
        data.subTotal ??
        data.items.fold<double>(
          0,
          (sum, entry) =>
              sum +
              (entry.totalPrice ??
                  ((entry.unitPrice ?? 0) * (entry.quantity ?? 0))),
        );

    setState(() {
      _cartItemCount = itemCount;
      _cartTotal = total;
    });
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CartScreen(language: _activeLanguage, pincode: _effectivePincode),
      ),
    );
    await _loadCartSummary();
  }

  String? _productMediaUrl(ProductSummary item) {
    final candidates = [item.imageUrl, item.image2Url, item.image3Url];
    for (final raw in candidates) {
      final value = raw?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  IconData _staticProductIcon(ProductSummary item) {
    final text = '${item.nameEn ?? item.name} ${item.categoryName ?? ''}'
        .toLowerCase();
    if (text.contains('spinach') ||
        text.contains('leaf') ||
        text.contains('greens')) {
      return Icons.eco;
    }
    if (text.contains('tomato') ||
        text.contains('apple') ||
        text.contains('fruit')) {
      return Icons.apple;
    }
    if (text.contains('potato') ||
        text.contains('onion') ||
        text.contains('vegetable')) {
      return Icons.spa_outlined;
    }
    if (text.contains('milk') ||
        text.contains('dairy') ||
        text.contains('curd')) {
      return Icons.local_drink_outlined;
    }
    if (text.contains('fish') ||
        text.contains('meat') ||
        text.contains('chicken')) {
      return Icons.set_meal_outlined;
    }
    return Icons.shopping_bag_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final selectedSubCategory = _subCategories.where((sub) {
      return sub.id == _selectedSubCategoryId;
    }).toList();
    final totalSubCategoryTiles = _subCategories.length + 1;
    final subCategoryRows = (totalSubCategoryTiles / 3).ceil();
    final subCategoryGridHeight =
        ((subCategoryRows * 44) + ((subCategoryRows - 1) * 8)).toDouble();
    final sectionTitle = selectedSubCategory.isEmpty
        ? widget.categoryName
        : selectedSubCategory.first.localizedName(_activeLanguage);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFE9EBF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF111827),
                size: 20,
              ),
            ),
          ),
        ),
        titleSpacing: 6,
        title: Row(
          children: [
            const Text('🛒', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              widget.categoryName,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
                fontSize: 25,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _subCategories.isEmpty
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
          : Column(
              children: [
                if (_categoryBannerUrl != null &&
                    _categoryBannerUrl!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 96,
                        width: double.infinity,
                        child: Image.network(
                          ApiConstants.resolveMediaUrl(_categoryBannerUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const ColoredBox(
                              color: Color(0xFFE8EBF2),
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFDDE1EA), width: 1),
                    ),
                  ),
                  child: _subCategories.isEmpty
                      ? const SizedBox(
                          height: 40,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No subCategories',
                              style: TextStyle(
                                color: Color(0xFF7A8398),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: subCategoryGridHeight,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _subCategories.length + 1,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 3.3,
                                ),
                            itemBuilder: (context, index) {
                              final isCategoryChip = index == 0;
                              final selected = isCategoryChip
                                  ? _selectedSubCategoryId == null
                                  : _selectedSubCategoryId ==
                                        _subCategories[index - 1].id;
                              final label = isCategoryChip
                                  ? widget.categoryName
                                  : _subCategories[index - 1].localizedName(
                                      _activeLanguage,
                                    );
                              final emoji = _emojiForLabel(label);

                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    _selectedSubCategoryId = isCategoryChip
                                        ? null
                                        : _subCategories[index - 1].id;
                                  });
                                  _loadProducts();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF1FA652)
                                        : const Color(0xFFF2F4F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF1FA652)
                                          : const Color(0xFFD4DAE6),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF454D62),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EBF1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _emojiForLabel(sectionTitle),
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sectionTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_products.length} available',
                                style: const TextStyle(
                                  color: Color(0xFF7A8398),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error ?? 'No products available',
                                  style: const TextStyle(
                                    color: Color(0xFF4B5563),
                                    fontWeight: FontWeight.w600,
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
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final item = _products[index];
                            final discount = _discountPercent(item);
                            final mediaUrl = _productMediaUrl(item);
                            final showImage = mediaUrl != null;
                            final showEmoji =
                                item.emoji != null &&
                                item.emoji!.trim().isNotEmpty;

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
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
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  10,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFDDE1EA),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0F000000),
                                      blurRadius: 5,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE5F4EA),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _badgeForProduct(item, index),
                                        style: const TextStyle(
                                          color: Color(0xFF16964A),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Center(
                                        child: showImage
                                            ? Image.network(
                                                ApiConstants.resolveMediaUrl(
                                                  mediaUrl,
                                                ),
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) {
                                                  if (showEmoji) {
                                                    return Text(
                                                      item.emoji!,
                                                      style: const TextStyle(
                                                        fontSize: 52,
                                                      ),
                                                    );
                                                  }
                                                  return Icon(
                                                    _staticProductIcon(item),
                                                    size: 44,
                                                    color: const Color(
                                                      0xFF93A0B8,
                                                    ),
                                                  );
                                                },
                                              )
                                            : (showEmoji
                                                  ? Text(
                                                      item.emoji!,
                                                      style: const TextStyle(
                                                        fontSize: 52,
                                                      ),
                                                    )
                                                  : Icon(
                                                      _staticProductIcon(item),
                                                      size: 44,
                                                      color: const Color(
                                                        0xFF93A0B8,
                                                      ),
                                                    )),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.localizedName(_activeLanguage),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                        fontSize: 16,
                                        height: 1.12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.localizedUnit(_activeLanguage) ??
                                          '1 kg',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF8B93A8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          item.price != null
                                              ? '₹${item.price!.toStringAsFixed(0)}'
                                              : '₹--',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111827),
                                            fontSize: 29,
                                          ),
                                        ),
                                        if (item.mrpPrice != null &&
                                            item.mrpPrice! >
                                                (item.price ?? 0)) ...[
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              '₹${item.mrpPrice!.toStringAsFixed(0)}',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF939AAE),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 19,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (discount != null)
                                          Text(
                                            '$discount%',
                                            style: const TextStyle(
                                              color: Color(0xFF17A34A),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 36,
                                      child: ElevatedButton(
                                        onPressed: _addingProductId == item.id
                                            ? null
                                            : () => _addToCart(item),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: const Color(
                                            0xFFF44700,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: _addingProductId == item.id
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'ADD +',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _cartItemCount <= 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openCart,
                  child: Ink(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF44700),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_cartItemCount item${_cartItemCount == 1 ? '' : 's'} in cart',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'View Cart →',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${_cartTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 36,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
