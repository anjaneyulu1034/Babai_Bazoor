import 'dart:async';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:babai_bazor_app/core/services/category_service.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/cart_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/orders_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/product_details_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.language, this.currentLocation});

  final AppLanguage language;
  final String? currentLocation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CategoryService _categoryService = const CategoryService();
  final TextEditingController _searchController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  late AppLanguage _activeLanguage;

  String? _apiLocation;
  bool _isLoadingHome = true;
  bool _isLoadingCatalog = true;
  bool _isListening = false;
  String _searchQuery = '';
  String? _catalogError;
  Timer? _searchDebounce;
  List<CategorySummary> _categories = const [];
  List<ProductSummary> _featuredProducts = const [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.language;
    _loadHomeData();
    _loadCatalogData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scopedLanguage = AppLanguageScope.watch(context);
    if (scopedLanguage != _activeLanguage) {
      _activeLanguage = scopedLanguage;
      _loadHomeData();
      _loadCatalogData();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    final pincode = _resolvePincode(widget.currentLocation);

    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.apiV1}/home',
      ).replace(queryParameters: {'pincode': pincode});

      final response = await http.get(
        uri,
        headers: {
          ApiHeaders.contentType: ApiHeaders.applicationJson,
          ApiHeaders.acceptLanguage: _activeLanguage.code,
        },
      );

      final homeResponse = HomeApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );

      if (!mounted) return;
      setState(() {
        _apiLocation = homeResponse.currentLocation;
        _isLoadingHome = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHome = false);
    }
  }

  Future<void> _loadCatalogData() async {
    setState(() {
      _isLoadingCatalog = true;
      _catalogError = null;
    });

    try {
      List<CategorySummary> categories = const [];
      final parsedCategories = await _categoryService.getCategories(
        language: _activeLanguage,
      );
      if (!parsedCategories.isSuccess) {
        if (!mounted) {
          return;
        }
        setState(() {
          _categories = const [];
          _featuredProducts = const [];
          _selectedCategoryId = null;
          _catalogError =
              parsedCategories.message ?? 'Unable to load categories';
          _isLoadingCatalog = false;
        });
        return;
      }
      categories = parsedCategories.data;

      int? selectedCategoryId = _selectedCategoryId;
      final selectedStillExists = categories.any(
        (item) => item.id == selectedCategoryId,
      );
      if (!selectedStillExists) {
        selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
      }

      List<ProductSummary> products = const [];
      if (selectedCategoryId != null) {
        final productsResponse = await _fetchProducts(
          categoryId: selectedCategoryId,
          search: _searchQuery,
        );
        products = productsResponse.data?.items ?? const [];

        if (!productsResponse.isSuccess && !mounted) {
          return;
        }
        if (!productsResponse.isSuccess) {
          setState(() {
            _catalogError =
                productsResponse.message ?? 'Unable to load products';
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId = selectedCategoryId;
        _featuredProducts = products;
        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogError = 'Unable to load categories and products.';
        _isLoadingCatalog = false;
      });
    }
  }

  Future<void> _showCategoryDetails(CategorySummary category) async {
    final details = await _categoryService.getCategoryDetails(
      language: _activeLanguage,
      id: category.id,
    );

    if (!mounted) {
      return;
    }

    if (!details.isSuccess || details.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(details.message ?? 'Unable to load category details'),
        ),
      );
      return;
    }

    final item = details.data!;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text('Category ID: ${item.id}'),
              const SizedBox(height: 4),
              Text('Products: ${item.productCount ?? 0}'),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _apiHeaders() async {
    final headers = <String, String>{
      ApiHeaders.contentType: ApiHeaders.applicationJson,
      ApiHeaders.acceptLanguage: _activeLanguage.code,
    };

    final token = await AuthSessionService.instance.getToken();
    if (token != null && token.trim().isNotEmpty) {
      headers[ApiHeaders.authorization] =
          '${ApiHeaders.bearerPrefix}${token.trim()}';
    }
    return headers;
  }

  Future<ProductsListApiResponse> _fetchProducts({
    int? categoryId,
    String? search,
  }) async {
    final response = await http.get(
      ProductApiEndpoints.list(
        categoryId: categoryId,
        search: search,
        pageNumber: 1,
        pageSize: 20,
      ),
      headers: await _apiHeaders(),
    );

    return ProductsListApiResponse.fromHttp(response.statusCode, response.body);
  }

  Future<void> _selectCategory(CategorySummary category) async {
    setState(() {
      _selectedCategoryId = category.id;
    });

    await _runSearch();
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
      final response = await _fetchProducts(
        categoryId: _selectedCategoryId,
        search: _searchQuery,
      );
      if (!mounted) return;
      setState(() {
        _featuredProducts = response.data?.items ?? const [];
        _catalogError = response.isSuccess
            ? null
            : (response.message ?? 'Unable to load products');
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

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) {
          return;
        }
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() => _isListening = false);
      },
    );

    if (!available) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice search is not available')),
      );
      return;
    }

    setState(() => _isListening = true);

    await _speechToText.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
      ),
      onResult: (result) {
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) {
          return;
        }

        _searchController.value = TextEditingValue(
          text: recognized,
          selection: TextSelection.collapsed(offset: recognized.length),
        );
        _onSearchChanged(recognized);

        if (result.finalResult) {
          _speechToText.stop();
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
    );
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
        : (widget.currentLocation != null &&
              widget.currentLocation!.trim().isNotEmpty)
        ? widget.currentLocation!.trim()
        : 'Current location unavailable';

    final categoryPreview = _categories.take(8).toList();
    final pincode = _resolvePincode(widget.currentLocation);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF8D84D), Color(0xFFF6E87D)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to Babai Bazzor',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_isLoadingHome)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Color(0xFF3A3A3A),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3A3A3A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 30,
                            color: Color(0xFF505050),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onSubmitted: (_) => _runSearch(),
                              decoration: const InputDecoration(
                                hintText: 'Search products',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(
                                fontSize: 17,
                                color: Color(0xFF303030),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const VerticalDivider(color: Color(0xFFDFDFDF)),
                          IconButton(
                            onPressed: _toggleVoiceSearch,
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              size: 28,
                              color: _isListening
                                  ? const Color(0xFFDC3C2F)
                                  : const Color(0xFF333333),
                            ),
                            tooltip: _isListening
                                ? 'Stop voice search'
                                : 'Start voice search',
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF666666),
                              ),
                              tooltip: 'Clear search',
                            )
                          else
                            const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: _categories.isEmpty
                    ? Center(
                        child: Text(
                          _catalogError == null
                              ? 'No categories available'
                              : _catalogError!,
                          style: const TextStyle(
                            color: Color(0xFF6D6D6D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _categories[index];
                          final selected = _selectedCategoryId == item.id;

                          return GestureDetector(
                            onTap: () => _selectCategory(item),
                            onLongPress: () => _showCategoryDetails(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF202020)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF202020)
                                      : const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF2E2E2E),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 158,
                child: _featuredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _catalogError ?? 'No products found',
                              style: const TextStyle(
                                color: Color(0xFF6D6D6D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _isLoadingCatalog ? null : _runSearch,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        scrollDirection: Axis.horizontal,
                        itemCount: _featuredProducts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _featuredProducts[index];

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailsScreen(
                                    productId: item.id,
                                    language: _activeLanguage,
                                    pincode: pincode,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE4E4E4),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.isFeatured == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF1E5),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Text(
                                          'Featured',
                                          style: TextStyle(
                                            color: Color(0xFFAF4D1F),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 19),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Center(
                                        child:
                                            (item.imageUrl != null &&
                                                item.imageUrl!.isNotEmpty)
                                            ? Image.network(
                                                item.imageUrl!,
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      Icons
                                                          .image_not_supported_outlined,
                                                      size: 44,
                                                      color: Color(0xFF808080),
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.shopping_basket_outlined,
                                                size: 44,
                                                color: Color(0xFF808080),
                                              ),
                                      ),
                                    ),
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.price != null
                                          ? 'Rs ${item.price!.toStringAsFixed(0)}'
                                          : 'Price unavailable',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4A4A4A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_isLoadingCatalog)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Categories'),
              const SizedBox(height: 12),
              _CategoryGrid(items: categoryPreview),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 82,
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
              icon: Icons.receipt_long_outlined,
              label: 'Orders',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrdersScreen(language: _activeLanguage),
                  ),
                );
              },
            ),
            _BottomNavItem(
              icon: Icons.shopping_cart_outlined,
              label: 'Cart',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CartScreen(language: _activeLanguage, pincode: pincode),
                  ),
                );
              },
            ),
            _BottomNavItem(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(language: _activeLanguage),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.items});

  final List<CategorySummary> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Center(
          child: Text(
            'No categories available',
            style: TextStyle(
              color: Color(0xFF6D6D6D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.73,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final bgColors = [
            const Color(0xFFE6F0F3),
            const Color(0xFFF0ECE1),
            const Color(0xFFFFF0D8),
            const Color(0xFFE9F4FF),
            const Color(0xFFF3E9E7),
            const Color(0xFFF5EFE1),
            const Color(0xFFFFECE8),
            const Color(0xFFE8F0F3),
          ];
          final tileColor = bgColors[index % bgColors.length];

          return Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: (item.iconUrl != null && item.iconUrl!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            item.iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.category_outlined,
                                  color: Color(0xFF303030),
                                  size: 34,
                                ),
                          ),
                        )
                      : const Icon(
                          Icons.category_outlined,
                          color: Color(0xFF303030),
                          size: 34,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected
                  ? const Color(0xFF202020)
                  : const Color(0xFF6D6D6D),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? const Color(0xFF202020)
                    : const Color(0xFF6D6D6D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
