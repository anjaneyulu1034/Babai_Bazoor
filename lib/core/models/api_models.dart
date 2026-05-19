import 'dart:convert';

import 'package:babai_bazor_app/core/localization/app_localizations.dart';

class SendOtpApiResponse {
  const SendOtpApiResponse({
    required this.isSuccess,
    this.message,
    this.otpCode,
  });

  final bool isSuccess;
  final String? message;
  final String? otpCode;

  factory SendOtpApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    return SendOtpApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      otpCode: _ApiModelParser.extractOtpCode(payload),
    );
  }
}

class VerifyOtpApiResponse {
  const VerifyOtpApiResponse({
    required this.isSuccess,
    this.message,
    this.accessToken,
  });

  final bool isSuccess;
  final String? message;
  final String? accessToken;

  factory VerifyOtpApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    return VerifyOtpApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      accessToken: _ApiModelParser.extractAccessToken(payload),
    );
  }
}

class HomeApiResponse {
  const HomeApiResponse({
    this.currentLocation,
    this.etaText,
    this.banners = const [],
    this.categories = const [],
    this.featuredProducts = const [],
    this.featuredServices = const [],
    this.promoCodes = const [],
  });

  final String? currentLocation;
  final String? etaText;
  final List<HomeBannerSummary> banners;
  final List<CategorySummary> categories;
  final List<ProductSummary> featuredProducts;
  final List<ServiceSummary> featuredServices;
  final List<PromoCodeSummary> promoCodes;

  factory HomeApiResponse.fromHttp(int statusCode, String rawBody) {
    if (statusCode < 200 || statusCode >= 300) {
      return const HomeApiResponse();
    }

    final payload = _ApiModelParser.decodeObject(rawBody);
    if (payload == null) {
      return const HomeApiResponse();
    }

    final data = payload['data'];
    final dataMap = data is Map<String, dynamic> ? data : payload;
    final banners = _ApiModelParser.toMapList(
      dataMap['banners'],
    ).map(HomeBannerSummary.fromJson).toList();
    final categories = _ApiModelParser.toMapList(
      dataMap['categories'],
    ).map(CategorySummary.fromJson).toList();
    final featuredProducts = _ApiModelParser.toMapList(
      dataMap['featuredProducts'],
    ).map(ProductSummary.fromJson).toList();
    final featuredServices = _ApiModelParser.toMapList(
      dataMap['featuredServices'],
    ).map(ServiceSummary.fromJson).toList();
    final promoCodes = _ApiModelParser.toMapList(
      dataMap['promoCodes'],
    ).map(PromoCodeSummary.fromJson).toList();

    final location =
        _ApiModelParser.pickFirstString(dataMap, const [
          'currentLocation',
          'location',
          'address',
          'deliveryAddress',
        ]) ??
        _ApiModelParser.pickFirstString(payload, const [
          'currentLocation',
          'location',
          'address',
          'deliveryAddress',
        ]);

    final eta =
        _ApiModelParser.pickFirstString(dataMap, const [
          'etaText',
          'deliveryEtaText',
          'deliveryTimeText',
          'eta',
        ]) ??
        _ApiModelParser.pickFirstString(payload, const [
          'etaText',
          'deliveryEtaText',
          'deliveryTimeText',
          'eta',
        ]) ??
        _ApiModelParser.pickFirstMinutesText(dataMap, const [
          'etaMinutes',
          'deliveryEtaMinutes',
          'deliveryTimeMinutes',
        ]) ??
        _ApiModelParser.pickFirstMinutesText(payload, const [
          'etaMinutes',
          'deliveryEtaMinutes',
          'deliveryTimeMinutes',
        ]);

    return HomeApiResponse(
      currentLocation: location?.trim().isNotEmpty == true
          ? location!.trim()
          : null,
      etaText: eta?.trim().isNotEmpty == true
          ? _normalizeEta(eta!.trim())
          : null,
      banners: banners,
      categories: categories,
      featuredProducts: featuredProducts,
      featuredServices: featuredServices,
      promoCodes: promoCodes,
    );
  }

  static String _normalizeEta(String raw) {
    final hasUnit = raw.toLowerCase().contains('min');
    return hasUnit ? raw : '$raw minutes';
  }
}

class ServiceSummary {
  const ServiceSummary({
    required this.id,
    required this.name,
    this.subCategoryId,
    this.emoji,
    this.price,
    this.mrp,
    this.durationLabel,
    this.imageUrl,
    this.rating,
    this.reviewCount,
    this.isFeatured,
    this.sortOrder,
    this.description,
    this.nameEn,
    this.nameTe,
    this.discount,
    this.instructions = const [],
    this.includes = const [],
  });

  final int id;
  final String name;
  final int? subCategoryId;
  final String? emoji;
  final double? price;
  final double? mrp;
  final String? durationLabel;
  final String? imageUrl;
  final double? rating;
  final int? reviewCount;
  final bool? isFeatured;
  final int? sortOrder;
  final String? description;
  final String? nameEn;
  final String? nameTe;
  final int? discount;
  final List<String> instructions;
  final List<String> includes;

  factory ServiceSummary.fromJson(Map<String, dynamic> json) {
    return ServiceSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      name:
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(json['nameEn']) ??
          _ApiModelParser.toStringValue(json['nameTe']) ??
          _ApiModelParser.toStringValue(json['title']) ??
          '',
      subCategoryId: _ApiModelParser.toInt(json['subCategoryId']),
      emoji: _ApiModelParser.toStringValue(json['emoji']),
      price: _ApiModelParser.toDouble(json['price']),
      mrp: _ApiModelParser.toDouble(json['mrp']),
      durationLabel: _ApiModelParser.toStringValue(json['durationLabel']),
      imageUrl: _ApiModelParser.toStringValue(json['imageUrl']),
      rating: _ApiModelParser.toDouble(json['rating']),
      reviewCount: _ApiModelParser.toInt(json['reviewCount']),
      isFeatured: _ApiModelParser.toBool(json['isFeatured']),
      sortOrder: _ApiModelParser.toInt(json['sortOrder']),
      description:
          _ApiModelParser.toStringValue(json['desc']) ??
          _ApiModelParser.toStringValue(json['description']),
      nameEn: _ApiModelParser.toStringValue(json['nameEn']),
      nameTe: _ApiModelParser.toStringValue(json['nameTe']),
      discount:
          _ApiModelParser.toInt(json['discount']) ??
          _ApiModelParser.toInt(json['discountPct']),
      instructions: _ApiModelParser.toStringList(json['instructions']),
      includes: _ApiModelParser.toStringList(json['includes']),
    );
  }

  String localizedName(AppLanguage language) {
    final preferred = language == AppLanguage.te ? nameTe : nameEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }
    final fallback = language == AppLanguage.te ? nameEn : nameTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }
    return name;
  }
}

class OfferSummary {
  const OfferSummary({
    required this.id,
    this.code,
    this.title,
    this.titleEn,
    this.titleTe,
    this.subtitle,
    this.discountType,
    this.discountValue,
    this.maxDiscount,
    this.minOrderValue,
    this.applicableOn,
    this.color,
    this.validTill,
    this.emoji,
  });

  final int id;
  final String? code;
  final String? title;
  final String? titleEn;
  final String? titleTe;
  final String? subtitle;
  final String? discountType;
  final double? discountValue;
  final double? maxDiscount;
  final double? minOrderValue;
  final String? applicableOn;
  final String? color;
  final String? validTill;
  final String? emoji;

  factory OfferSummary.fromJson(Map<String, dynamic> json) {
    return OfferSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      code: _ApiModelParser.toStringValue(json['code']),
      title: _ApiModelParser.toStringValue(json['title']),
      titleEn: _ApiModelParser.toStringValue(json['titleEn']),
      titleTe: _ApiModelParser.toStringValue(json['titleTe']),
      subtitle:
          _ApiModelParser.toStringValue(json['subtitle']) ??
          _ApiModelParser.toStringValue(json['description']),
      discountType: _ApiModelParser.toStringValue(json['discountType']),
      discountValue: _ApiModelParser.toDouble(json['discountValue']),
      maxDiscount: _ApiModelParser.toDouble(json['maxDiscount']),
      minOrderValue: _ApiModelParser.toDouble(json['minOrderValue']),
      applicableOn: _ApiModelParser.toStringValue(json['applicableOn']),
      color: _ApiModelParser.toStringValue(json['color']),
      validTill:
          _ApiModelParser.toStringValue(json['validTill']) ??
          _ApiModelParser.toStringValue(json['validUntil']) ??
          _ApiModelParser.toStringValue(json['expiryDate']) ??
          _ApiModelParser.toStringValue(json['endDate']),
      emoji: _ApiModelParser.toStringValue(json['emoji']),
    );
  }

  String localizedTitle(AppLanguage language) {
    final preferred = language == AppLanguage.te ? titleTe : titleEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }

    final fallback = language == AppLanguage.te ? titleEn : titleTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }

    final baseTitle = title?.trim();
    if (baseTitle != null && baseTitle.isNotEmpty) {
      return baseTitle;
    }

    final promoCode = code?.trim();
    if (promoCode != null && promoCode.isNotEmpty) {
      return promoCode;
    }
    return 'Offer';
  }

  String categoryLabel() {
    final on = applicableOn?.trim();
    if (on == null || on.isEmpty) {
      return 'All';
    }
    return on;
  }

  String contextLabel() {
    final explicit = subtitle?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final category = categoryLabel();
    final minOrder = minOrderValue;
    if (minOrder != null && minOrder > 0) {
      final amount = minOrder == minOrder.roundToDouble()
          ? minOrder.toStringAsFixed(0)
          : minOrder.toStringAsFixed(2);
      return '$category · Min ₹$amount';
    }
    return category;
  }

  String discountLabel() {
    final type = (discountType ?? '').toUpperCase();
    if (type == 'FREE_DELIVERY') {
      final minOrder = minOrderValue;
      if (minOrder != null && minOrder > 0) {
        final amount = minOrder == minOrder.roundToDouble()
            ? minOrder.toStringAsFixed(0)
            : minOrder.toStringAsFixed(2);
        return 'Free delivery above ₹$amount';
      }
      return 'Free delivery';
    }

    if (type == 'PERCENT') {
      final value = discountValue;
      if (value != null) {
        final pct = value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(1);
        final cap = maxDiscount;
        if (cap != null && cap > 0) {
          final capText = cap == cap.roundToDouble()
              ? cap.toStringAsFixed(0)
              : cap.toStringAsFixed(2);
          return '$pct% off up to ₹$capText';
        }
        return '$pct% off';
      }
    }

    if (type == 'FLAT') {
      final value = discountValue;
      if (value != null) {
        final amount = value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2);
        return '₹$amount off';
      }
    }

    return 'Offer available';
  }

  String validTillLabel() {
    final raw = validTill?.trim();
    if (raw == null || raw.isEmpty) {
      return '';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return 'Valid till: ${parsed.day} ${months[parsed.month - 1]}';
    }

    if (raw.toLowerCase().startsWith('valid')) {
      return raw;
    }
    return 'Valid till: $raw';
  }
}

class OffersListApiResponse {
  const OffersListApiResponse({
    required this.isSuccess,
    this.message,
    this.total,
    this.page,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final int? total;
  final int? page;
  final List<OfferSummary> data;
  final List<String> errors;

  factory OffersListApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataList = _ApiModelParser.toMapList(payload?['data']);
    final directList = _ApiModelParser.decodeMapList(rawBody);
    final parsed = dataList.isNotEmpty ? dataList : directList;

    return OffersListApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      total: _ApiModelParser.toInt(payload?['total']),
      page: _ApiModelParser.toInt(payload?['page']),
      data: parsed.map(OfferSummary.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class PromoCodeSummary {
  const PromoCodeSummary({
    required this.id,
    required this.code,
    this.title,
    this.titleEn,
    this.titleTe,
    this.discountType,
    this.discountValue,
    this.maxDiscount,
    this.minOrderValue,
    this.applicableOn,
    this.color,
  });

  final int id;
  final String code;
  final String? title;
  final String? titleEn;
  final String? titleTe;
  final String? discountType;
  final double? discountValue;
  final double? maxDiscount;
  final double? minOrderValue;
  final String? applicableOn;
  final String? color;

  factory PromoCodeSummary.fromJson(Map<String, dynamic> json) {
    return PromoCodeSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      code: _ApiModelParser.toStringValue(json['code']) ?? '',
      title: _ApiModelParser.toStringValue(json['title']),
      titleEn: _ApiModelParser.toStringValue(json['titleEn']),
      titleTe: _ApiModelParser.toStringValue(json['titleTe']),
      discountType: _ApiModelParser.toStringValue(json['discountType']),
      discountValue: _ApiModelParser.toDouble(json['discountValue']),
      maxDiscount: _ApiModelParser.toDouble(json['maxDiscount']),
      minOrderValue: _ApiModelParser.toDouble(json['minOrderValue']),
      applicableOn: _ApiModelParser.toStringValue(json['applicableOn']),
      color: _ApiModelParser.toStringValue(json['color']),
    );
  }

  String localizedTitle(AppLanguage language) {
    final preferred = language == AppLanguage.te ? titleTe : titleEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }

    final fallback = language == AppLanguage.te ? titleEn : titleTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }

    final baseTitle = title?.trim();
    if (baseTitle != null && baseTitle.isNotEmpty) {
      return baseTitle;
    }
    return code;
  }
}

class PromoCodesListApiResponse {
  const PromoCodesListApiResponse({
    required this.isSuccess,
    this.message,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final List<PromoCodeSummary> data;
  final List<String> errors;

  factory PromoCodesListApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataList = _ApiModelParser.toMapList(payload?['data']);
    final directList = _ApiModelParser.decodeMapList(rawBody);
    final parsed = dataList.isNotEmpty ? dataList : directList;

    return PromoCodesListApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: parsed.map(PromoCodeSummary.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class ServicesListApiResponse {
  const ServicesListApiResponse({
    required this.isSuccess,
    this.message,
    this.total,
    this.page,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final int? total;
  final int? page;
  final List<ServiceSummary> data;
  final List<String> errors;

  factory ServicesListApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataList = _ApiModelParser.toMapList(payload?['data']);

    return ServicesListApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      total: _ApiModelParser.toInt(payload?['total']),
      page: _ApiModelParser.toInt(payload?['page']),
      data: dataList.map(ServiceSummary.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class ServiceSlotSummary {
  const ServiceSlotSummary({
    required this.id,
    required this.slotTime,
    this.label,
    this.isAvailable,
  });

  final int id;
  final String slotTime;
  final String? label;
  final bool? isAvailable;

  factory ServiceSlotSummary.fromJson(Map<String, dynamic> json) {
    final time =
        _ApiModelParser.toStringValue(json['slotTime']) ??
        _ApiModelParser.toStringValue(json['time']) ??
        _ApiModelParser.toStringValue(json['startTime']) ??
        '';
    return ServiceSlotSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      slotTime: time,
      label:
          _ApiModelParser.toStringValue(json['label']) ??
          _ApiModelParser.toStringValue(json['displayTime']),
      isAvailable:
          _ApiModelParser.toBool(json['isAvailable']) ??
          (!(_ApiModelParser.toBool(json['booked']) ?? false)),
    );
  }
}

class ServiceSlotsApiResponse {
  const ServiceSlotsApiResponse({
    required this.isSuccess,
    this.message,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final List<ServiceSlotSummary> data;
  final List<String> errors;

  factory ServiceSlotsApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    final list = dataMap == null
        ? _ApiModelParser.toMapList(payload?['data'])
        : (_ApiModelParser.toMapList(dataMap['slots']).isNotEmpty
              ? _ApiModelParser.toMapList(dataMap['slots'])
              : _ApiModelParser.toMapList(dataMap['items']));
    final directList = _ApiModelParser.decodeMapList(rawBody);
    final parsed = list.isNotEmpty ? list : directList;

    return ServiceSlotsApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: parsed.map(ServiceSlotSummary.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class ServiceProfessionalSummary {
  const ServiceProfessionalSummary({
    required this.id,
    required this.name,
    this.rating,
    this.tag,
  });

  final int id;
  final String name;
  final double? rating;
  final String? tag;

  factory ServiceProfessionalSummary.fromJson(Map<String, dynamic> json) {
    return ServiceProfessionalSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      name:
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(json['fullName']) ??
          'Professional',
      rating: _ApiModelParser.toDouble(json['rating']),
      tag:
          _ApiModelParser.toStringValue(json['tag']) ??
          _ApiModelParser.toStringValue(json['badge']),
    );
  }
}

class ServiceProfessionalsApiResponse {
  const ServiceProfessionalsApiResponse({
    required this.isSuccess,
    this.message,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final List<ServiceProfessionalSummary> data;
  final List<String> errors;

  factory ServiceProfessionalsApiResponse.fromHttp(
    int statusCode,
    String rawBody,
  ) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final list = _ApiModelParser.toMapList(payload?['data']);
    final directList = _ApiModelParser.decodeMapList(rawBody);
    final parsed = list.isNotEmpty ? list : directList;

    return ServiceProfessionalsApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: parsed.map(ServiceProfessionalSummary.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class ServiceBookingApiResponse {
  const ServiceBookingApiResponse({
    required this.isSuccess,
    this.message,
    this.bookingId,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final int? bookingId;
  final List<String> errors;

  factory ServiceBookingApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    return ServiceBookingApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      bookingId:
          _ApiModelParser.toInt(dataMap?['id']) ??
          _ApiModelParser.toInt(payload?['id']),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class ServiceBookingSummary {
  const ServiceBookingSummary({
    required this.id,
    this.serviceId,
    this.serviceName,
    this.status,
    this.slotDate,
    this.slotTime,
    this.amount,
    this.professionalName,
    this.emoji,
    this.rating,
  });

  final int id;
  final int? serviceId;
  final String? serviceName;
  final String? status;
  final String? slotDate;
  final String? slotTime;
  final double? amount;
  final String? professionalName;
  final String? emoji;
  final int? rating;

  factory ServiceBookingSummary.fromJson(Map<String, dynamic> json) {
    final serviceMap = _ApiModelParser.toMap(json['service']);
    return ServiceBookingSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      serviceId:
          _ApiModelParser.toInt(json['serviceId']) ??
          _ApiModelParser.toInt(serviceMap?['id']),
      serviceName:
          _ApiModelParser.toStringValue(json['serviceName']) ??
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(serviceMap?['name']) ??
          _ApiModelParser.toStringValue(serviceMap?['nameEn']),
      status: _ApiModelParser.toStringValue(json['status']),
      slotDate: _ApiModelParser.toStringValue(json['slotDate']),
      slotTime:
          _ApiModelParser.toStringValue(json['slotTime']) ??
          _ApiModelParser.toStringValue(json['scheduledTime']),
      amount:
          _ApiModelParser.toDouble(json['amount']) ??
          _ApiModelParser.toDouble(json['price']) ??
          _ApiModelParser.toDouble(json['totalAmount']),
      professionalName:
          _ApiModelParser.toStringValue(json['professionalName']) ??
          _ApiModelParser.toStringValue(json['servicePersonName']) ??
          _ApiModelParser.toStringValue(json['assignedTo']),
      emoji:
          _ApiModelParser.toStringValue(json['emoji']) ??
          _ApiModelParser.toStringValue(serviceMap?['emoji']),
      rating: _ApiModelParser.toInt(json['rating']),
    );
  }

  String get scheduleLabel {
    final date = slotDate?.trim();
    final time = slotTime?.trim();
    if ((date ?? '').isNotEmpty && (time ?? '').isNotEmpty) {
      return '$date, $time';
    }
    if ((date ?? '').isNotEmpty) {
      return date!;
    }
    if ((time ?? '').isNotEmpty) {
      return time!;
    }
    return 'Schedule pending';
  }
}

class ServiceBookingsListApiResponse {
  const ServiceBookingsListApiResponse({
    required this.isSuccess,
    this.message,
    this.total,
    this.page,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final int? total;
  final int? page;
  final List<ServiceBookingSummary> data;
  final List<String> errors;

  factory ServiceBookingsListApiResponse.fromHttp(
    int statusCode,
    String rawBody,
  ) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataList = _ApiModelParser.toMapList(payload?['data']);

    return ServiceBookingsListApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      total: _ApiModelParser.toInt(payload?['total']),
      page: _ApiModelParser.toInt(payload?['page']),
      data: dataList.map(ServiceBookingSummary.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class HomeBannerSummary {
  const HomeBannerSummary({
    required this.id,
    this.title,
    this.subtitle,
    this.emoji,
    this.gradient,
    this.couponCode,
    this.imageUrl,
    this.linkedCategoryId,
    this.linkedProductId,
    this.deepLinkUrl,
  });

  final int id;
  final String? title;
  final String? subtitle;
  final String? emoji;
  final String? gradient;
  final String? couponCode;
  final String? imageUrl;
  final int? linkedCategoryId;
  final int? linkedProductId;
  final String? deepLinkUrl;

  factory HomeBannerSummary.fromJson(Map<String, dynamic> json) {
    return HomeBannerSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      title: _ApiModelParser.toStringValue(json['title']),
      subtitle: _ApiModelParser.toStringValue(json['subtitle']),
      emoji: _ApiModelParser.toStringValue(json['emoji']),
      gradient: _ApiModelParser.toStringValue(json['gradient']),
      couponCode: _ApiModelParser.toStringValue(json['couponCode']),
      imageUrl: _ApiModelParser.toStringValue(json['imageUrl']),
      linkedCategoryId: _ApiModelParser.toInt(json['linkedCategoryId']),
      linkedProductId: _ApiModelParser.toInt(json['linkedProductId']),
      deepLinkUrl:
          _ApiModelParser.toStringValue(json['deepLinkUrl']) ??
          _ApiModelParser.toStringValue(json['deepLink']),
    );
  }
}

class HomeCategoryPill {
  const HomeCategoryPill({
    required this.id,
    required this.name,
    this.emoji,
    this.nameEn,
    this.nameTe,
    this.iconUrl,
    this.sortOrder,
  });

  final int id;
  final String name;
  final String? emoji;
  final String? nameEn;
  final String? nameTe;
  final String? iconUrl;
  final int? sortOrder;

  factory HomeCategoryPill.fromJson(Map<String, dynamic> json) {
    return HomeCategoryPill(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      name:
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(json['nameEn']) ??
          _ApiModelParser.toStringValue(json['nameTe']) ??
          '',
      emoji: _ApiModelParser.toStringValue(json['emoji']),
      nameEn: _ApiModelParser.toStringValue(json['nameEn']),
      nameTe: _ApiModelParser.toStringValue(json['nameTe']),
      iconUrl: _ApiModelParser.toStringValue(json['iconUrl']),
      sortOrder: _ApiModelParser.toInt(json['sortOrder']),
    );
  }

  String localizedName(AppLanguage language) {
    final preferred = language == AppLanguage.te ? nameTe : nameEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }

    final fallback = language == AppLanguage.te ? nameEn : nameTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }
    return name;
  }
}

class HomeSubCategory {
  const HomeSubCategory({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameTe,
    this.iconUrl,
  });

  final int id;
  final String name;
  final String? nameEn;
  final String? nameTe;
  final String? iconUrl;

  factory HomeSubCategory.fromJson(Map<String, dynamic> json) {
    return HomeSubCategory(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      name:
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(json['nameEn']) ??
          _ApiModelParser.toStringValue(json['nameTe']) ??
          _ApiModelParser.toStringValue(json['title']) ??
          '',
      nameEn: _ApiModelParser.toStringValue(json['nameEn']),
      nameTe: _ApiModelParser.toStringValue(json['nameTe']),
      iconUrl: _ApiModelParser.toStringValue(json['iconUrl']),
    );
  }

  String localizedName(AppLanguage language) {
    final preferred = language == AppLanguage.te ? nameTe : nameEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }

    final fallback = language == AppLanguage.te ? nameEn : nameTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }
    return name;
  }
}

class HomeSection {
  const HomeSection({
    this.categoryId,
    this.title,
    this.subCategories = const [],
    this.products = const [],
    this.viewAllLink,
    this.offerBanner,
  });

  final int? categoryId;
  final String? title;
  final List<HomeSubCategory> subCategories;
  final List<ProductSummary> products;
  final String? viewAllLink;
  final String? offerBanner;

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      categoryId: _ApiModelParser.toInt(json['categoryId']),
      title: _ApiModelParser.toStringValue(json['title']),
      subCategories: _ApiModelParser.toMapList(
        json['subCategories'],
      ).map(HomeSubCategory.fromJson).toList(),
      products: _ApiModelParser.toMapList(
        json['products'],
      ).map(ProductSummary.fromJson).toList(),
      viewAllLink: _ApiModelParser.toStringValue(json['viewAllLink']),
      offerBanner: _ApiModelParser.toStringValue(json['offerBanner']),
    );
  }
}

class HomeSectionsData {
  const HomeSectionsData({
    this.nearestShop,
    this.banners = const [],
    this.categoryPills = const [],
    this.sections = const [],
    this.deliveryZone,
  });

  final String? nearestShop;
  final List<HomeBannerSummary> banners;
  final List<HomeCategoryPill> categoryPills;
  final List<HomeSection> sections;
  final PincodeCheckData? deliveryZone;

  factory HomeSectionsData.fromJson(Map<String, dynamic> json) {
    return HomeSectionsData(
      nearestShop: _ApiModelParser.toStringValue(json['nearestShop']),
      banners: _ApiModelParser.toMapList(
        json['banners'],
      ).map(HomeBannerSummary.fromJson).toList(),
      categoryPills: _ApiModelParser.toMapList(
        json['categoryPills'],
      ).map(HomeCategoryPill.fromJson).toList(),
      sections: _ApiModelParser.toMapList(
        json['sections'],
      ).map(HomeSection.fromJson).toList(),
      deliveryZone: _ApiModelParser.toMap(json['deliveryZone']) == null
          ? null
          : PincodeCheckData.fromJson(
              _ApiModelParser.toMap(json['deliveryZone'])!,
            ),
    );
  }
}

class HomeSectionsApiResponse {
  const HomeSectionsApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final HomeSectionsData? data;
  final List<String> errors;

  factory HomeSectionsApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    return HomeSectionsApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null ? null : HomeSectionsData.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class HomeSearchData {
  const HomeSearchData({
    this.query,
    this.totalProducts,
    this.products = const [],
    this.categories = const [],
  });

  final String? query;
  final int? totalProducts;
  final List<ProductSummary> products;
  final List<HomeCategoryPill> categories;

  factory HomeSearchData.fromJson(Map<String, dynamic> json) {
    return HomeSearchData(
      query: _ApiModelParser.toStringValue(json['query']),
      totalProducts: _ApiModelParser.toInt(json['totalProducts']),
      products: _ApiModelParser.toMapList(
        json['products'],
      ).map(ProductSummary.fromJson).toList(),
      categories: _ApiModelParser.toMapList(
        json['categories'],
      ).map(HomeCategoryPill.fromJson).toList(),
    );
  }
}

class HomeSearchApiResponse {
  const HomeSearchApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final HomeSearchData? data;
  final List<String> errors;

  factory HomeSearchApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);

    return HomeSearchApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null ? null : HomeSearchData.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class CategorySummary {
  const CategorySummary({
    required this.id,
    required this.name,
    this.emoji,
    this.slug,
    this.type,
    this.colorBg,
    this.colorText,
    this.nameEn,
    this.nameTe,
    this.iconUrl,
    this.bannerUrl,
    this.sortOrder,
    this.productCount,
    this.subCategoryItems = const [],
    this.subCategories = const [],
  });

  final int id;
  final String name;
  final String? emoji;
  final String? slug;
  final String? type;
  final String? colorBg;
  final String? colorText;
  final String? nameEn;
  final String? nameTe;
  final String? iconUrl;
  final String? bannerUrl;
  final int? sortOrder;
  final int? productCount;
  final List<HomeSubCategory> subCategoryItems;
  final List<String> subCategories;

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      name:
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(json['nameEn']) ??
          _ApiModelParser.toStringValue(json['nameTe']) ??
          '',
      emoji: _ApiModelParser.toStringValue(json['emoji']),
      slug: _ApiModelParser.toStringValue(json['slug']),
      type: _ApiModelParser.toStringValue(json['type']),
      colorBg: _ApiModelParser.toStringValue(json['colorBg']),
      colorText: _ApiModelParser.toStringValue(json['colorText']),
      nameEn: _ApiModelParser.toStringValue(json['nameEn']),
      nameTe: _ApiModelParser.toStringValue(json['nameTe']),
      iconUrl: _ApiModelParser.toStringValue(json['iconUrl']),
      bannerUrl: _ApiModelParser.toStringValue(json['bannerUrl']),
      sortOrder: _ApiModelParser.toInt(json['sortOrder']),
      productCount: _ApiModelParser.toInt(json['productCount']),
      subCategoryItems: _ApiModelParser.toMapList(
        json['subCategories'],
      ).map(HomeSubCategory.fromJson).toList(),
      subCategories: _ApiModelParser.toSubCategoryNames(json['subCategories']),
    );
  }

  String localizedName(AppLanguage language) {
    final preferred = language == AppLanguage.te ? nameTe : nameEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }

    final fallback = language == AppLanguage.te ? nameEn : nameTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }
    return name;
  }
}

class CategoriesListApiResponse {
  const CategoriesListApiResponse({
    required this.isSuccess,
    this.message,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final List<CategorySummary> data;
  final List<String> errors;

  factory CategoriesListApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final list = payload == null
        ? _ApiModelParser.decodeMapList(rawBody)
        : _ApiModelParser.toMapList(payload['data']);
    return CategoriesListApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: list.map(CategorySummary.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class CategoryDetailsApiResponse {
  const CategoryDetailsApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final CategorySummary? data;
  final List<String> errors;

  factory CategoryDetailsApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final map = payload == null
        ? _ApiModelParser.decodeObject(rawBody)
        : (_ApiModelParser.toMap(payload['data']) ?? payload);
    return CategoryDetailsApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: map == null ? null : CategorySummary.fromJson(map),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class CategoryProductsData {
  const CategoryProductsData({
    this.categoryId,
    this.categoryName,
    this.categoryBannerUrl,
    this.subCategories = const [],
    this.products,
    this.offerBanner,
  });

  final int? categoryId;
  final String? categoryName;
  final String? categoryBannerUrl;
  final List<HomeSubCategory> subCategories;
  final ProductsPageData? products;
  final String? offerBanner;

  factory CategoryProductsData.fromJson(Map<String, dynamic> json) {
    final productsMap = _ApiModelParser.toMap(json['products']);
    final productsList = _ApiModelParser.toMapList(json['products']);
    return CategoryProductsData(
      categoryId: _ApiModelParser.toInt(json['categoryId']),
      categoryName: _ApiModelParser.toStringValue(json['categoryName']),
      categoryBannerUrl: _ApiModelParser.toStringValue(
        json['categoryBannerUrl'],
      ),
      subCategories: _ApiModelParser.toMapList(
        json['subCategories'],
      ).map(HomeSubCategory.fromJson).toList(),
      products: productsMap != null
          ? ProductsPageData.fromJson(productsMap)
          : (productsList.isNotEmpty
                ? ProductsPageData(
                    items: productsList.map(ProductSummary.fromJson).toList(),
                  )
                : null),
      offerBanner: _ApiModelParser.toStringValue(json['offerBanner']),
    );
  }
}

class CategoryProductsApiResponse {
  const CategoryProductsApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final CategoryProductsData? data;
  final List<String> errors;

  factory CategoryProductsApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']) ?? payload;

    return CategoryProductsApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null || dataMap.isEmpty
          ? null
          : CategoryProductsData.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }

  factory CategoryProductsApiResponse.fromProductsHttp(
    int statusCode,
    String rawBody, {
    required int categoryId,
  }) {
    final productsResponse = ProductsListApiResponse.fromHttp(
      statusCode,
      rawBody,
    );
    return CategoryProductsApiResponse(
      isSuccess: productsResponse.isSuccess,
      message: productsResponse.message,
      data: CategoryProductsData(
        categoryId: categoryId,
        products: productsResponse.data,
      ),
      errors: productsResponse.errors,
    );
  }
}

class CategoryTreeNode {
  const CategoryTreeNode({
    required this.id,
    required this.name,
    this.iconUrl,
    this.productCount,
    this.children = const [],
  });

  final int id;
  final String name;
  final String? iconUrl;
  final int? productCount;
  final List<CategoryTreeNode> children;

  factory CategoryTreeNode.fromJson(Map<String, dynamic> json) {
    return CategoryTreeNode(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      name: _ApiModelParser.toStringValue(json['name']) ?? '',
      iconUrl: _ApiModelParser.toStringValue(json['iconUrl']),
      productCount: _ApiModelParser.toInt(json['productCount']),
      children: _ApiModelParser.toMapList(
        json['children'],
      ).map(CategoryTreeNode.fromJson).toList(),
    );
  }
}

class CategoriesTreeApiResponse {
  const CategoriesTreeApiResponse({
    required this.isSuccess,
    this.message,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final List<CategoryTreeNode> data;
  final List<String> errors;

  factory CategoriesTreeApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final list = _ApiModelParser.toMapList(payload?['data']);

    return CategoriesTreeApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: list.map(CategoryTreeNode.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.name,
    this.emoji,
    this.nameEn,
    this.nameTe,
    this.description,
    this.price,
    this.mrpPrice,
    this.discountPct,
    this.unit,
    this.unitEn,
    this.unitTe,
    this.stockQty,
    this.inStock,
    this.minOrderQty,
    this.maxOrderQty,
    this.imageUrl,
    this.image2Url,
    this.image3Url,
    this.categoryId,
    this.categoryName,
    this.brand,
    this.tag,
    this.rating,
    this.isFeatured,
  });

  final int id;
  final String name;
  final String? emoji;
  final String? nameEn;
  final String? nameTe;
  final String? description;
  final double? price;
  final double? mrpPrice;
  final double? discountPct;
  final String? unit;
  final String? unitEn;
  final String? unitTe;
  final int? stockQty;
  final bool? inStock;
  final int? minOrderQty;
  final int? maxOrderQty;
  final String? imageUrl;
  final String? image2Url;
  final String? image3Url;
  final int? categoryId;
  final String? categoryName;
  final String? brand;
  final String? tag;
  final double? rating;
  final bool? isFeatured;

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    return ProductSummary(
      id: _ApiModelParser.toInt(json['id']) ?? 0,
      name:
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(json['nameEn']) ??
          _ApiModelParser.toStringValue(json['nameTe']) ??
          '',
      emoji: _ApiModelParser.toStringValue(json['emoji']),
      nameEn: _ApiModelParser.toStringValue(json['nameEn']),
      nameTe: _ApiModelParser.toStringValue(json['nameTe']),
      description:
          _ApiModelParser.toStringValue(json['description']) ??
          _ApiModelParser.toStringValue(json['desc']),
      price: _ApiModelParser.toDouble(json['price']),
      mrpPrice:
          _ApiModelParser.toDouble(json['mrpPrice']) ??
          _ApiModelParser.toDouble(json['mrp']),
      discountPct:
          _ApiModelParser.toDouble(json['discountPct']) ??
          _ApiModelParser.toDouble(json['discount']),
      unit:
          _ApiModelParser.toStringValue(json['unit']) ??
          _ApiModelParser.toStringValue(json['weight']),
      unitEn: _ApiModelParser.toStringValue(json['unitEn']),
      unitTe: _ApiModelParser.toStringValue(json['unitTe']),
      stockQty: _ApiModelParser.toInt(json['stockQty']),
      inStock: _ApiModelParser.toBool(json['inStock']),
      minOrderQty: _ApiModelParser.toInt(json['minOrderQty']),
      maxOrderQty: _ApiModelParser.toInt(json['maxOrderQty']),
      imageUrl:
          _ApiModelParser.toStringValue(json['imageUrl']) ??
          _ApiModelParser.toStringValue(json['image']) ??
          _ApiModelParser.toStringValue(json['thumbnail']) ??
          _ApiModelParser.toStringValue(json['image1Url']),
      image2Url:
          _ApiModelParser.toStringValue(json['image2Url']) ??
          _ApiModelParser.toStringValue(json['image2']),
      image3Url:
          _ApiModelParser.toStringValue(json['image3Url']) ??
          _ApiModelParser.toStringValue(json['image3']),
      categoryId: _ApiModelParser.toInt(json['categoryId']),
      categoryName: _ApiModelParser.toStringValue(json['categoryName']),
      brand: _ApiModelParser.toStringValue(json['brand']),
      tag: _ApiModelParser.toStringValue(json['tag']),
      rating: _ApiModelParser.toDouble(json['rating']),
      isFeatured:
          _ApiModelParser.toBool(json['isFeatured']) ??
          _ApiModelParser.toBool(json['featured']),
    );
  }

  String? get displayTag {
    final value = tag?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    final brandValue = brand?.trim();
    if (brandValue != null && brandValue.isNotEmpty) {
      return brandValue;
    }
    return null;
  }

  String localizedName(AppLanguage language) {
    final preferred = language == AppLanguage.te ? nameTe : nameEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }

    final fallback = language == AppLanguage.te ? nameEn : nameTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }
    return name;
  }

  String? localizedUnit(AppLanguage language) {
    final preferred = language == AppLanguage.te ? unitTe : unitEn;
    if ((preferred ?? '').trim().isNotEmpty) {
      return preferred!.trim();
    }

    final fallback = language == AppLanguage.te ? unitEn : unitTe;
    if ((fallback ?? '').trim().isNotEmpty) {
      return fallback!.trim();
    }

    final base = unit?.trim();
    if (base != null && base.isNotEmpty) {
      return base;
    }
    return null;
  }
}

class ProductsPageData {
  const ProductsPageData({
    this.items = const [],
    this.totalCount,
    this.pageNumber,
    this.pageSize,
    this.totalPages,
    this.hasNext,
    this.hasPrev,
  });

  final List<ProductSummary> items;
  final int? totalCount;
  final int? pageNumber;
  final int? pageSize;
  final int? totalPages;
  final bool? hasNext;
  final bool? hasPrev;

  factory ProductsPageData.fromJson(Map<String, dynamic> json) {
    final list = _ApiModelParser.toMapList(json['items']).isNotEmpty
        ? _ApiModelParser.toMapList(json['items'])
        : _ApiModelParser.toMapList(json['products']);
    return ProductsPageData(
      items: list.map(ProductSummary.fromJson).toList(),
      totalCount: _ApiModelParser.toInt(json['totalCount']),
      pageNumber: _ApiModelParser.toInt(json['pageNumber']),
      pageSize: _ApiModelParser.toInt(json['pageSize']),
      totalPages: _ApiModelParser.toInt(json['totalPages']),
      hasNext: _ApiModelParser.toBool(json['hasNext']),
      hasPrev: _ApiModelParser.toBool(json['hasPrev']),
    );
  }
}

class ProductsListApiResponse {
  const ProductsListApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final ProductsPageData? data;
  final List<String> errors;

  factory ProductsListApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final directList = _ApiModelParser.decodeMapList(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    final dataList = _ApiModelParser.toMapList(payload?['data']);

    ProductsPageData? parsedData;
    if (dataMap != null) {
      parsedData = ProductsPageData.fromJson(dataMap);
    } else if (dataList.isNotEmpty) {
      parsedData = ProductsPageData(
        items: dataList.map(ProductSummary.fromJson).toList(),
        totalCount:
            _ApiModelParser.toInt(payload?['totalCount']) ??
            _ApiModelParser.toInt(payload?['total']),
        pageNumber:
            _ApiModelParser.toInt(payload?['pageNumber']) ??
            _ApiModelParser.toInt(payload?['page']),
        pageSize: _ApiModelParser.toInt(payload?['pageSize']),
      );
    } else if (payload != null && payload.containsKey('items')) {
      parsedData = ProductsPageData.fromJson(payload);
    } else if (directList.isNotEmpty) {
      parsedData = ProductsPageData(
        items: directList.map(ProductSummary.fromJson).toList(),
      );
    } else {
      final payloadProductList = payload == null
          ? const <Map<String, dynamic>>[]
          : _ApiModelParser.toMapList(payload['products']);
      if (payloadProductList.isNotEmpty) {
        parsedData = ProductsPageData(
          items: payloadProductList.map(ProductSummary.fromJson).toList(),
          totalCount:
              _ApiModelParser.toInt(payload?['totalCount']) ??
              _ApiModelParser.toInt(payload?['total']),
          pageNumber:
              _ApiModelParser.toInt(payload?['pageNumber']) ??
              _ApiModelParser.toInt(payload?['page']),
          pageSize: _ApiModelParser.toInt(payload?['pageSize']),
        );
      }
    }

    return ProductsListApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: parsedData,
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class ProductDetailsApiResponse {
  const ProductDetailsApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final ProductSummary? data;
  final List<String> errors;

  factory ProductDetailsApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final map = _ApiModelParser.toMap(payload?['data']) ?? payload;

    return ProductDetailsApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: map == null || map.isEmpty ? null : ProductSummary.fromJson(map),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class PincodeCheckData {
  const PincodeCheckData({
    this.pincode,
    this.areaName,
    this.mandal,
    this.district,
    this.deliveryCharge,
    this.freeDeliveryAbove,
    this.estimatedDeliveryHours,
    this.isServiceable,
  });

  final String? pincode;
  final String? areaName;
  final String? mandal;
  final String? district;
  final double? deliveryCharge;
  final double? freeDeliveryAbove;
  final int? estimatedDeliveryHours;
  final bool? isServiceable;

  factory PincodeCheckData.fromJson(Map<String, dynamic> json) {
    return PincodeCheckData(
      pincode: _ApiModelParser.toStringValue(json['pincode']),
      areaName: _ApiModelParser.toStringValue(json['areaName']),
      mandal: _ApiModelParser.toStringValue(json['mandal']),
      district: _ApiModelParser.toStringValue(json['district']),
      deliveryCharge: _ApiModelParser.toDouble(json['deliveryCharge']),
      freeDeliveryAbove: _ApiModelParser.toDouble(json['freeDeliveryAbove']),
      estimatedDeliveryHours: _ApiModelParser.toInt(
        json['estimatedDeliveryHours'],
      ),
      isServiceable: _ApiModelParser.toBool(json['isServiceable']),
    );
  }
}

class ProductPincodeCheckApiResponse {
  const ProductPincodeCheckApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final PincodeCheckData? data;
  final List<String> errors;

  factory ProductPincodeCheckApiResponse.fromHttp(
    int statusCode,
    String rawBody,
  ) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);

    return ProductPincodeCheckApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null ? null : PincodeCheckData.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class CartUpdateRequest {
  const CartUpdateRequest({required this.productId, required this.quantity});

  final int productId;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {'productId': productId, 'quantity': quantity};
  }
}

class CartItemModel {
  const CartItemModel({
    this.cartItemId,
    this.productId,
    this.productName,
    this.emoji,
    this.imageUrl,
    this.unitPrice,
    this.unit,
    this.quantity,
    this.totalPrice,
    this.maxOrderQty,
    this.inStock,
  });

  final int? cartItemId;
  final int? productId;
  final String? productName;
  final String? emoji;
  final String? imageUrl;
  final double? unitPrice;
  final String? unit;
  final int? quantity;
  final double? totalPrice;
  final int? maxOrderQty;
  final bool? inStock;

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final productMap = _ApiModelParser.toMap(json['product']);
    final resolvedCartItemId =
        _ApiModelParser.toInt(json['cartItemId']) ??
        _ApiModelParser.toInt(json['id']);
    final resolvedProductId =
        _ApiModelParser.toInt(json['productId']) ??
        _ApiModelParser.toInt(json['productID']) ??
        _ApiModelParser.toInt(json['itemProductId']) ??
        _ApiModelParser.toInt(productMap?['productId']) ??
        _ApiModelParser.toInt(productMap?['id']) ??
        // Fall back to `id` only when this payload appears to be a direct product list.
        (json.containsKey('cartItemId')
            ? null
            : _ApiModelParser.toInt(json['id']));

    return CartItemModel(
      cartItemId: resolvedCartItemId,
      productId: resolvedProductId,
      productName:
          _ApiModelParser.toStringValue(json['productName']) ??
          _ApiModelParser.toStringValue(json['name']) ??
          _ApiModelParser.toStringValue(json['nameEn']) ??
          _ApiModelParser.toStringValue(json['nameTe']) ??
          _ApiModelParser.toStringValue(json['product_title']) ??
          _ApiModelParser.toStringValue(productMap?['productName']) ??
          _ApiModelParser.toStringValue(productMap?['name']) ??
          _ApiModelParser.toStringValue(productMap?['nameEn']) ??
          _ApiModelParser.toStringValue(productMap?['nameTe']) ??
          _ApiModelParser.toStringValue(productMap?['title']),
      emoji:
          _ApiModelParser.toStringValue(json['emoji']) ??
          _ApiModelParser.toStringValue(productMap?['emoji']),
      imageUrl:
          _ApiModelParser.toStringValue(json['imageUrl']) ??
          _ApiModelParser.toStringValue(json['image']) ??
          _ApiModelParser.toStringValue(json['thumbnail']) ??
          _ApiModelParser.toStringValue(productMap?['imageUrl']) ??
          _ApiModelParser.toStringValue(productMap?['image']) ??
          _ApiModelParser.toStringValue(productMap?['thumbnail']),
      unitPrice:
          _ApiModelParser.toDouble(json['unitPrice']) ??
          _ApiModelParser.toDouble(json['price']) ??
          _ApiModelParser.toDouble(productMap?['unitPrice']) ??
          _ApiModelParser.toDouble(productMap?['price']),
      unit:
          _ApiModelParser.toStringValue(json['unit']) ??
          _ApiModelParser.toStringValue(json['weight']) ??
          _ApiModelParser.toStringValue(productMap?['unit']) ??
          _ApiModelParser.toStringValue(productMap?['weight']),
      quantity:
          _ApiModelParser.toInt(json['quantity']) ??
          _ApiModelParser.toInt(json['qty']),
      totalPrice:
          _ApiModelParser.toDouble(json['totalPrice']) ??
          _ApiModelParser.toDouble(json['lineTotal']) ??
          _ApiModelParser.toDouble(json['amount']),
      maxOrderQty:
          _ApiModelParser.toInt(json['maxOrderQty']) ??
          _ApiModelParser.toInt(json['maxQty']),
      inStock: _ApiModelParser.toBool(json['inStock']),
    );
  }
}

class CartData {
  const CartData({
    this.items = const [],
    this.totalItems,
    this.subTotal,
    this.deliveryCharge,
    this.taxes,
    this.discount,
    this.totalAmount,
    this.freeDelivery,
    this.freeDeliveryAbove,
  });

  final List<CartItemModel> items;
  final int? totalItems;
  final double? subTotal;
  final double? deliveryCharge;
  final double? taxes;
  final double? discount;
  final double? totalAmount;
  final bool? freeDelivery;
  final double? freeDeliveryAbove;

  factory CartData.fromJson(Map<String, dynamic> json) {
    final list = _ApiModelParser.toMapList(json['items']).isNotEmpty
        ? _ApiModelParser.toMapList(json['items'])
        : (_ApiModelParser.toMapList(json['cartItems']).isNotEmpty
              ? _ApiModelParser.toMapList(json['cartItems'])
              : _ApiModelParser.toMapList(json['products']));
    return CartData(
      items: list.map(CartItemModel.fromJson).toList(),
      totalItems:
          _ApiModelParser.toInt(json['totalItems']) ??
          _ApiModelParser.toInt(json['itemCount']),
      subTotal:
          _ApiModelParser.toDouble(json['subTotal']) ??
          _ApiModelParser.toDouble(json['subtotal']),
      deliveryCharge:
          _ApiModelParser.toDouble(json['deliveryCharge']) ??
          _ApiModelParser.toDouble(json['deliveryFee']) ??
          _ApiModelParser.toDouble(json['shippingCharge']),
      taxes:
          _ApiModelParser.toDouble(json['taxes']) ??
          _ApiModelParser.toDouble(json['tax']) ??
          _ApiModelParser.toDouble(json['gst']),
      discount: _ApiModelParser.toDouble(json['discount']),
      totalAmount:
          _ApiModelParser.toDouble(json['totalAmount']) ??
          _ApiModelParser.toDouble(json['grandTotal']) ??
          _ApiModelParser.toDouble(json['total']),
      freeDelivery: _ApiModelParser.toBool(json['freeDelivery']),
      freeDeliveryAbove: _ApiModelParser.toDouble(json['freeDeliveryAbove']),
    );
  }
}

class CartApiResponse {
  const CartApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final CartData? data;
  final List<String> errors;

  factory CartApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap =
        _ApiModelParser.toMap(payload?['data']) ??
        ((payload != null &&
                (payload.containsKey('items') ||
                    payload.containsKey('cartItems') ||
                    payload.containsKey('products')))
            ? payload
            : null);
    final dataList = _ApiModelParser.toMapList(payload?['data']);
    final directList = _ApiModelParser.decodeMapList(rawBody);

    CartData? parsedData;
    if (dataMap != null) {
      parsedData = CartData.fromJson(dataMap);
    } else if (dataList.isNotEmpty) {
      parsedData = CartData(
        items: dataList.map(CartItemModel.fromJson).toList(),
      );
    } else if (directList.isNotEmpty) {
      parsedData = CartData(
        items: directList.map(CartItemModel.fromJson).toList(),
      );
    }

    return CartApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: parsedData,
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class OrderItemModel {
  const OrderItemModel({
    this.productId,
    this.productName,
    this.imageUrl,
    this.unit,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
  });

  final int? productId;
  final String? productName;
  final String? imageUrl;
  final String? unit;
  final int? quantity;
  final double? unitPrice;
  final double? totalPrice;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: _ApiModelParser.toInt(json['productId']),
      productName: _ApiModelParser.toStringValue(json['productName']),
      imageUrl: _ApiModelParser.toStringValue(json['imageUrl']),
      unit: _ApiModelParser.toStringValue(json['unit']),
      quantity: _ApiModelParser.toInt(json['quantity']),
      unitPrice: _ApiModelParser.toDouble(json['unitPrice']),
      totalPrice: _ApiModelParser.toDouble(json['totalPrice']),
    );
  }
}

class OrderTrackingModel {
  const OrderTrackingModel({
    this.status,
    this.statusTe,
    this.note,
    this.trackedAt,
  });

  final String? status;
  final String? statusTe;
  final String? note;
  final DateTime? trackedAt;

  factory OrderTrackingModel.fromJson(Map<String, dynamic> json) {
    return OrderTrackingModel(
      status: _ApiModelParser.toStringValue(json['status']),
      statusTe: _ApiModelParser.toStringValue(json['statusTe']),
      note: _ApiModelParser.toStringValue(json['note']),
      trackedAt: _ApiModelParser.toDateTime(json['trackedAt']),
    );
  }
}

class OrderModel {
  const OrderModel({
    this.id,
    this.orderNumber,
    this.status,
    this.statusTe,
    this.paymentMode,
    this.subTotal,
    this.deliveryCharge,
    this.discount,
    this.totalAmount,
    this.deliveryAddress,
    this.specialInstructions,
    this.estimatedDelivery,
    this.deliveredAt,
    this.createdAt,
    this.items = const [],
    this.tracking = const [],
  });

  final int? id;
  final String? orderNumber;
  final String? status;
  final String? statusTe;
  final String? paymentMode;
  final double? subTotal;
  final double? deliveryCharge;
  final double? discount;
  final double? totalAmount;
  final String? deliveryAddress;
  final String? specialInstructions;
  final DateTime? estimatedDelivery;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final List<OrderItemModel> items;
  final List<OrderTrackingModel> tracking;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemMaps = _ApiModelParser.toMapList(json['items']);
    final trackingMaps = _ApiModelParser.toMapList(json['tracking']);

    return OrderModel(
      id: _ApiModelParser.toInt(json['id']),
      orderNumber: _ApiModelParser.toStringValue(json['orderNumber']),
      status: _ApiModelParser.toStringValue(json['status']),
      statusTe: _ApiModelParser.toStringValue(json['statusTe']),
      paymentMode: _ApiModelParser.toStringValue(json['paymentMode']),
      subTotal: _ApiModelParser.toDouble(json['subTotal']),
      deliveryCharge: _ApiModelParser.toDouble(json['deliveryCharge']),
      discount: _ApiModelParser.toDouble(json['discount']),
      totalAmount: _ApiModelParser.toDouble(json['totalAmount']),
      deliveryAddress: _ApiModelParser.toStringValue(json['deliveryAddress']),
      specialInstructions: _ApiModelParser.toStringValue(
        json['specialInstructions'],
      ),
      estimatedDelivery: _ApiModelParser.toDateTime(json['estimatedDelivery']),
      deliveredAt: _ApiModelParser.toDateTime(json['deliveredAt']),
      createdAt: _ApiModelParser.toDateTime(json['createdAt']),
      items: itemMaps.map(OrderItemModel.fromJson).toList(),
      tracking: trackingMaps.map(OrderTrackingModel.fromJson).toList(),
    );
  }
}

class OrdersPageData {
  const OrdersPageData({
    this.items = const [],
    this.totalCount,
    this.pageNumber,
    this.pageSize,
    this.totalPages,
    this.hasNext,
    this.hasPrev,
  });

  final List<OrderModel> items;
  final int? totalCount;
  final int? pageNumber;
  final int? pageSize;
  final int? totalPages;
  final bool? hasNext;
  final bool? hasPrev;

  factory OrdersPageData.fromJson(Map<String, dynamic> json) {
    final list = _ApiModelParser.toMapList(json['items']);
    return OrdersPageData(
      items: list.map(OrderModel.fromJson).toList(),
      totalCount: _ApiModelParser.toInt(json['totalCount']),
      pageNumber: _ApiModelParser.toInt(json['pageNumber']),
      pageSize: _ApiModelParser.toInt(json['pageSize']),
      totalPages: _ApiModelParser.toInt(json['totalPages']),
      hasNext: _ApiModelParser.toBool(json['hasNext']),
      hasPrev: _ApiModelParser.toBool(json['hasPrev']),
    );
  }
}

class OrdersListApiResponse {
  const OrdersListApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final OrdersPageData? data;
  final List<String> errors;

  factory OrdersListApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    return OrdersListApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null ? null : OrdersPageData.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class OrderApiResponse {
  const OrderApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final OrderModel? data;
  final List<String> errors;

  factory OrderApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    return OrderApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null ? null : OrderModel.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class UserProfileModel {
  const UserProfileModel({
    this.id,
    this.mobile,
    this.name,
    this.village,
    this.pincode,
    this.createdAt,
  });

  final int? id;
  final String? mobile;
  final String? name;
  final String? village;
  final String? pincode;
  final DateTime? createdAt;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: _ApiModelParser.toInt(json['id']),
      mobile: _ApiModelParser.toStringValue(json['mobile']),
      name: _ApiModelParser.toStringValue(json['name']),
      village: _ApiModelParser.toStringValue(json['village']),
      pincode: _ApiModelParser.toStringValue(json['pincode']),
      createdAt: _ApiModelParser.toDateTime(json['createdAt']),
    );
  }
}

class UserProfileApiResponse {
  const UserProfileApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final UserProfileModel? data;
  final List<String> errors;

  factory UserProfileApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    return UserProfileApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null ? null : UserProfileModel.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class AddressModel {
  const AddressModel({
    this.id,
    this.label,
    this.addressLine,
    this.village,
    this.mandal,
    this.district,
    this.pincode,
    this.isDefault,
    this.latitude,
    this.longitude,
  });

  final int? id;
  final String? label;
  final String? addressLine;
  final String? village;
  final String? mandal;
  final String? district;
  final String? pincode;
  final bool? isDefault;
  final double? latitude;
  final double? longitude;

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: _ApiModelParser.toInt(json['id']),
      label: _ApiModelParser.toStringValue(json['label']),
      addressLine: _ApiModelParser.toStringValue(json['addressLine']),
      village: _ApiModelParser.toStringValue(json['village']),
      mandal: _ApiModelParser.toStringValue(json['mandal']),
      district: _ApiModelParser.toStringValue(json['district']),
      pincode: _ApiModelParser.toStringValue(json['pincode']),
      isDefault: _ApiModelParser.toBool(json['isDefault']),
      latitude: _ApiModelParser.toDouble(json['latitude']),
      longitude: _ApiModelParser.toDouble(json['longitude']),
    );
  }
}

class AddressesApiResponse {
  const AddressesApiResponse({
    required this.isSuccess,
    this.message,
    this.data = const [],
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final List<AddressModel> data;
  final List<String> errors;

  factory AddressesApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final list = _ApiModelParser.toMapList(payload?['data']);

    return AddressesApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: list.map(AddressModel.fromJson).toList(),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class AddressApiResponse {
  const AddressApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final AddressModel? data;
  final List<String> errors;

  factory AddressApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    final dataMap = _ApiModelParser.toMap(payload?['data']);
    return AddressApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: dataMap == null ? null : AddressModel.fromJson(dataMap),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class StringDataApiResponse {
  const StringDataApiResponse({
    required this.isSuccess,
    this.message,
    this.data,
    this.errors = const [],
  });

  final bool isSuccess;
  final String? message;
  final String? data;
  final List<String> errors;

  factory StringDataApiResponse.fromHttp(int statusCode, String rawBody) {
    final payload = _ApiModelParser.decodeObject(rawBody);
    return StringDataApiResponse(
      isSuccess: statusCode >= 200 && statusCode < 300,
      message: _ApiModelParser.extractMessage(payload),
      data: _ApiModelParser.toStringValue(payload?['data']),
      errors: _ApiModelParser.toStringList(payload?['errors']),
    );
  }
}

class _ApiModelParser {
  static Map<String, dynamic>? decodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> decodeMapList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static String? extractMessage(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    for (final key in ['message', 'error', 'detail', 'description']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final errors = payload['errors'];
    if (errors is String && errors.trim().isNotEmpty) {
      return errors.trim();
    }

    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is String && first.trim().isNotEmpty) {
        return first.trim();
      }
      if (first is Map<String, dynamic>) {
        for (final key in ['message', 'error']) {
          final value = first[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    }

    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.trim().isNotEmpty) {
            return first.trim();
          }
          return first.toString();
        }
        if (value != null) {
          return value.toString();
        }
      }
    }

    return null;
  }

  static String? extractOtpCode(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    for (final key in ['otpCode', 'otp', 'code']) {
      final value = payload[key];
      final otp = normalizeOtp(value?.toString());
      if (otp != null) {
        return otp;
      }
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      for (final key in ['otpCode', 'otp', 'code']) {
        final value = data[key];
        final otp = normalizeOtp(value?.toString());
        if (otp != null) {
          return otp;
        }
      }
    }

    final message = extractMessage(payload);
    return normalizeOtp(message);
  }

  static String? extractAccessToken(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    String? fromAny(Map<String, dynamic>? map) {
      if (map == null) {
        return null;
      }
      for (final key in [
        'token',
        'accessToken',
        'jwt',
        'bearerToken',
        'authToken',
      ]) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    return fromAny(_ApiModelParser.toMap(payload['data'])) ?? fromAny(payload);
  }

  static String? normalizeOtp(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final match = RegExp(r'\b(\d{4})\b').firstMatch(raw);
    return match?.group(1);
  }

  static String? pickFirstString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? pickFirstMinutesText(
    Map<String, dynamic>? map,
    List<String> keys,
  ) {
    if (map == null) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return '$value minutes';
      }
      if (value is String) {
        final n = int.tryParse(value);
        if (n != null) {
          return '$n minutes';
        }
      }
    }
    return null;
  }

  static Map<String, dynamic>? toMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static List<Map<String, dynamic>> toMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static List<String> toStringList(dynamic value) {
    if (value is Map) {
      final list = <String>[];
      for (final entry in value.entries) {
        final v = entry.value;
        if (v is List) {
          list.addAll(v.map((e) => e.toString()));
        } else if (v != null) {
          list.add(v.toString());
        }
      }
      return list;
    }
    if (value is! List) {
      return const [];
    }
    return value.map((e) => e.toString()).toList();
  }

  static List<String> toSubCategoryNames(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final names = <String>[];
    for (final item in value) {
      if (item == null) {
        continue;
      }
      if (item is String && item.trim().isNotEmpty) {
        names.add(item.trim());
        continue;
      }
      if (item is Map<String, dynamic>) {
        final candidate = pickFirstString(item, const [
          'name',
          'nameEn',
          'title',
          'label',
        ]);
        if (candidate != null && candidate.trim().isNotEmpty) {
          names.add(candidate.trim());
        }
      }
    }
    return names;
  }

  static String? toStringValue(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int? toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static bool? toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true') {
        return true;
      }
      if (v == 'false') {
        return false;
      }
    }
    return null;
  }

  static DateTime? toDateTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
