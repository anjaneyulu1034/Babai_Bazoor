import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/models/order_models.dart';
import 'package:babai_bazor_app/core/services/orders_service.dart';
import 'package:flutter/material.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrdersService _ordersService = const OrdersService();
  late AppLanguage _activeLanguage;

  bool _isLoading = true;
  bool _isBusy = false;
  List<OrderModel> _orders = const [];

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
    final parsed = await _ordersService.getOrders(
      language: _activeLanguage,
      pageNumber: 1,
      pageSize: 20,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _orders = parsed.data?.items ?? const [];
      _isLoading = false;
    });

    if (!parsed.isSuccess && (parsed.message ?? '').isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parsed.message!)));
    }
  }

  Future<void> _createOrderDialog() async {
    final addressCtrl = TextEditingController(text: '1');
    final paymentCtrl = TextEditingController(text: '1');
    final enCtrl = TextEditingController(text: 'Leave at door');
    final teCtrl = TextEditingController(text: 'ద్వారం వద్ద వదిలేయండి');

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Address ID'),
                ),
                TextField(
                  controller: paymentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Payment Mode'),
                ),
                TextField(
                  controller: enCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Special Instructions (EN)',
                  ),
                ),
                TextField(
                  controller: teCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Special Instructions (TE)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true || !mounted) {
      return;
    }

    final addressId = int.tryParse(addressCtrl.text.trim());
    final paymentMode = int.tryParse(paymentCtrl.text.trim());
    if (addressId == null || paymentMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address ID and Payment Mode are required'),
        ),
      );
      return;
    }

    setState(() {
      _isBusy = true;
    });

    final response = await _ordersService.createOrder(
      language: _activeLanguage,
      request: CreateOrderRequest(
        addressId: addressId,
        paymentMode: paymentMode,
        specialInstructionsEn: enCtrl.text.trim(),
        specialInstructionsTe: teCtrl.text.trim(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? 'Create order response received'),
      ),
    );

    if (response.isSuccess) {
      _load();
    }
  }

  Future<void> _showOrderDetails(String orderNumber) async {
    final response = await _ordersService.getOrderDetails(
      language: _activeLanguage,
      orderNumber: orderNumber,
    );

    if (!mounted) {
      return;
    }

    if (!response.isSuccess || response.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Unable to load order details'),
        ),
      );
      return;
    }

    final order = response.data!;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(order.orderNumber ?? 'Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${order.status ?? '-'}'),
                Text(
                  'Total: Rs ${order.totalAmount?.toStringAsFixed(0) ?? '-'}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Items',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ...order.items.map(
                  (item) => Text(
                    '${item.productName ?? 'Item'} x${item.quantity ?? 0}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelOrder(String orderNumber) async {
    final reasonCtrl = TextEditingController(text: 'Customer changed mind');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    final response = await _ordersService.cancelOrder(
      language: _activeLanguage,
      orderNumber: orderNumber,
      request: CancelOrderRequest(reason: reasonCtrl.text.trim()),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(response.message ?? 'Cancel response received')),
    );

    if (response.isSuccess) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _createOrderDialog,
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
          ? const Center(child: Text('No orders yet'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _orders.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final orderNumber = order.orderNumber ?? '';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6E6E6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderNumber.isEmpty ? '-' : orderNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.status ?? '-',
                          style: const TextStyle(
                            color: Color(0xFF5D5D5D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs ${order.totalAmount?.toStringAsFixed(0) ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: orderNumber.isEmpty
                                  ? null
                                  : () => _showOrderDetails(orderNumber),
                              child: const Text('Details'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _isBusy || orderNumber.isEmpty
                                  ? null
                                  : () => _cancelOrder(orderNumber),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
