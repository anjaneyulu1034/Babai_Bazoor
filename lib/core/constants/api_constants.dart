class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = 'http://204.168.159.160:8085';
  static const String api = '/api';
  static const String apiV1 = '/api/v1';
  static const String mapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyAT3wIjV73qVXPAlgkyifnns38GztnbNF4',
  );

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

  static void addLanguageQuery(
    Map<String, String> query,
    String? languageCode,
  ) {
    final code = languageCode?.trim().toLowerCase();
    if (code == null || code.isEmpty) {
      return;
    }
    query['lang'] = code;
  }

  static Uri googleGeocodeByLatLng({
    required double latitude,
    required double longitude,
  }) {
    return Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '$latitude,$longitude',
      'key': mapsApiKey,
    });
  }

  static Uri googleGeocodeByAddress({required String address}) {
    return Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'address': address,
      'key': mapsApiKey,
      'components': 'country:in',
    });
  }

  static Uri googlePlacesAutocomplete({required String input}) {
    return Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': input, 'key': mapsApiKey, 'components': 'country:in'},
    );
  }
}

class AuthApiEndpoints {
  const AuthApiEndpoints._();

  static Uri sendOtp() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/auth/send-otp',
    );
  }

  static Uri verifyOtp() {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/auth/verify-otp',
    );
  }

  static Uri google() {
    return Uri.parse('${ApiConstants.baseUrl}${ApiConstants.api}/auth/google');
  }

  static Uri me() {
    return Uri.parse('${ApiConstants.baseUrl}${ApiConstants.api}/auth/me');
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

  static Uri home({required String pincode, String? languageCode}) {
    final query = <String, String>{'pincode': pincode.trim()};
    ApiConstants.addLanguageQuery(query, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/dashboard',
    ).replace(queryParameters: query);
  }

  static Uri sections({
    required String pincode,
    String? languageCode,
    double? latitude,
    double? longitude,
  }) {
    final query = <String, String>{'pincode': pincode.trim()};
    ApiConstants.addLanguageQuery(query, languageCode);
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

  static Uri search({
    required String query,
    required String pincode,
    String? languageCode,
  }) {
    final params = <String, String>{
      'q': query.trim(),
      'pincode': pincode.trim(),
    };
    ApiConstants.addLanguageQuery(params, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/home/search',
    ).replace(queryParameters: params);
  }
}

class CategoryApiEndpoints {
  const CategoryApiEndpoints._();

  static Uri list({String? type, String? languageCode}) {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/categories',
    );
    final query = <String, String>{};
    final normalizedType = type?.trim();
    if (normalizedType != null && normalizedType.isNotEmpty) {
      query['type'] = normalizedType;
    }
    ApiConstants.addLanguageQuery(query, languageCode);
    return query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  static Uri detailsBySlug(String slug) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/categories/${slug.trim()}',
    );
  }

  static Uri byId(int id) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/categories/$id',
    );
  }

  static Uri subCategories(int categoryId, {String? languageCode}) {
    final query = <String, String>{};
    ApiConstants.addLanguageQuery(query, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/categories/$categoryId/sub-categories',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Uri subCategoryById(int id) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/categories/sub-categories/$id',
    );
  }

  static Uri tree({String? languageCode}) {
    final query = <String, String>{};
    ApiConstants.addLanguageQuery(query, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/categories/tree',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Uri products(
    int categoryId, {
    String? languageCode,
    int? subCategoryId,
    String? sort,
    int? pageNumber,
    int? pageSize,
  }) {
    final query = <String, String>{};
    if (subCategoryId != null) {
      query['subCategoryId'] = '$subCategoryId';
    }
    if (pageNumber != null) {
      query['page'] = '$pageNumber';
    }
    if (pageSize != null) {
      query['pageSize'] = '$pageSize';
    }
    ApiConstants.addLanguageQuery(query, languageCode);

    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.apiV1}/categories/$categoryId/products',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }
}

class ProductApiEndpoints {
  const ProductApiEndpoints._();

  static Uri list({
    String? languageCode,
    int? categoryId,
    int? subCategoryId,
    String? search,
    bool? inStockOnly,
    bool? featured,
    String? sortBy,
    int? pageNumber,
    int? pageSize,
  }) {
    final query = <String, String>{};
    if (categoryId != null) {
      query['categoryId'] = '$categoryId';
    }
    if (subCategoryId != null) {
      query['subCategoryId'] = '$subCategoryId';
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (inStockOnly != null) {
      query['inStockOnly'] = '$inStockOnly';
    }
    if (featured != null) {
      query['featured'] = '$featured';
    }
    if (pageNumber != null) {
      query['page'] = '$pageNumber';
    }
    if (pageSize != null) {
      query['pageSize'] = '$pageSize';
    }
    ApiConstants.addLanguageQuery(query, languageCode);

    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/products',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Uri details(int id, {String? languageCode}) {
    final query = <String, String>{};
    ApiConstants.addLanguageQuery(query, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/products/$id',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Uri checkPincode(String pincode) {
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/products/check-pincode/$pincode',
    );
  }
}

class CartApiEndpoints {
  const CartApiEndpoints._();

  static Uri cart({String? pincode, String? languageCode}) {
    final query = <String, String>{};
    final normalizedPincode = pincode?.trim();
    if (normalizedPincode != null && normalizedPincode.isNotEmpty) {
      query['pincode'] = normalizedPincode;
    }
    ApiConstants.addLanguageQuery(query, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/cart',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Uri update({String? pincode, String? languageCode}) {
    final query = <String, String>{};
    final normalizedPincode = pincode?.trim();
    if (normalizedPincode != null && normalizedPincode.isNotEmpty) {
      query['pincode'] = normalizedPincode;
    }
    ApiConstants.addLanguageQuery(query, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/cart/update',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static Uri clear({String? pincode, String? languageCode}) {
    final query = <String, String>{};
    final normalizedPincode = pincode?.trim();
    if (normalizedPincode != null && normalizedPincode.isNotEmpty) {
      query['pincode'] = normalizedPincode;
    }
    ApiConstants.addLanguageQuery(query, languageCode);
    return Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.api}/cart/clear',
    ).replace(queryParameters: query.isEmpty ? null : query);
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
