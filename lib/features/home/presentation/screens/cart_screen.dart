import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/constants/payment_constants.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/cart_service.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/payment_failure_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/payment_method_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/payment_success_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/saved_addresses_screen.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.language, this.pincode});

  final AppLanguage language;
  final String? pincode;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = const CartService();
  final Razorpay _razorpay = Razorpay();
  final TextEditingController _couponController = TextEditingController();
  late AppLanguage _activeLanguage;

  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isProcessingCheckout = false;
  double _checkoutAmount = 0;
  int _selectedTip = 0;
  CartData? _cart;
  late SavedAddressResult _selectedAddress;

  String _money(num value) => '₹${value.toStringAsFixed(0)}';

  String get _effectivePincode {
    final selected = _selectedAddress.pincode.trim();
    if (selected.isNotEmpty) {
      return selected;
    }

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
    _selectedAddress = SavedAddressResult(
      label: 'Home',
      icon: '🏠',
      line1: 'Flat 4B, Sunrise Apartments',
      line2:
          'Sector 21, Gurugram, HR ${widget.pincode?.trim().isNotEmpty == true ? widget.pincode!.trim() : '122016'}',
      pincode: widget.pincode?.trim().isNotEmpty == true
          ? widget.pincode!.trim()
          : '122016',
    );
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _loadCart();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _couponController.dispose();
    super.dispose();
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
    if (_isUpdating) {
      return;
    }

    final resolvedProductId = item.productId ?? item.cartItemId;
    if (resolvedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update this cart item')),
      );
      return;
    }

    final currentQty = item.quantity ?? 0;
    final nextQty = qty < 0 ? 0 : qty;

    setState(() {
      _isUpdating = true;
    });

    final response = nextQty > currentQty
        ? await _cartService.addToCart(
            language: _activeLanguage,
            pincode: _effectivePincode,
            request: CartUpdateRequest(
              productId: resolvedProductId,
              quantity: nextQty - currentQty,
            ),
          )
        : await _cartService.updateCart(
            language: _activeLanguage,
            pincode: _effectivePincode,
            request: CartUpdateRequest(
              productId: resolvedProductId,
              quantity: nextQty,
            ),
          );

    if (!mounted) {
      return;
    }

    if (response.isSuccess) {
      if (response.data != null) {
        setState(() {
          _cart = response.data;
          _isUpdating = false;
        });
      } else {
        setState(() {
          _isUpdating = false;
        });
        await _loadCart();
      }
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

  Future<void> _clearCart({bool showSnackbar = true}) async {
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
      if (showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Cart cleared')),
        );
      }
      return;
    }

    setState(() {
      _isUpdating = false;
    });
    if (showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Unable to clear cart')),
      );
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessingCheckout = false;
    });

    await _clearCart();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(amount: _checkoutAmount),
      ),
    );
  }

  void _onPaymentError(PaymentFailureResponse response) async {
    if (!mounted) {
      return;
    }

    final message = response.message?.trim();
    final code = response.code;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed ($code): $message')),
      );
    }

    setState(() {
      _isProcessingCheckout = false;
    });

    final retry = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentFailureScreen(amount: _checkoutAmount),
      ),
    );

    if (retry == true && mounted) {
      _openRazorpayCheckout(_checkoutAmount);
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName ?? 'Unknown'}',
        ),
      ),
    );
  }

  void _openRazorpayCheckout(num amount) {
    if (_isProcessingCheckout || _isUpdating) {
      return;
    }

    final key = PaymentConstants.razorpayKeyId.trim();
    final looksInvalidKey =
        key.isEmpty ||
        key.contains('replace_with_your_key_id') ||
        (!key.startsWith('rzp_test_') && !key.startsWith('rzp_live_'));
    if (looksInvalidKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set a valid Razorpay Key ID in payment_constants.dart before checkout.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isProcessingCheckout = true;
      _checkoutAmount = amount.toDouble();
    });
    final amountInPaise = (amount * 100).round();
    final options = {
      'key': PaymentConstants.razorpayKeyId,
      'amount': amountInPaise,
      'name': PaymentConstants.merchantName,
      'description': PaymentConstants.merchantDescription,
      'timeout': 300,
      'retry': {'enabled': true, 'max_count': 2},
      'prefill': {'contact': '9999999999', 'email': 'guest@babaibazor.com'},
      'theme': {'color': '#F44700'},
    };

    try {
      _razorpay.open(options);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessingCheckout = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start Razorpay checkout')),
      );
    }
  }

  Future<void> _openPaymentMethodScreen(double amount) async {
    if (_isUpdating || _isProcessingCheckout) {
      return;
    }

    final selectedMethod = await Navigator.of(context).push<PaymentMethodType>(
      MaterialPageRoute(builder: (_) => PaymentMethodScreen(amount: amount)),
    );

    if (!mounted) {
      return;
    }

    if (selectedMethod == PaymentMethodType.upi) {
      _openRazorpayCheckout(amount);
      return;
    }

    if (selectedMethod == PaymentMethodType.cod) {
      setState(() {
        _isProcessingCheckout = true;
        _checkoutAmount = amount;
      });

      final goHome = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            amount: amount,
            title: 'Order Successful',
            subtitle: 'Your cash on delivery order has been placed.',
            buttonText: 'OK',
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (goHome == true) {
        await _clearCart(showSnackbar: false);
        if (!mounted) {
          return;
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      setState(() {
        _isProcessingCheckout = false;
      });
    }
  }

  Future<void> _openAddressSelector() async {
    final selected = await Navigator.of(context).push<SavedAddressResult>(
      MaterialPageRoute(
        builder: (_) => SavedAddressesScreen(current: _selectedAddress),
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedAddress = selected;
    });

    await _loadCart();
  }

  @override
  Widget build(BuildContext context) {
    final items = _cart?.items ?? const <CartItemModel>[];
    final itemTotal =
        _cart?.subTotal ??
        items.fold<double>(
          0,
          (sum, item) =>
              sum +
              (item.totalPrice ??
                  ((item.unitPrice ?? 0) * (item.quantity ?? 0))),
        );
    final deliveryFee = _cart?.deliveryCharge ?? 0;
    final taxes =
        _cart?.taxes ??
        (itemTotal > 0
            ? ((itemTotal * 0.04).round().toDouble()).clamp(1.0, 9999.0)
            : 0);
    final discount = _cart?.discount ?? 0;
    final baseGrandTotal =
        _cart?.totalAmount ?? (itemTotal + deliveryFee + taxes - discount);
    final grandTotalRaw = baseGrandTotal + _selectedTip;
    final grandTotal = grandTotalRaw < 0 ? 0.0 : grandTotalRaw;
    final savings = discount < 0 ? 0.0 : discount;
    final itemCount =
        _cart?.totalItems ??
        items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
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
              child: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Row(
          children: [
            const Text('🛒', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Cart',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  '$itemCount items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E96A9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF5E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Save ${_money(savings)}',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
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
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 128),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDEE3EE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('📍', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          const Text(
                            'Delivering to',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _openAddressSelector,
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                color: Color(0xFFF44700),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _selectedAddress.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedAddress.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedAddress.line1,
                                  style: const TextStyle(
                                    color: Color(0xFF8E96A9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _selectedAddress.line2,
                                  style: const TextStyle(
                                    color: Color(0xFF8E96A9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _effectivePincode,
                            style: const TextStyle(
                              color: Color(0xFFF44700),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '$itemCount Items',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map((item) {
                  final qty = item.quantity ?? 0;
                  final unitPrice = item.unitPrice ?? 0;
                  final linePrice = item.totalPrice ?? (unitPrice * qty);
                  final emoji = item.emoji?.trim();
                  final hasEmoji = emoji != null && emoji.isNotEmpty;
                  final estimatedMrp = unitPrice > 0
                      ? (unitPrice * 1.43)
                      : (linePrice * 1.43);
                  final discountPct = estimatedMrp > linePrice
                      ? (((estimatedMrp - linePrice) / estimatedMrp) * 100)
                            .round()
                      : 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDEE3EE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              (item.imageUrl != null &&
                                  item.imageUrl!.trim().isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    ApiConstants.resolveMediaUrl(item.imageUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => hasEmoji
                                        ? Text(
                                            emoji,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 30,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.shopping_basket_outlined,
                                            color: Color(0xFF97A1B7),
                                          ),
                                  ),
                                )
                              : hasEmoji
                              ? Text(
                                  emoji,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 30),
                                )
                              : const Icon(
                                  Icons.shopping_basket_outlined,
                                  color: Color(0xFF97A1B7),
                                ),
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
                                  fontSize: 20,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.unit ?? '-',
                                style: const TextStyle(
                                  color: Color(0xFF8E96A9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _money(linePrice),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 28,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _money(estimatedMrp),
                                    style: const TextStyle(
                                      color: Color(0xFF9AA2B5),
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$discountPct% off',
                                    style: const TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _QtyPill(
                          qty: qty,
                          isUpdating: _isUpdating,
                          onMinus: () => _changeQty(item, qty - 1),
                          onPlus: () => _changeQty(item, qty + 1),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDEE3EE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('🎟️', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            'Apply Coupon',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F5FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E6F0),
                                ),
                              ),
                              child: TextField(
                                controller: _couponController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter code',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Coupon feature coming soon'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF44700),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CouponTag(
                            text: 'BABAI1',
                            color: Color(0xFFFFF1EC),
                            textColor: Color(0xFFF44700),
                            borderColor: Color(0xFFFFC9B6),
                          ),
                          _CouponTag(
                            text: 'FARM40',
                            color: Color(0xFFE8F8EF),
                            textColor: Color(0xFF16A34A),
                            borderColor: Color(0xFFB9EACD),
                          ),
                          _CouponTag(
                            text: 'HOME200',
                            color: Color(0xFFEEF3FF),
                            textColor: Color(0xFF1D4ED8),
                            borderColor: Color(0xFFC9D9FF),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDEE3EE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('🛵', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            'Tip your delivery partner',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'They work hard to deliver on time',
                        style: TextStyle(
                          color: Color(0xFF8E96A9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TipChip(
                            label: 'None',
                            selected: _selectedTip == 0,
                            onTap: () => setState(() => _selectedTip = 0),
                          ),
                          _TipChip(
                            label: _money(10),
                            selected: _selectedTip == 10,
                            onTap: () => setState(() => _selectedTip = 10),
                          ),
                          _TipChip(
                            label: _money(20),
                            selected: _selectedTip == 20,
                            onTap: () => setState(() => _selectedTip = 20),
                          ),
                          _TipChip(
                            label: _money(30),
                            selected: _selectedTip == 30,
                            onTap: () => setState(() => _selectedTip = 30),
                          ),
                          _TipChip(
                            label: _money(50),
                            selected: _selectedTip == 50,
                            onTap: () => setState(() => _selectedTip = 50),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDEE3EE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('🧾', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            'Bill Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _BillRow(label: 'Item total', value: _money(itemTotal)),
                      const SizedBox(height: 8),
                      _BillRow(
                        label: 'Delivery fee',
                        value: _money(deliveryFee),
                      ),
                      const SizedBox(height: 8),
                      _BillRow(label: 'Taxes & charges', value: _money(taxes)),
                      if (_selectedTip > 0) ...[
                        const SizedBox(height: 8),
                        _BillRow(
                          label: 'Delivery tip',
                          value: _money(_selectedTip.toDouble()),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFFE1E5EE), height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Grand Total',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Text(
                            _money(grandTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                              color: Color(0xFFF44700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF2E6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🎉 You\'re saving ${_money(savings)} on this order!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isUpdating ? null : _clearCart,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Clear cart'),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F3F7),
                  border: Border(top: BorderSide(color: Color(0xFFE4E8F1))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isUpdating || _isProcessingCheckout)
                        ? null
                        : () => _openPaymentMethodScreen(grandTotal),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      backgroundColor: const Color(0xFFF44700),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isProcessingCheckout
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Proceed to Payment · ${_money(grandTotal)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B849A),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _CouponTag extends StatelessWidget {
  const _CouponTag({
    required this.text,
    required this.color,
    required this.textColor,
    required this.borderColor,
  });

  final String text;
  final Color color;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 70,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF44700) : const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFF44700) : const Color(0xFFE1E5EF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4A4E5E),
            fontWeight: FontWeight.w700,
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
      height: 38,
      width: 86,
      decoration: BoxDecoration(
        color: const Color(0xFFF44700),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isUpdating ? null : onMinus,
              child: const Center(
                child: Text(
                  '−',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: isUpdating ? null : onPlus,
              child: const Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
