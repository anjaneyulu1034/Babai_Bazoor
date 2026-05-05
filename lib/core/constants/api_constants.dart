class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = 'http://204.168.159.160:8085';
  static const String apiV1 = '/api/v1';

  static String resolveMediaUrl(String? rawValue) {
    final raw = rawValue?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) {
      return raw;
    }

    final base = Uri.parse(baseUrl);
    if (raw.startsWith('/')) {
      return base.resolve(raw).toString();
    }
    return base.resolve('/$raw').toString();
  }
}

class AuthApiEndpoints {
  const AuthApiEndpoints._();

  static Uri sendOtp() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/auth/send-otp',
    );
  }

  static Uri verifyOtp() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/auth/verify-otp',
    );
  }
}

class LocationApiEndpoints {
  const LocationApiEndpoints._();

  static Uri checkPincode() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/location/check-pincode',
    );
  }
}

class HomeApiEndpoints {
  const HomeApiEndpoints._();

  static Uri home({required String pincode}) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/home',
    ).replace(queryParameters: {'pincode': pincode.trim()});
  }

  static Uri sections({
    required String pincode,
    double? latitude,
    double? longitude,
  }) {
    final query = <String, String>{'pincode': pincode.trim()};
    if (latitude != null) {
      query['lat'] = latitude.toStringAsFixed(4);
    }
    if (longitude != null) {
      query['lng'] = longitude.toStringAsFixed(4);
    }

    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/home/sections',
    ).replace(queryParameters: query);
  }

  static Uri search({required String query, required String pincode}) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/home/search',
    ).replace(queryParameters: {'q': query.trim(), 'pincode': pincode.trim()});
  }
}

class CategoryApiEndpoints {
  const CategoryApiEndpoints._();

  static Uri list() {
    return Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiV1}/categories');
  }

  static Uri details(int id) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/categories/$id',
    );
  }

  static Uri tree() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/categories/tree',
    );
  }

  static Uri products(
    int categoryId, {
    int? subCategoryId,
    String? sort,
    int? pageNumber,
    int? pageSize,
  }) {
    final query = <String, String>{};
    if (subCategoryId != null) {
      query['subCategoryId'] = '$subCategoryId';
    }
    if (sort != null && sort.trim().isNotEmpty) {
      query['sort'] = sort.trim();
    }
    if (pageNumber != null) {
      query['pageNumber'] = '$pageNumber';
    }
    if (pageSize != null) {
      query['pageSize'] = '$pageSize';
    }

    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/categories/$categoryId/products',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }
}

class ProductApiEndpoints {
  const ProductApiEndpoints._();

  static Uri list({
    int? categoryId,
    String? search,
    bool? inStockOnly,
    bool? featuredOnly,
    String? sortBy,
    int? pageNumber,
    int? pageSize,
  }) {
    final query = <String, String>{};
    if (categoryId != null) {
      query['CategoryId'] = '$categoryId';
    }
    if (search != null && search.trim().isNotEmpty) {
      query['Search'] = search.trim();
    }
    if (inStockOnly != null) {
      query['InStockOnly'] = '$inStockOnly';
    }
    if (featuredOnly != null) {
      query['FeaturedOnly'] = '$featuredOnly';
    }
    if (sortBy != null && sortBy.trim().isNotEmpty) {
      query['SortBy'] = sortBy.trim();
    }
    if (pageNumber != null) {
      query['PageNumber'] = '$pageNumber';
    }
    if (pageSize != null) {
      query['PageSize'] = '$pageSize';
    }

    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/products',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Uri details(int id) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/products/$id',
    );
  }

  static Uri checkPincode(String pincode) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/products/check-pincode/$pincode',
    );
  }
}

class CartApiEndpoints {
  const CartApiEndpoints._();

  static Uri cart({String? pincode}) {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiV1}/cart');
    if (pincode == null || pincode.trim().isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {'pincode': pincode.trim()});
  }
}

class OrdersApiEndpoints {
  const OrdersApiEndpoints._();

  static Uri list({int pageNumber = 1, int pageSize = 10}) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/orders',
    ).replace(
      queryParameters: {'pageNumber': '$pageNumber', 'pageSize': '$pageSize'},
    );
  }

  static Uri create() {
    return Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiV1}/orders');
  }

  static Uri details(String orderNumber) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/orders/$orderNumber',
    );
  }

  static Uri cancel(String orderNumber) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/orders/$orderNumber/cancel',
    );
  }
}

class ProfileApiEndpoints {
  const ProfileApiEndpoints._();

  static Uri profile() {
    return Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiV1}/profile');
  }

  static Uri addresses() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/profile/addresses',
    );
  }

  static Uri deleteAddress(int id) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/profile/addresses/$id',
    );
  }
}

class UploadApiEndpoints {
  const UploadApiEndpoints._();

  static Uri uploadImage() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/upload/image',
    );
  }
}

class WebhookApiEndpoints {
  const WebhookApiEndpoints._();

  static Uri razorpay() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/webhooks/razorpay',
    );
  }
}

class ApiHeaders {
  const ApiHeaders._();

  static const String contentType = 'Content-Type';
  static const String acceptLanguage = 'Accept-Language';
  static const String authorization = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
  static const String applicationJson = 'application/json';
}
