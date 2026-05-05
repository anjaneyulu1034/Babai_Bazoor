import 'dart:async';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:http/http.dart' as http;

class CategoryService {
  const CategoryService();

  Future<Map<String, String>> _headers(AppLanguage language) async {
    final headers = <String, String>{ApiHeaders.acceptLanguage: language.code};
    final token = await AuthSessionService.instance.getToken();
    if (token != null && token.trim().isNotEmpty) {
      headers[ApiHeaders.authorization] =
          '${ApiHeaders.bearerPrefix}${token.trim()}';
    }
    return headers;
  }

  Future<CategoriesListApiResponse> getCategories({
    required AppLanguage language,
  }) async {
    try {
      final response = await http
          .get(CategoryApiEndpoints.list(), headers: await _headers(language))
          .timeout(const Duration(seconds: 15));

      return CategoriesListApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const CategoriesListApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const CategoriesListApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const CategoriesListApiResponse(
        isSuccess: false,
        message: 'Unable to load categories.',
      );
    }
  }

  Future<CategoryDetailsApiResponse> getCategoryDetails({
    required AppLanguage language,
    required int id,
  }) async {
    try {
      final response = await http
          .get(
            CategoryApiEndpoints.details(id),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 15));

      return CategoryDetailsApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const CategoryDetailsApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const CategoryDetailsApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const CategoryDetailsApiResponse(
        isSuccess: false,
        message: 'Unable to load category details.',
      );
    }
  }
}
