import 'dart:async';
import 'dart:convert';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:babai_bazor_app/core/services/cart_service.dart';
import 'package:babai_bazor_app/core/services/category_service.dart';
import 'package:babai_bazor_app/core/services/home_service.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/login_required_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/category_products_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/cart_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/product_details_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/static_design_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.language, this.currentLocation});

  final AppLanguage language;
  final String? currentLocation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CartService _cartService = const CartService();
  final CategoryService _categoryService = const CategoryService();
  final HomeService _homeService = const HomeService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final PageController _bannerPageController = PageController(
    viewportFraction: 0.92,
  );
  late AppLanguage _activeLanguage;

  String? _apiLocation;
  String _apiEtaText = '22 minutes';
  bool _isLoadingHome = true;
  bool _isLoadingCatalog = true;
  String _searchQuery = '';
  String? _catalogError;
  Timer? _searchDebounce;
  Timer? _bannerAutoSlideTimer;
  List<HomeBannerSummary> _banners = const [];
  int _activeBannerIndex = 0;
  List<CategorySummary> _categories = const [];
  Map<int, HomeSection> _sectionsByCategory = const {};
  List<ProductSummary> _featuredProducts = const [];
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;
  String? _resolvedGuestLocation;
  String? _resolvedGuestPincode;
  double? _resolvedGuestLatitude;
  double? _resolvedGuestLongitude;
  bool _isRefreshingCartSummary = false;
  bool _isUpdatingQuickPickCart = false;
  int _cartItemCount = 0;
  double _cartTotal = 0;
  Set<int> _updatingProductIds = <int>{};
  Map<int, int> _cartQtyByProductId = <int, int>{};

  bool get _isGuestMode =>
      (widget.currentLocation ?? '').trim().toLowerCase() == 'guest mode';

  String get _effectivePincode {
    final guestPincode = _resolvedGuestPincode?.trim();
    if (guestPincode != null && guestPincode.isNotEmpty) {
      return guestPincode;
    }
    return _resolvePincode(widget.currentLocation);
  }

  IconData _iconForCategory(String name, {int? categoryId}) {
    switch (categoryId) {
      case 1:
        return Icons.shopping_bag_outlined;
      case 2:
        return Icons.fitness_center_outlined;
      case 3:
        return Icons.medical_services_outlined;
      case 4:
        return Icons.devices_outlined;
      case 5:
        return Icons.spa_outlined;
      case 6:
        return Icons.local_offer_outlined;
      case 7:
        return Icons.trending_down_outlined;
      case 8:
        return Icons.home_outlined;
      case 9:
        return Icons.diamond_outlined;
    }

    final lower = name.toLowerCase();
    if (lower.contains('all')) return Icons.shopping_bag_outlined;
    if (lower.contains('electronic')) return Icons.headphones_outlined;
    if (lower.contains('beauty')) return Icons.spa_outlined;
    if (lower.contains('pharmacy') || lower.contains('medicine')) {
      return Icons.medication_outlined;
    }
    if (lower.contains('fruit') || lower.contains('vegetable')) {
      return Icons.eco_outlined;
    }
    if (lower.contains('home') || lower.contains('kitchen')) {
      return Icons.kitchen_outlined;
    }
    return Icons.grid_view_rounded;
  }

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.language;
    _loadCartSummary();
    if (_isGuestMode) {
      _resolveGuestLocationAndLoadHome();
    } else {
      _loadHomeData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scopedLanguage = AppLanguageScope.watch(context);
    if (scopedLanguage != _activeLanguage) {
      _activeLanguage = scopedLanguage;
      _loadHomeData();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _bannerAutoSlideTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  void _syncBannerAutoSlide() {
    _bannerAutoSlideTimer?.cancel();
    if (_banners.length <= 1) {
      return;
    }

    _bannerAutoSlideTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_bannerPageController.hasClients || _banners.isEmpty) {
        return;
      }

      final nextIndex = (_activeBannerIndex + 1) % _banners.length;
      _bannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadHomeData() async {
    final pincode = _effectivePincode;

    try {
      final sectionsResponse = await _homeService.getHomeSections(
        language: _activeLanguage,
        pincode: pincode,
        latitude: _resolvedGuestLatitude,
        longitude: _resolvedGuestLongitude,
      );
      final fallbackHome = await _homeService.getHome(
        language: _activeLanguage,
        pincode: pincode,
      );

      final sectionsData = sectionsResponse.data;

      List<CategorySummary> categories = const [];
      Map<int, HomeSection> sectionsByCategory = const {};
      List<HomeBannerSummary> banners = const [];
      List<ProductSummary> featuredProducts = const [];

      if (sectionsData != null) {
        banners = sectionsData.banners;
        categories =
            sectionsData.categoryPills
                .map(
                  (pill) => CategorySummary(
                    id: pill.id,
                    name: pill.localizedName(_activeLanguage),
                    emoji: pill.emoji,
                    nameEn: pill.nameEn,
                    nameTe: pill.nameTe,
                    iconUrl: pill.iconUrl,
                    sortOrder: pill.sortOrder,
                  ),
                )
                .toList()
              ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));

        final sectionMap = <int, HomeSection>{};
        for (final section in sectionsData.sections) {
          final categoryId = section.categoryId;
          if (categoryId == null) {
            continue;
          }
          sectionMap[categoryId] = section;
        }
        sectionsByCategory = sectionMap;
      }

      if (banners.isEmpty) {
        banners = fallbackHome.banners;
      }

      if (categories.isEmpty) {
        categories = fallbackHome.categories;
      }

      if (categories.isEmpty) {
        final categoriesResponse = await _categoryService.getCategories(
          language: _activeLanguage,
          type: 'grocery',
        );
        if (categoriesResponse.data.isNotEmpty) {
          categories = categoriesResponse.data;
        }
      }

      int? selectedCategoryId = _selectedCategoryId;
      if (categories.isNotEmpty) {
        final exists = categories.any((c) => c.id == selectedCategoryId);
        if (!exists) {
          selectedCategoryId = categories.first.id;
        }
      } else {
        selectedCategoryId = null;
      }

      final selectedSubCategories =
          sectionsByCategory[selectedCategoryId]?.subCategories ?? const [];
      if (_selectedSubCategoryId != null) {
        final exists = selectedSubCategories.any(
          (item) => item.id == _selectedSubCategoryId,
        );
        if (!exists) {
          _selectedSubCategoryId = null;
        }
      }

      if (_searchQuery.isEmpty) {
        final sectionProducts = selectedCategoryId == null
            ? const <ProductSummary>[]
            : (sectionsByCategory[selectedCategoryId]?.products ?? const []);

        if (sectionProducts.isNotEmpty) {
          featuredProducts = sectionProducts;
        } else {
          featuredProducts = fallbackHome.featuredProducts;
          if (featuredProducts.isEmpty) {
            final productsResponse = await _homeService.getProducts(
              language: _activeLanguage,
              pageNumber: 1,
              pageSize: 20,
            );
            featuredProducts = productsResponse.data?.items ?? const [];
          }
        }
      }

      final zone = sectionsData?.deliveryZone;
      final etaText =
          fallbackHome.etaText ??
          (zone?.estimatedDeliveryHours != null
              ? '${zone!.estimatedDeliveryHours} hours'
              : '22 minutes');

      if (!mounted) return;
      setState(() {
        _apiLocation =
            sectionsData?.deliveryZone?.areaName ??
            fallbackHome.currentLocation;
        _apiEtaText = etaText;
        _banners = banners;
        if (_activeBannerIndex >= _banners.length) {
          _activeBannerIndex = 0;
        }
        _categories = categories;
        _sectionsByCategory = sectionsByCategory;
        _selectedCategoryId = selectedCategoryId;
        if (_searchQuery.isEmpty) {
          _featuredProducts = featuredProducts;
        }
        _isLoadingHome = false;
        _isLoadingCatalog = false;
      });
      _syncBannerAutoSlide();
      _loadCartSummary();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingHome = false;
        _isLoadingCatalog = false;
      });
    }
  }

  Future<void> _resolveGuestLocationAndLoadHome() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _loadHomeData();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _loadHomeData();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _resolvedGuestLatitude = position.latitude;
      _resolvedGuestLongitude = position.longitude;

      final uri = ApiConstants.googleGeocodeByLatLng(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status']?.toString() ?? '';
        final results = body['results'] as List<dynamic>?;

        if (status == 'OK' && results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final formattedAddress =
              first['formatted_address']?.toString().trim() ?? '';
          final components =
              first['address_components'] as List<dynamic>? ?? const [];

          String pincode = '';
          for (final item in components) {
            final map = item as Map<String, dynamic>;
            final types = (map['types'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList();
            if (types.contains('postal_code')) {
              pincode = map['long_name']?.toString() ?? '';
              break;
            }
          }

          if (mounted) {
            setState(() {
              _resolvedGuestLocation = formattedAddress.isEmpty
                  ? null
                  : formattedAddress;
              _resolvedGuestPincode = pincode.trim().length == 6
                  ? pincode.trim()
                  : null;
            });
          }
        }
      }
    } catch (_) {
      // Intentionally fall back to default pincode behavior.
    }

    await _loadHomeData();
  }

  Future<void> _openCategoryProducts(
    CategorySummary category, {
    int? initialSubCategoryId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          categoryId: category.id,
          categoryName: category.localizedName(_activeLanguage),
          language: _activeLanguage,
          pincode: _effectivePincode,
          initialSubCategoryId: initialSubCategoryId,
        ),
      ),
    );
    await _loadCartSummary();
  }

  Future<void> _loadCartSummary() async {
    if (_isRefreshingCartSummary) {
      return;
    }

    _isRefreshingCartSummary = true;
    try {
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
          _cartQtyByProductId = <int, int>{};
        });
        return;
      }

      final data = response.data!;
      final qtyByProduct = <int, int>{};
      for (final item in data.items) {
        final productId = item.productId;
        if (productId == null) {
          continue;
        }
        qtyByProduct[productId] = item.quantity ?? 0;
      }

      final itemCount =
          data.totalItems ??
          data.items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));
      final total =
          data.totalAmount ??
          data.subTotal ??
          data.items.fold<double>(
            0,
            (sum, item) =>
                sum +
                (item.totalPrice ??
                    ((item.unitPrice ?? 0) * (item.quantity ?? 0))),
          );

      setState(() {
        _cartItemCount = itemCount;
        _cartTotal = total;
        _cartQtyByProductId = qtyByProduct;
      });
    } finally {
      _isRefreshingCartSummary = false;
    }
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

  Future<void> _updateQuickPickCart(ProductSummary item, int quantity) async {
    final productId = item.id;
    if (_isUpdatingQuickPickCart || _updatingProductIds.contains(productId)) {
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

    final currentQty = _cartQtyByProductId[productId] ?? 0;
    final normalizedQty = quantity < 0 ? 0 : quantity;

    setState(() {
      _isUpdatingQuickPickCart = true;
      _updatingProductIds = {..._updatingProductIds, productId};
    });

    final response = normalizedQty > currentQty
        ? await _cartService.addToCart(
            language: _activeLanguage,
            pincode: _effectivePincode,
            request: CartUpdateRequest(
              productId: productId,
              quantity: normalizedQty - currentQty,
            ),
          )
        : await _cartService.updateCart(
            language: _activeLanguage,
            pincode: _effectivePincode,
            request: CartUpdateRequest(
              productId: productId,
              quantity: normalizedQty,
            ),
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _updatingProductIds = {..._updatingProductIds}..remove(productId);
      _isUpdatingQuickPickCart = _updatingProductIds.isNotEmpty;
    });

    if (!response.isSuccess) {
      final message =
          response.message ??
          (response.errors.isNotEmpty
              ? response.errors.first
              : 'Unable to update cart');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (response.data != null) {
      final data = response.data!;
      final qtyByProduct = <int, int>{};
      for (final cartItem in data.items) {
        final pid = cartItem.productId;
        if (pid == null) {
          continue;
        }
        qtyByProduct[pid] = cartItem.quantity ?? 0;
      }

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
        _cartQtyByProductId = qtyByProduct;
      });
    } else {
      await _loadCartSummary();
    }
  }

  Future<void> _onBannerTap(HomeBannerSummary banner) async {
    final linkedCategoryId = banner.linkedCategoryId;
    if (linkedCategoryId != null) {
      CategorySummary? category;
      for (final item in _categories) {
        if (item.id == linkedCategoryId) {
          category = item;
          break;
        }
      }
      if (category != null) {
        _openCategoryProducts(category);
        return;
      }

      _openCategoryProducts(
        CategorySummary(
          id: linkedCategoryId,
          name: (banner.title ?? '').trim().isNotEmpty
              ? banner.title!.trim()
              : 'Category Products',
        ),
      );
      return;
    }

    final linkedProductId = banner.linkedProductId;
    if (linkedProductId != null && linkedProductId > 0) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(
            productId: linkedProductId,
            language: _activeLanguage,
            pincode: _effectivePincode,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      await _loadCartSummary();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value.trim());
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    setState(() {
      _isLoadingCatalog = true;
      _catalogError = null;
    });

    try {
      List<ProductSummary> products = const [];
      String? message;

      if (_searchQuery.isNotEmpty) {
        final response = await _homeService.search(
          language: _activeLanguage,
          query: _searchQuery,
          pincode: _effectivePincode,
        );
        products = response.data?.products ?? const [];
        if (!response.isSuccess) {
          message = response.message ?? 'Unable to search products';
        }
      } else {
        final selectedCategoryId = _selectedCategoryId;
        if (selectedCategoryId != null) {
          if (_selectedSubCategoryId != null) {
            final response = await _homeService.getCategoryProducts(
              language: _activeLanguage,
              categoryId: selectedCategoryId,
              subCategoryId: _selectedSubCategoryId,
              pageNumber: 1,
              pageSize: 20,
            );
            products = response.data?.products?.items ?? const [];
            if (!response.isSuccess) {
              message = response.message ?? 'Unable to load products';
            }
          } else {
            final sectionProducts =
                _sectionsByCategory[selectedCategoryId]?.products ?? const [];
            if (sectionProducts.isNotEmpty) {
              products = sectionProducts;
            } else {
              final response = await _homeService.getCategoryProducts(
                language: _activeLanguage,
                categoryId: selectedCategoryId,
                pageNumber: 1,
                pageSize: 20,
              );
              products = response.data?.products?.items ?? const [];
              if (!response.isSuccess) {
                message = response.message ?? 'Unable to load products';
              }
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _featuredProducts = products;
        _catalogError = message;
        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogError = 'Unable to load products.';
        _isLoadingCatalog = false;
      });
    }
  }

  String _resolvePincode(String? location) {
    const fallback = '500001';
    if (location == null || location.trim().isEmpty) {
      return fallback;
    }

    final match = RegExp(r'\b(\d{6})\b').firstMatch(location);
    if (match == null) {
      return fallback;
    }

    return match.group(1) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final locationText = (_apiLocation != null && _apiLocation!.isNotEmpty)
        ? _apiLocation!
        : (_resolvedGuestLocation != null &&
              _resolvedGuestLocation!.trim().isNotEmpty)
        ? _resolvedGuestLocation!
        : (widget.currentLocation != null &&
              widget.currentLocation!.trim().isNotEmpty)
        ? widget.currentLocation!.trim()
        : 'Current location unavailable';

    final pincode = _effectivePincode;
    final compactLocation = locationText.split(',').take(2).join(',').trim();
    final displayLocation = compactLocation.isEmpty
        ? locationText
        : compactLocation;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A1A3D), Color(0xFF2A294D)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_pin,
                                color: Color(0xFFEB5A73),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'DELIVERING TO',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1,
                                  color: Color(0xFFB7BDD3),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              _HeaderActionButton(
                                icon: Icons.confirmation_num_outlined,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Offers coming soon'),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _HeaderActionButton(
                                icon: Icons.shopping_cart_outlined,
                                onTap: () {
                                  _openCart();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 29,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFFFFC53A),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Delivery in ${_apiEtaText.replaceAll('hours', 'hrs')}',
                            style: const TextStyle(
                              color: Color(0xFFADB3C8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_isLoadingHome)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          const SizedBox(height: 14),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.only(left: 12, right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '🔍',
                                  style: TextStyle(fontSize: 19),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    onChanged: _onSearchChanged,
                                    onSubmitted: (_) => _runSearch(),
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Search groceries, services, medicines...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF9AA2B2),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _runSearch,
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFEFE7),
                                    foregroundColor: const Color(0xFFF0531C),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Search',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeading(
                            icon: '🔥',
                            title: "Today's Offers",
                            subtitle: 'Tap to copy code',
                            actionLabel: 'See all →',
                            onActionTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StaticOffersScreen(
                                    language: _activeLanguage,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 136,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                const offerTitles = [
                                  '50% OFF',
                                  '₹200 OFF',
                                  'FREE DELIVERY',
                                ];
                                const offerSubs = [
                                  'First grocery order',
                                  'Services above ₹999',
                                  'Orders above ₹299',
                                ];
                                const offerCodes = [
                                  'BABAI1',
                                  'HOME200',
                                  'FREEDEL',
                                ];
                                const colors = [
                                  Color(0xFFD9EFE5),
                                  Color(0xFFDCE8FC),
                                  Color(0xFFFBE7DC),
                                ];
                                return _OfferCard(
                                  title: offerTitles[index],
                                  subtitle: offerSubs[index],
                                  code: offerCodes[index],
                                  background: colors[index],
                                  onTap: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: offerCodes[index]),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Copied ${offerCodes[index]}',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _banners.isEmpty
                                  ? null
                                  : () => _onBannerTap(
                                      _banners[_activeBannerIndex],
                                    ),
                              child: _MonsoonPromoCard(banners: _banners),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _SectionHeading(
                            icon: '🏪',
                            title: 'Shop by Category',
                          ),
                          const SizedBox(height: 10),
                          _CategoryGridModern(
                            categories: _categories,
                            iconResolver: _iconForCategory,
                            onCategoryTap: (item) =>
                                _openCategoryProducts(item),
                          ),
                          const SizedBox(height: 18),
                          const _SectionHeading(
                            icon: '⚡',
                            title: 'Quick Picks',
                            subtitle: 'Most ordered today',
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 190,
                            child: _featuredProducts.isEmpty
                                ? Center(
                                    child: Text(
                                      _catalogError ?? 'Products loading...',
                                      style: const TextStyle(
                                        color: Color(0xFF6D6D6D),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _featuredProducts.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final item = _featuredProducts[index];
                                      return _QuickPickCard(
                                        item: item,
                                        language: _activeLanguage,
                                        onTap: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductDetailsScreen(
                                                    productId: item.id,
                                                    language: _activeLanguage,
                                                    pincode: pincode,
                                                  ),
                                            ),
                                          );
                                          if (!mounted) {
                                            return;
                                          }
                                          await _loadCartSummary();
                                        },
                                        qty: _cartQtyByProductId[item.id] ?? 0,
                                        isUpdating: _updatingProductIds
                                            .contains(item.id),
                                        onAdd: () => _updateQuickPickCart(
                                          item,
                                          (_cartQtyByProductId[item.id] ?? 0) +
                                              1,
                                        ),
                                        onMinus: () => _updateQuickPickCart(
                                          item,
                                          (_cartQtyByProductId[item.id] ?? 0) -
                                              1,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (_isLoadingCatalog)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          const SizedBox(height: 18),
                          _SectionHeading(
                            icon: '🔧',
                            title: 'Popular Services',
                            subtitle: 'Trusted professionals near you',
                            actionLabel: 'See all →',
                            onActionTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StaticServicesScreen(
                                    language: _activeLanguage,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const _ServiceTile(
                            title: 'Full Home Deep Clean',
                            price: '₹999',
                            strikePrice: '₹1399',
                            discount: '29% OFF',
                            rating: '4.8 (2341)',
                            eta: '4-5 hrs',
                          ),
                          const SizedBox(height: 10),
                          const _ServiceTile(
                            title: 'Bathroom Deep Clean',
                            price: '₹299',
                            strikePrice: '₹449',
                            discount: '33% OFF',
                            rating: '4.7 (1892)',
                            eta: '1-1.5 hrs',
                          ),
                          const SizedBox(height: 18),
                          _SectionHeading(
                            icon: '🎟️',
                            title: 'Coupons for You',
                            actionLabel: 'See all →',
                            onActionTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StaticOffersScreen(
                                    language: _activeLanguage,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Expanded(
                                child: _CouponCard(
                                  accent: Color(0xFFFFE1D5),
                                  title: 'Welcome Offer',
                                  subtitle: '50% off up to ₹150',
                                  code: 'BABAi1',
                                  tag: 'ALL',
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _CouponCard(
                                  accent: Color(0xFFDDF8E8),
                                  title: 'Fresh Farms',
                                  subtitle: '40% off on veggies',
                                  code: 'FARM40',
                                  tag: 'GROCERY',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_cartItemCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
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
            SizedBox(
              height: 72,
              child: Container(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
                ),
                child: Row(
                  children: [
                    const _BottomNavItem(
                      icon: Icons.home_filled,
                      label: 'Home',
                      selected: true,
                    ),
                    _BottomNavItem(
                      icon: Icons.shopping_cart_outlined,
                      label: 'Cart',
                      badgeCount: _cartItemCount,
                      onTap: _openCart,
                    ),
                    _BottomNavItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'Bookings',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StaticBookingHistoryScreen(
                              language: _activeLanguage,
                            ),
                          ),
                        );
                      },
                    ),
                    _BottomNavItem(
                      icon: Icons.confirmation_num_outlined,
                      label: 'Offers',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                StaticOffersScreen(language: _activeLanguage),
                          ),
                        );
                      },
                    ),
                    _BottomNavItem(
                      icon: Icons.person,
                      label: 'Profile',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StaticProfileMenuScreen(
                              language: _activeLanguage,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A5D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1A1E2E),
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (actionLabel != null)
              GestureDetector(
                onTap: onActionTap,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: Color(0xFFF0531C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF8A90A4),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.background,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String code;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 148,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD5D9E7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0B6E4B),
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4D556D),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1B8C57),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonsoonPromoCard extends StatelessWidget {
  const _MonsoonPromoCard({required this.banners});

  final List<HomeBannerSummary> banners;

  @override
  Widget build(BuildContext context) {
    final banner = banners.isEmpty ? null : banners.first;
    return Container(
      height: 178,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1DAE5F), Color(0xFF11BA84)],
        ),
      ),
      child: Stack(
        children: [
          if ((banner?.imageUrl ?? '').trim().isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  ApiConstants.resolveMediaUrl(banner!.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xAA1DAE5F), Color(0xBB0A8F6B)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: SizedBox(
              width: 100,
              height: 68,
              child: Stack(
                children: [
                  Positioned(
                    right: 2,
                    top: 4,
                    child: Container(
                      width: 62,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0x22C7FFE5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 14,
                    child: Container(
                      width: 46,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0x18C7FFE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const Positioned(right: 26, bottom: 2, child: _RainLine()),
                  const Positioned(right: 14, bottom: 6, child: _RainLine()),
                  const Positioned(right: 2, bottom: 2, child: _RainLine()),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LIMITED OFFER',
                  style: TextStyle(
                    color: Color(0xFFD4FFE8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  banner?.title ?? 'Monsoon Fresh Veggies',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 38,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  banner?.subtitle ?? 'Straight from farms · Up to 40% off',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE7FFF2),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7DD1A3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'USE: FARM40',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Row(
                      children: [
                        _PagerDot(active: true),
                        SizedBox(width: 6),
                        _PagerDot(),
                        SizedBox(width: 6),
                        _PagerDot(),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PagerDot extends StatelessWidget {
  const _PagerDot({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0x88FFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _RainLine extends StatelessWidget {
  const _RainLine();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.6,
      child: Container(
        width: 6,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0x2266C7B0),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _CategoryGridModern extends StatelessWidget {
  const _CategoryGridModern({
    required this.categories,
    required this.iconResolver,
    required this.onCategoryTap,
  });

  final List<CategorySummary> categories;
  final IconData Function(String, {int? categoryId}) iconResolver;
  final ValueChanged<CategorySummary> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final activeLanguage = AppLanguageScope.watch(context);
    if (categories.isEmpty) {
      return const SizedBox(
        height: 86,
        child: Center(
          child: Text(
            'No categories available',
            style: TextStyle(color: Color(0xFF6D6D6D)),
          ),
        ),
      );
    }

    final items = categories.length > 8 ? categories.sublist(0, 8) : categories;
    final tileColors = [
      const Color(0xFFDDF0E8),
      const Color(0xFFF9E8E1),
      const Color(0xFFE7ECFA),
      const Color(0xFFFAF0D8),
      const Color(0xFFF8E4F1),
      const Color(0xFFE4F2FA),
      const Color(0xFFE8F5EA),
      const Color(0xFFFBEFB7),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onCategoryTap(item),
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tileColors[index % tileColors.length],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7DCE8)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if ((item.emoji ?? '').trim().isNotEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        item.emoji!,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  )
                else if ((item.iconUrl ?? '').trim().isNotEmpty)
                  Expanded(
                    child: Image.network(
                      ApiConstants.resolveMediaUrl(item.iconUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        iconResolver(
                          item.nameEn ?? item.name,
                          categoryId: item.id,
                        ),
                        size: 28,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Icon(
                      iconResolver(
                        item.nameEn ?? item.name,
                        categoryId: item.id,
                      ),
                      size: 28,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  item.localizedName(activeLanguage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickPickCard extends StatelessWidget {
  const _QuickPickCard({
    required this.item,
    required this.language,
    required this.onTap,
    required this.qty,
    required this.isUpdating,
    required this.onAdd,
    required this.onMinus,
  });

  final ProductSummary item;
  final AppLanguage language;
  final VoidCallback onTap;
  final int qty;
  final bool isUpdating;
  final VoidCallback onAdd;
  final VoidCallback onMinus;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 138,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E6EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F8EB),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                item.isFeatured == true ? 'ORGANIC' : 'FRESH',
                style: const TextStyle(
                  color: Color(0xFF1D9855),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: (item.imageUrl ?? '').trim().isEmpty
                    ? ((item.emoji ?? '').trim().isNotEmpty
                          ? Text(
                              item.emoji!,
                              style: const TextStyle(fontSize: 42),
                            )
                          : const Icon(Icons.eco_rounded, size: 42))
                    : Image.network(
                        ApiConstants.resolveMediaUrl(item.imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            ((item.emoji ?? '').trim().isNotEmpty
                            ? Text(
                                item.emoji!,
                                style: const TextStyle(fontSize: 42),
                              )
                            : const Icon(Icons.eco_rounded, size: 42)),
                      ),
              ),
            ),
            Text(
              item.localizedName(language),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              item.localizedUnit(language) ?? '1 kg',
              style: const TextStyle(color: Color(0xFF7C8399), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  item.price != null
                      ? '₹${item.price!.toStringAsFixed(0)}'
                      : '₹--',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                if (isUpdating)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFF44700),
                    ),
                  )
                else if (qty <= 0)
                  InkWell(
                    onTap: onAdd,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44700),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '+ADD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF44700),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onMinus,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '−',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        InkWell(
                          onTap: onAdd,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '+',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.title,
    required this.price,
    required this.strikePrice,
    required this.discount,
    required this.rating,
    required this.eta,
  });

  final String title;
  final String price;
  final String strikePrice;
  final String discount;
  final String rating;
  final String eta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E6EF)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F8),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('🏠', style: TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '⭐ $rating',
                  style: const TextStyle(
                    color: Color(0xFF6A7289),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '⏱ $eta',
                  style: const TextStyle(
                    color: Color(0xFF6A7289),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 86),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    price,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Text(
                strikePrice,
                style: const TextStyle(
                  color: Color(0xFF9BA1B5),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F7E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  discount,
                  style: const TextStyle(
                    color: Color(0xFF1C9B49),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.tag,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final String code;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F7A44),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6A7289),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1FA652),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.badgeCount = 0,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selected
                      ? const Color(0xFFF44700)
                      : const Color(0xFF6D6D6D),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -10,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44700),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? const Color(0xFFF44700)
                    : const Color(0xFF6D6D6D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
