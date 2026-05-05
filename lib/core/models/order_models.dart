class CreateOrderRequest {
  const CreateOrderRequest({
    required this.addressId,
    required this.paymentMode,
    required this.specialInstructionsEn,
    required this.specialInstructionsTe,
  });

  final int addressId;
  final int paymentMode;
  final String specialInstructionsEn;
  final String specialInstructionsTe;

  Map<String, dynamic> toJson() {
    return {
      'addressId': addressId,
      'paymentMode': paymentMode,
      'specialInstructionsEn': specialInstructionsEn,
      'specialInstructionsTe': specialInstructionsTe,
    };
  }
}

class CancelOrderRequest {
  const CancelOrderRequest({required this.reason});

  final String reason;
}
