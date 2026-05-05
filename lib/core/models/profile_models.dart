class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.nameEn,
    required this.nameTe,
    required this.villageEn,
    required this.villageTe,
    required this.pincode,
    required this.district,
  });

  final String nameEn;
  final String nameTe;
  final String villageEn;
  final String villageTe;
  final String pincode;
  final String district;

  Map<String, dynamic> toJson() {
    return {
      'nameEn': nameEn,
      'nameTe': nameTe,
      'villageEn': villageEn,
      'villageTe': villageTe,
      'pincode': pincode,
      'district': district,
    };
  }
}

class AddAddressRequest {
  const AddAddressRequest({
    required this.labelEn,
    required this.labelTe,
    required this.addressLineEn,
    required this.addressLineTe,
    required this.villageEn,
    required this.villageTe,
    required this.mandalEn,
    required this.mandalTe,
    required this.districtEn,
    required this.districtTe,
    required this.pincode,
    required this.isDefault,
    required this.latitude,
    required this.longitude,
  });

  final String labelEn;
  final String labelTe;
  final String addressLineEn;
  final String addressLineTe;
  final String villageEn;
  final String villageTe;
  final String mandalEn;
  final String mandalTe;
  final String districtEn;
  final String districtTe;
  final String pincode;
  final bool isDefault;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() {
    return {
      'labelEn': labelEn,
      'labelTe': labelTe,
      'addressLineEn': addressLineEn,
      'addressLineTe': addressLineTe,
      'villageEn': villageEn,
      'villageTe': villageTe,
      'mandalEn': mandalEn,
      'mandalTe': mandalTe,
      'districtEn': districtEn,
      'districtTe': districtTe,
      'pincode': pincode,
      'isDefault': isDefault,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
