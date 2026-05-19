import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:http/http.dart' as http;

class HomeService {
  const HomeService();

  Future<Map<String, String>> _headers(AppLanguage language) async {
    final headers = <String, String>{
      ApiHeaders.contentType: ApiHeaders.applicationJson,
      ApiHeaders.acceptLanguage: language.code,
    };
    final token = await AuthSessionService.instance.getToken();
    if (token != null && token.trim().isNotEmpty) {
      headers[ApiHeaders.authorization] =
          '${ApiHeaders.bearerPrefix}${token.trim()}';
    }
    return headers;
  }

  Future<HomeApiResponse> getHome({
    required AppLanguage language,
    required String pincode,
  }) async {
    try {
      final response = await http
          .get(
            HomeApiEndpoints.home(
              pincode: pincode,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return HomeApiResponse.fromHttp(response.statusCode, response.body);
    } on TimeoutException {
      return const HomeApiResponse();
    } on SocketException {
      return const HomeApiResponse();
    } catch (_) {
      return const HomeApiResponse();
    }
  }

  Future<OffersListApiResponse> getOffers({
    required AppLanguage language,
  }) async {
    try {
      final response = await http
          .get(
            OfferApiEndpoints.list(languageCode: language.code),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return OffersListApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const OffersListApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const OffersListApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const OffersListApiResponse(
        isSuccess: false,
        message: 'Unable to load offers.',
      );
    }
  }

  Future<PromoCodesListApiResponse> getPromoCodes({
    required AppLanguage language,
    String? applicableOn,
  }) async {
    try {
      final response = await http
          .get(
            PromoApiEndpoints.list(
              applicableOn: applicableOn,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return PromoCodesListApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const PromoCodesListApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const PromoCodesListApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const PromoCodesListApiResponse(
        isSuccess: false,
        message: 'Unable to load promo codes.',
      );
    }
  }

  Future<ServicesListApiResponse> getServices({
    required AppLanguage language,
    int? pageNumber,
    int? pageSize,
  }) async {
    try {
      final response = await http
          .get(
            ServicesApiEndpoints.list(
              pageNumber: pageNumber,
              pageSize: pageSize,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return ServicesListApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const ServicesListApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const ServicesListApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const ServicesListApiResponse(
        isSuccess: false,
        message: 'Unable to load services.',
      );
    }
  }

  Future<ServiceSummary?> getServiceDetails({
    required AppLanguage language,
    required int serviceId,
  }) async {
    try {
      final response = await http
          .get(
            ServicesApiEndpoints.details(
              serviceId,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final data = payload['data'];
        if (data is Map<String, dynamic>) {
          return ServiceSummary.fromJson(data);
        }
        return ServiceSummary.fromJson(payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ServiceSlotsApiResponse> getServiceSlots({
    required AppLanguage language,
    required int serviceId,
    required String slotDate,
  }) async {
    try {
      final byServiceResponse = await http
          .get(
            ServicesApiEndpoints.slotsByService(
              serviceId,
              slotDate: slotDate,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      final parsedByService = ServiceSlotsApiResponse.fromHttp(
        byServiceResponse.statusCode,
        byServiceResponse.body,
      );
      if (parsedByService.isSuccess && parsedByService.data.isNotEmpty) {
        return parsedByService;
      }

      final genericResponse = await http
          .get(
            ServicesApiEndpoints.slots(
              serviceId: serviceId,
              slotDate: slotDate,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return ServiceSlotsApiResponse.fromHttp(
        genericResponse.statusCode,
        genericResponse.body,
      );
    } on TimeoutException {
      return const ServiceSlotsApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const ServiceSlotsApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const ServiceSlotsApiResponse(
        isSuccess: false,
        message: 'Unable to load slots.',
      );
    }
  }

  Future<ServiceProfessionalsApiResponse> getServiceProfessionals({
    required AppLanguage language,
    required int serviceId,
  }) async {
    try {
      final response = await http
          .get(
            ServicesApiEndpoints.professionals(
              serviceId,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return ServiceProfessionalsApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const ServiceProfessionalsApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const ServiceProfessionalsApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const ServiceProfessionalsApiResponse(
        isSuccess: false,
        message: 'Unable to load service professionals.',
      );
    }
  }

  Future<ServiceBookingsListApiResponse> getServiceBookings({
    required AppLanguage language,
    String? status,
    int? pageNumber,
  }) async {
    try {
      final response = await http
          .get(
            ServicesApiEndpoints.bookingsList(
              status: status,
              pageNumber: pageNumber,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return ServiceBookingsListApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const ServiceBookingsListApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const ServiceBookingsListApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const ServiceBookingsListApiResponse(
        isSuccess: false,
        message: 'Unable to load bookings.',
      );
    }
  }

  Future<ServiceBookingApiResponse> bookService({
    required AppLanguage language,
    required int serviceId,
    required int addressId,
    required String slotDate,
    required String slotTime,
    required int slotId,
    required int servicePersonId,
    required String paymentMethod,
  }) async {
    try {
      final response = await http
          .post(
            ServicesApiEndpoints.createBooking(),
            headers: await _headers(language),
            body: jsonEncode({
              'serviceId': serviceId,
              'addressId': addressId,
              'slotDate': slotDate,
              'slotTime': slotTime,
              'slotId': slotId,
              'servicePersonId': servicePersonId,
              'paymentMethod': paymentMethod,
            }),
          )
          .timeout(const Duration(seconds: 20));

      return ServiceBookingApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const ServiceBookingApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const ServiceBookingApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const ServiceBookingApiResponse(
        isSuccess: false,
        message: 'Unable to create booking.',
      );
    }
  }

  Future<HomeSectionsApiResponse> getHomeSections({
    required AppLanguage language,
    required String pincode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await http
          .get(
            HomeApiEndpoints.sections(
              pincode: pincode,
              languageCode: language.code,
              latitude: latitude,
              longitude: longitude,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return HomeSectionsApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const HomeSectionsApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const HomeSectionsApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const HomeSectionsApiResponse(
        isSuccess: false,
        message: 'Unable to load home sections.',
      );
    }
  }

  Future<HomeSearchApiResponse> search({
    required AppLanguage language,
    required String query,
    required String pincode,
  }) async {
    try {
      final response = await http
          .get(
            HomeApiEndpoints.search(
              query: query,
              pincode: pincode,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return HomeSearchApiResponse.fromHttp(response.statusCode, response.body);
    } on TimeoutException {
      return const HomeSearchApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const HomeSearchApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const HomeSearchApiResponse(
        isSuccess: false,
        message: 'Unable to search products.',
      );
    }
  }

  Future<ProductsListApiResponse> getProducts({
    required AppLanguage language,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await http
          .get(
            ProductApiEndpoints.list(
              languageCode: language.code,
              pageNumber: pageNumber,
              pageSize: pageSize,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return ProductsListApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const ProductsListApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const ProductsListApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const ProductsListApiResponse(
        isSuccess: false,
        message: 'Unable to load products.',
      );
    }
  }

  Future<CategoryProductsApiResponse> getCategoryProducts({
    required AppLanguage language,
    required int categoryId,
    int? subCategoryId,
    String? sort,
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await http
          .get(
            CategoryApiEndpoints.products(
              categoryId,
              languageCode: language.code,
              subCategoryId: subCategoryId,
              sort: sort,
              pageNumber: pageNumber,
              pageSize: pageSize,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      final parsed = CategoryProductsApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
      return parsed;
    } on TimeoutException {
      return const CategoryProductsApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const CategoryProductsApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const CategoryProductsApiResponse(
        isSuccess: false,
        message: 'Unable to load category products.',
      );
    }
  }

  Future<CategoriesTreeApiResponse> getCategoryTree({
    required AppLanguage language,
  }) async {
    try {
      final response = await http
          .get(
            CategoryApiEndpoints.tree(languageCode: language.code),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return CategoriesTreeApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const CategoriesTreeApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const CategoriesTreeApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const CategoriesTreeApiResponse(
        isSuccess: false,
        message: 'Unable to load category tree.',
      );
    }
  }
}
