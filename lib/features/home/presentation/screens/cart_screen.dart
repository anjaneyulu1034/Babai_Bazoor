import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/cart_service.dart';
import 'package:flutter/material.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.language, this.pincode});

  final AppLanguage language;
  final String? pincode;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = const CartService();
  late AppLanguage _activeLanguage;

  bool _isLoading = true;
  bool _isUpdating = false;
  CartData? _cart;

  String _money(num value) => 'Rs ${value.toStringAsFixed(0)}';

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
    _loadCart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scopedLanguage = AppLanguageScope.watch(context);
    if (scopedLanguage != _activeLanguage) {
      _activeLanguage = scopedLanguage;
      _loadCart();
    }
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _cartService.getCart(
      language: _activeLanguage,
      pincode: _effectivePincode,
    );

    if (!mounted) {
      return;
    }

    if (response.isSuccess) {
      setState(() {
        _cart = response.data;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _cart = response.data;
    });

    if ((response.message ?? '').isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message ??
                (response.errors.isNotEmpty
                    ? response.errors.first
                    : 'Unable to load cart'),
          ),
        ),
      );
    }
  }

  Future<void> _changeQty(CartItemModel item, int qty) async {
    if (_isUpdating || item.productId == null) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final response = await _cartService.updateCart(
      language: _activeLanguage,
      pincode: _effectivePincode,
      request: CartUpdateRequest(
        productId: item.productId!,
        quantity: qty < 0 ? 0 : qty,
      ),
    );

    if (!mounted) {
      return;
    }

    if (response.isSuccess) {
      setState(() {
        _cart = response.data;
        _isUpdating = false;
      });
      return;
    }

    setState(() {
      _isUpdating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.message ??
              (response.errors.isNotEmpty
                  ? response.errors.first
                  : 'Unable to update cart'),
        ),
      ),
    );
  }

  Future<void> _clearCart() async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final response = await _cartService.clearCart(
      language: _activeLanguage,
      pincode: _effectivePincode,
    );

    if (!mounted) {
      return;
    }

    if (response.isSuccess) {
      setState(() {
        _cart = const CartData(items: []);
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Cart cleared')),
      );
      return;
    }

    setState(() {
      _isUpdating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.message ?? 'Unable to clear cart')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _cart?.items ?? const <CartItemModel>[];
    final total = _cart?.totalAmount ?? 0;
    final subTotal = _cart?.subTotal ?? 0;
    final deliveryCharge = _cart?.deliveryCharge ?? 0;
    final discount = _cart?.discount ?? 0;
    final freeDelivery = _cart?.freeDelivery ?? false;
    final freeDeliveryAbove = _cart?.freeDeliveryAbove ?? 0;
    final itemCount =
        _cart?.totalItems ??
        items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'My Cart',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              onPressed: _isUpdating ? null : _clearCart,
              tooltip: 'Clear cart',
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.remove_shopping_cart_outlined,
                      size: 44,
                      color: Color(0xFF8A8A8A),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Your cart is empty',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add some items to continue checkout.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF7F7F7F)),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 130),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFDFC9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6F45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$itemCount items in your cart',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4D2D1A),
                          ),
                        ),
                      ),
                      Text(
                        _money(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF2D1A0E),
                        ),
                      ),
                    ],
                  ),
                ),
                ...items.map((item) {
                  final qty = item.quantity ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              (item.imageUrl != null &&
                                  item.imageUrl!.trim().isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => const Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                  ),
                                )
                              : const Icon(Icons.shopping_basket_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName ?? 'Product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.unit ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _money(item.totalPrice ?? 0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _QtyPill(
                                qty: qty,
                                isUpdating: _isUpdating,
                                onMinus: () => _changeQty(item, qty - 1),
                                onPlus: () => _changeQty(item, qty + 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 2),
                _InfoTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Shipping',
                  subtitle: freeDelivery
                      ? 'Free delivery'
                      : _money(deliveryCharge),
                  trailing: freeDelivery
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF28A966),
                          size: 18,
                        )
                      : (freeDeliveryAbove > 0
                            ? _Badge(
                                text: 'Free above ${_money(freeDeliveryAbove)}',
                              )
                            : const SizedBox.shrink()),
                ),
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.payments_outlined,
                  title: 'Subtotal',
                  subtitle: _money(subTotal),
                  trailing: const Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF4A4A4A),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.percent_rounded,
                  title: 'Discount',
                  subtitle: '-${_money(discount)}',
                  trailing: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2DBB6F),
                    size: 18,
                  ),
                ),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE6E6E6)),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 10,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Grand Total',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _money(total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUpdating
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Checkout coming soon'),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFFFF6F45),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CHECKOUT',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  const _QtyPill({
    required this.qty,
    required this.isUpdating,
    required this.onMinus,
    required this.onPlus,
  });

  final int qty;
  final bool isUpdating;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isUpdating ? null : onMinus,
              child: const Icon(Icons.remove, size: 18),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Expanded(
            child: InkWell(
              onTap: isUpdating ? null : onPlus,
              child: const Icon(Icons.add, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF333333)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6F45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
