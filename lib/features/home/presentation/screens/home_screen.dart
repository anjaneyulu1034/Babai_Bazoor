import 'dart:async';
import 'dart:convert';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/category_service.dart';
import 'package:babai_bazor_app/core/services/home_service.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/category_products_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/cart_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/orders_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/product_details_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  static const String _mapsApiKey = 'AIzaSyAT3wIjV73qVXPAlgkyifnns38GztnbNF4';

  final CategoryService _categoryService = const CategoryService();
  final HomeService _homeService = const HomeService();
  final TextEditingController _searchController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  final PageController _bannerPageController = PageController(
    viewportFraction: 0.92,
  );
  late AppLanguage _activeLanguage;

  String? _apiLocation;
  String _apiEtaText = '22 minutes';
  String? _deliveryBadgeText;
  bool _isLoadingHome = true;
  bool _isLoadingCatalog = true;
  bool _isListening = false;
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
    _bannerPageController.dispose();
    _speechToText.stop();
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
                    name: pill.name,
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
        }
      }

      final zone = sectionsData?.deliveryZone;
      final etaText =
          fallbackHome.etaText ??
          (zone?.estimatedDeliveryHours != null
              ? '${zone!.estimatedDeliveryHours} hours'
              : '22 minutes');

      String? deliveryBadge;
      if (zone?.freeDeliveryAbove != null) {
        deliveryBadge =
            'Free delivery above Rs ${zone!.freeDeliveryAbove!.toStringAsFixed(0)}';
      } else if (zone?.isServiceable == true) {
        deliveryBadge = 'Serviceable';
      }

      if (!mounted) return;
      setState(() {
        _apiLocation =
            sectionsData?.deliveryZone?.areaName ??
            fallbackHome.currentLocation;
        _apiEtaText = etaText;
        _deliveryBadgeText = deliveryBadge;
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

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_mapsApiKey',
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

  Future<void> _openCategoryProducts(
    CategorySummary category, {
    int? initialSubCategoryId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          categoryId: category.id,
          categoryName: category.name,
          language: _activeLanguage,
          pincode: _effectivePincode,
          initialSubCategoryId: initialSubCategoryId,
        ),
      ),
    );
  }

  Future<void> _selectCategory(CategorySummary category) async {
    setState(() {
      _selectedCategoryId = category.id;
      _selectedSubCategoryId = null;
    });

    await _runSearch();
  }

  Future<void> _selectSubCategory(int? subCategoryId) async {
    setState(() {
      _selectedSubCategoryId = subCategoryId;
    });
    await _runSearch();
  }

  void _onBannerTap(HomeBannerSummary banner) {
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(
            productId: linkedProductId,
            language: _activeLanguage,
            pincode: _effectivePincode,
          ),
        ),
      );
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
        : (_resolvedGuestLocation != null &&
              _resolvedGuestLocation!.trim().isNotEmpty)
        ? _resolvedGuestLocation!
        : (widget.currentLocation != null &&
              widget.currentLocation!.trim().isNotEmpty)
        ? widget.currentLocation!.trim()
        : 'Current location unavailable';

    final pincode = _effectivePincode;
    CategorySummary? selectedCategory;
    for (final item in _categories) {
      if (item.id == _selectedCategoryId) {
        selectedCategory = item;
        break;
      }
    }
    final selectedSubCategories =
        _sectionsByCategory[_selectedCategoryId]?.subCategories ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF5D34E), Color(0xFFF3DE8A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Babai in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E232C),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 42,
                          width: 42,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF1F2A37),
                            size: 23,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _apiEtaText,
                          style: const TextStyle(
                            fontSize: 42,
                            height: 1,
                            letterSpacing: -0.7,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (_deliveryBadgeText != null &&
                            _deliveryBadgeText!.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC7E8E8),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _deliveryBadgeText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D6E6E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_isLoadingHome)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Color(0xFF202427),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'HOME - $locationText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.1,
                              letterSpacing: -0.3,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF1F2937),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                                hintText: 'Search "disposables"',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF303030),
                                fontWeight: FontWeight.w600,
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
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
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
                            child: SizedBox(
                              width: 64,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFFFFFFF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? const Color(0xFF1E293B)
                                              : const Color(0xFFD1D5DB),
                                          width: 1.2,
                                        ),
                                      ),
                                      child:
                                          (item.iconUrl != null &&
                                              item.iconUrl!.trim().isNotEmpty)
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              child: Image.network(
                                                ApiConstants.resolveMediaUrl(
                                                  item.iconUrl,
                                                ),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Icon(
                                                      _iconForCategory(
                                                        item.name,
                                                        categoryId: item.id,
                                                      ),
                                                      size: 24,
                                                      color: selected
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF232323,
                                                            ),
                                                    ),
                                              ),
                                            )
                                          : Icon(
                                              _iconForCategory(
                                                item.name,
                                                categoryId: item.id,
                                              ),
                                              size: 24,
                                              color: selected
                                                  ? Colors.white
                                                  : const Color(0xFF232323),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: const Color(0xFF242424),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: selected ? 34 : 0,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D2D2D),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (selectedSubCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final item = isAll
                          ? null
                          : selectedSubCategories[index - 1];
                      final selected = isAll
                          ? _selectedSubCategoryId == null
                          : _selectedSubCategoryId == item!.id;
                      return InkWell(
                        onTap: () =>
                            _selectSubCategory(isAll ? null : item!.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF111827)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFE3E3E3),
                            ),
                          ),
                          child: Text(
                            isAll ? 'All' : item!.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF333333),
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemCount: selectedSubCategories.length + 1,
                  ),
                ),
              ],
              if (_banners.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 168,
                  child: PageView.builder(
                    controller: _bannerPageController,
                    itemCount: _banners.length,
                    onPageChanged: (index) {
                      setState(() => _activeBannerIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final banner = _banners[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _onBannerTap(banner),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFFECECEC),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child:
                                      (banner.imageUrl != null &&
                                          banner.imageUrl!.trim().isNotEmpty)
                                      ? Image.network(
                                          ApiConstants.resolveMediaUrl(
                                            banner.imageUrl,
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: const Color(
                                                    0xFFE5E7EB,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    color: Color(0xFF9CA3AF),
                                                    size: 34,
                                                  ),
                                                );
                                              },
                                        )
                                      : Container(
                                          color: const Color(0xFFE5E7EB),
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.image_outlined,
                                            color: Color(0xFF9CA3AF),
                                            size: 34,
                                          ),
                                        ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0x8C000000),
                                        Color(0x24000000),
                                        Color(0x10000000),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 12,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        banner.title ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if ((banner.subtitle ?? '').isNotEmpty)
                                        Text(
                                          banner.subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
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
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_banners.length, (index) {
                      final isActive = index == _activeBannerIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        height: 6,
                        width: isActive ? 20 : 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF111827)
                              : const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ),
              ],
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
                                                ApiConstants.resolveMediaUrl(
                                                  item.imageUrl,
                                                ),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
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
                      builder: (_) => CartScreen(
                        language: _activeLanguage,
                        pincode: pincode,
                      ),
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
  const _CategoryGrid({required this.items, required this.onCategoryTap});

  final List<CategorySummary> items;
  final ValueChanged<CategorySummary> onCategoryTap;

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

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onCategoryTap(item),
            child: Column(
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
                              ApiConstants.resolveMediaUrl(item.iconUrl),
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
            ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: selected
                  ? const Color(0xFF202020)
                  : const Color(0xFF6D6D6D),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
