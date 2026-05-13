import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:http/http.dart' as http;

class CategoryService {
  const CategoryService();

  List<HomeSubCategory> _parseSubCategories(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(HomeSubCategory.fromJson)
            .toList();
      }

      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map(HomeSubCategory.fromJson)
              .toList();
        }
      }
    } catch (_) {
      return const [];
    }

    return const [];
  }

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
    String? type,
  }) async {
    try {
      final response = await http
          .get(
            CategoryApiEndpoints.list(type: type, languageCode: language.code),
            headers: await _headers(language),
          )
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
    required String slug,
  }) async {
    try {
      final response = await http
          .get(
            CategoryApiEndpoints.detailsBySlug(slug),
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

  Future<List<HomeSubCategory>> getSubCategories({
    required AppLanguage language,
    required int categoryId,
  }) async {
    try {
      final response = await http
          .get(
            CategoryApiEndpoints.subCategories(
              categoryId,
              languageCode: language.code,
            ),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      return _parseSubCategories(response.body);
    } on TimeoutException {
      return const [];
    } on SocketException {
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
