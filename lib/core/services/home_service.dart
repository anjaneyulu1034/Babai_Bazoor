import 'dart:async';
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
            HomeApiEndpoints.home(pincode: pincode),
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
            HomeApiEndpoints.search(query: query, pincode: pincode),
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
              subCategoryId: subCategoryId,
              sort: sort,
              pageNumber: pageNumber,
              pageSize: pageSize,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 20));

      return CategoryProductsApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
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
          .get(CategoryApiEndpoints.tree(), headers: await _headers(language))
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
