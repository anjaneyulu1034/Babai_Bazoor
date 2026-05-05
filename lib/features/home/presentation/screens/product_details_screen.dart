import 'dart:async';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/cart_service.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.productId,
    required this.language,
    this.pincode,
  });

  final int productId;
  final AppLanguage language;
  final String? pincode;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final CartService _cartService = const CartService();
  late AppLanguage _activeLanguage;

  ProductSummary? _product;
  bool _isLoading = true;
  bool _isUpdatingCart = false;
  int _qty = 0;

  String get _effectivePincode {
    final p = widget.pincode?.trim();
    if (p == null || p.isEmpty) {
      return '500001';
    }
    return p;
  }

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.language;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scopedLanguage = AppLanguageScope.watch(context);
    if (scopedLanguage != _activeLanguage) {
      _activeLanguage = scopedLanguage;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final response = await http
          .get(
            ProductApiEndpoints.details(widget.productId),
            headers: {ApiHeaders.acceptLanguage: _activeLanguage.code},
          )
          .timeout(const Duration(seconds: 15));

      final parsed = ProductDetailsApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _product = parsed.data;
      });

      await _loadCurrentCartQty();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCurrentCartQty() async {
    final cart = await _cartService.getCart(
      language: _activeLanguage,
      pincode: _effectivePincode,
    );
    if (!mounted || !cart.isSuccess) {
      return;
    }

    final match = cart.data?.items
        .where((item) => item.productId == widget.productId)
        .cast<CartItemModel?>()
        .firstWhere((item) => item != null, orElse: () => null);

    if (!mounted) {
      return;
    }

    setState(() {
      _qty = match?.quantity ?? 0;
    });
  }

  Future<void> _updateCart(int qty, {bool openCartOnSuccess = false}) async {
    if (_isUpdatingCart) {
      return;
    }

    final normalizedQty = qty < 0 ? 0 : qty;

    setState(() {
      _isUpdatingCart = true;
    });

    final parsed = await _cartService.updateCart(
      language: _activeLanguage,
      pincode: _effectivePincode,
      request: CartUpdateRequest(
        productId: widget.productId,
        quantity: normalizedQty,
      ),
    );

    if (!mounted) {
      return;
    }

    if (parsed.isSuccess) {
      final match = parsed.data?.items
          .where((item) => item.productId == widget.productId)
          .cast<CartItemModel?>()
          .firstWhere((item) => item != null, orElse: () => null);
      final updatedQty = match?.quantity ?? normalizedQty;
      setState(() {
        _qty = updatedQty;
      });

      if (openCartOnSuccess && updatedQty > 0 && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CartScreen(
              language: _activeLanguage,
              pincode: _effectivePincode,
            ),
          ),
        );
      }
    } else {
      final msg =
          parsed.message ??
          (parsed.errors.isNotEmpty
              ? parsed.errors.first
              : 'Unable to update cart');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    if (mounted) {
      setState(() {
        _isUpdatingCart = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final product = _product;
    if (product == null) {
      return const Scaffold(body: Center(child: Text('Product not found')));
    }

    final price = product.price?.toStringAsFixed(0) ?? '-';
    final mrp = product.mrpPrice?.toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        product.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
                    )
                  : const Icon(Icons.shopping_basket_outlined, size: 68),
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Rs $price',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (mrp != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Rs $mrp',
                    style: const TextStyle(
                      fontSize: 16,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            if ((product.unit ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                product.unit!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5A5A5A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if ((product.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                product.description!,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpdatingCart
                  ? null
                  : () async {
                      if (_qty > 0) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CartScreen(
                              language: _activeLanguage,
                              pincode: _effectivePincode,
                            ),
                          ),
                        );
                        return;
                      }
                      await _updateCart(1, openCartOnSuccess: true);
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFFFF6F00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isUpdatingCart
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _qty > 0 ? 'GO TO CART' : 'ADD TO CART',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
