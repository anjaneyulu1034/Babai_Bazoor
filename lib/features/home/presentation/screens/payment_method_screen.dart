import 'package:flutter/material.dart';

enum PaymentMethodType { upi, card, wallet, cod, payLater }

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key, required this.amount});

  final double amount;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final TextEditingController _upiController = TextEditingController();
  PaymentMethodType _selectedMethod = PaymentMethodType.upi;

  String _money(num value) => '₹${value.toStringAsFixed(0)}';

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F8),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(false),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFE9EBF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF121826)),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Row(
          children: [
            const Text('💳', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text(
              'Payment',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1E2D),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDDF2E7),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                '🔒 Secure',
                style: TextStyle(
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E4EE)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GROCERY ORDER',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9199AD),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Your Cart Items',
                                style: TextStyle(
                                  fontSize: 34,
                                  color: Color(0xFF1A1E2D),
                                  fontWeight: FontWeight.w800,
                                  height: 1.06,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _money(widget.amount),
                          style: const TextStyle(
                            fontSize: 40,
                            color: Color(0xFFF44700),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Choose Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1E2D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _methodCard(
                    method: PaymentMethodType.upi,
                    title: 'UPI',
                    subtitle: 'GPay, PhonePe, Paytm',
                    emoji: '📱',
                    showUpiContent: true,
                  ),
                  const SizedBox(height: 10),
                  _methodCard(
                    method: PaymentMethodType.card,
                    title: 'Credit / Debit Card',
                    subtitle: 'Visa, Mastercard, Rupay',
                    emoji: '💳',
                  ),
                  const SizedBox(height: 10),
                  _methodCard(
                    method: PaymentMethodType.wallet,
                    title: 'Babai Wallet',
                    subtitle: 'Balance: ₹250',
                    emoji: '👛',
                  ),
                  const SizedBox(height: 10),
                  _methodCard(
                    method: PaymentMethodType.cod,
                    title: 'Cash on Delivery',
                    subtitle: 'Pay when delivered',
                    emoji: '💵',
                  ),
                  const SizedBox(height: 10),
                  _methodCard(
                    method: PaymentMethodType.payLater,
                    title: 'Pay Later',
                    subtitle: 'Babai Pay Later',
                    emoji: '⏳',
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F3F8),
                  border: Border(top: BorderSide(color: Color(0xFFE3E7F1))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedMethod != PaymentMethodType.upi &&
                          _selectedMethod != PaymentMethodType.cod) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'For now, only UPI and Cash on Delivery are enabled.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop(_selectedMethod);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color(0xFFF44700),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _selectedMethod == PaymentMethodType.cod
                          ? 'Place Order'
                          : 'Pay ${_money(widget.amount)} Now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodCard({
    required PaymentMethodType method,
    required String title,
    required String subtitle,
    required String emoji,
    bool showUpiContent = false,
  }) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE1E5EF),
            width: isSelected ? 2 : 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3FA),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
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
                          color: Color(0xFF1A1E2D),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8A92A6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off_outlined,
                  size: 28,
                  color: isSelected
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFCAD1E2),
                ),
              ],
            ),
            if (showUpiContent && isSelected) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE3E7F1)),
              const SizedBox(height: 10),
              const Text(
                'Enter UPI ID',
                style: TextStyle(
                  color: Color(0xFF626B80),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _upiController,
                        decoration: const InputDecoration(
                          hintText: 'yourname@upi',
                          hintStyle: TextStyle(
                            color: Color(0xFF9AA3B8),
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'UPI verification connected in next step',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDDF2E6),
                        foregroundColor: const Color(0xFF16A34A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Verify',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _UpiQuickAppTag(text: 'GPay'),
                  _UpiQuickAppTag(text: 'PhonePe'),
                  _UpiQuickAppTag(text: 'Paytm'),
                  _UpiQuickAppTag(text: 'BHIM'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpiQuickAppTag extends StatelessWidget {
  const _UpiQuickAppTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F9),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE0E5F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF59607A),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
