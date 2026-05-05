class PaymentConstants {
  const PaymentConstants._();

  // Replace with your live/test Razorpay Key ID from dashboard.
  static const String razorpayKeyId = 'rzp_test_replace_with_your_key_id';

  // Never use Key Secret in Flutter app code. Keep it only on backend server.
  static const String razorpayKeySecretBackendOnly = 'replace_on_backend_only';

  static const String merchantName = 'Babai Bazor';
  static const String merchantDescription = 'Order payment';
}
