import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:http/http.dart' as http;

class CartService {
  const CartService();

  Future<Map<String, String>> _headers(
    AppLanguage language, {
    bool json = false,
  }) async {
    final headers = <String, String>{ApiHeaders.acceptLanguage: language.code};
    if (json) {
      headers[ApiHeaders.contentType] = ApiHeaders.applicationJson;
    }

    final token = await AuthSessionService.instance.getToken();
    if (token != null && token.trim().isNotEmpty) {
      headers[ApiHeaders.authorization] =
          '${ApiHeaders.bearerPrefix}${token.trim()}';
    }
    return headers;
  }

  String _httpFailureMessage(int statusCode, String rawBody, String fallback) {
    final compact = rawBody.trim();
    if (compact.isEmpty) {
      return '$fallback (HTTP $statusCode)';
    }

    final sanitized = compact.replaceAll(RegExp(r'\s+'), ' ');
    final preview = sanitized.length > 180
        ? '${sanitized.substring(0, 180)}...'
        : sanitized;
    return '$fallback (HTTP $statusCode): $preview';
  }

  Future<CartApiResponse> getCart({
    required AppLanguage language,
    String? pincode,
  }) async {
    try {
      final response = await http
          .get(
            CartApiEndpoints.cart(pincode: pincode),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 15));

      final parsed = CartApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
      if (parsed.isSuccess ||
          (parsed.message ?? '').trim().isNotEmpty ||
          parsed.errors.isNotEmpty) {
        return parsed;
      }

      return CartApiResponse(
        isSuccess: false,
        message: _httpFailureMessage(
          response.statusCode,
          response.body,
          'Unable to load cart',
        ),
        data: parsed.data,
        errors: parsed.errors,
      );
    } on TimeoutException {
      return const CartApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const CartApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const CartApiResponse(
        isSuccess: false,
        message: 'Unable to load cart.',
      );
    }
  }

  Future<CartApiResponse> updateCart({
    required AppLanguage language,
    required CartUpdateRequest request,
    String? pincode,
  }) async {
    try {
      final response = await http
          .put(
            CartApiEndpoints.cart(pincode: pincode),
            headers: await _headers(language, json: true),
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      final parsed = CartApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
      if (parsed.isSuccess ||
          (parsed.message ?? '').trim().isNotEmpty ||
          parsed.errors.isNotEmpty) {
        return parsed;
      }

      return CartApiResponse(
        isSuccess: false,
        message: _httpFailureMessage(
          response.statusCode,
          response.body,
          'Unable to update cart',
        ),
        data: parsed.data,
        errors: parsed.errors,
      );
    } on TimeoutException {
      return const CartApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const CartApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const CartApiResponse(
        isSuccess: false,
        message: 'Unable to update cart.',
      );
    }
  }

  Future<StringDataApiResponse> clearCart({
    required AppLanguage language,
    String? pincode,
  }) async {
    try {
      final response = await http
          .delete(
            CartApiEndpoints.cart(pincode: pincode),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 15));

      final parsed = StringDataApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
      if (parsed.isSuccess ||
          (parsed.message ?? '').trim().isNotEmpty ||
          parsed.errors.isNotEmpty) {
        return parsed;
      }

      return StringDataApiResponse(
        isSuccess: false,
        message: _httpFailureMessage(
          response.statusCode,
          response.body,
          'Unable to clear cart',
        ),
        data: parsed.data,
        errors: parsed.errors,
      );
    } on TimeoutException {
      return const StringDataApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const StringDataApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const StringDataApiResponse(
        isSuccess: false,
        message: 'Unable to clear cart.',
      );
    }
  }
}
