import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/models/order_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:http/http.dart' as http;

class OrdersService {
  const OrdersService();

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

  Future<OrdersListApiResponse> getOrders({
    required AppLanguage language,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await http
          .get(
            OrdersApiEndpoints.list(pageNumber: pageNumber, pageSize: pageSize),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 15));

      return OrdersListApiResponse.fromHttp(response.statusCode, response.body);
    } on TimeoutException {
      return const OrdersListApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const OrdersListApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const OrdersListApiResponse(
        isSuccess: false,
        message: 'Unable to load orders.',
      );
    }
  }

  Future<OrderApiResponse> createOrder({
    required AppLanguage language,
    required CreateOrderRequest request,
  }) async {
    try {
      final response = await http
          .post(
            OrdersApiEndpoints.create(),
            headers: await _headers(language, json: true),
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      return OrderApiResponse.fromHttp(response.statusCode, response.body);
    } on TimeoutException {
      return const OrderApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const OrderApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const OrderApiResponse(
        isSuccess: false,
        message: 'Unable to create order.',
      );
    }
  }

  Future<OrderApiResponse> getOrderDetails({
    required AppLanguage language,
    required String orderNumber,
  }) async {
    try {
      final response = await http
          .get(
            OrdersApiEndpoints.details(orderNumber),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 15));

      return OrderApiResponse.fromHttp(response.statusCode, response.body);
    } on TimeoutException {
      return const OrderApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const OrderApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const OrderApiResponse(
        isSuccess: false,
        message: 'Unable to load order details.',
      );
    }
  }

  Future<StringDataApiResponse> cancelOrder({
    required AppLanguage language,
    required String orderNumber,
    required CancelOrderRequest request,
  }) async {
    try {
      final response = await http
          .post(
            OrdersApiEndpoints.cancel(orderNumber),
            headers: await _headers(language, json: true),
            body: jsonEncode(request.reason),
          )
          .timeout(const Duration(seconds: 15));

      return StringDataApiResponse.fromHttp(response.statusCode, response.body);
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
        message: 'Unable to cancel order.',
      );
    }
  }
}
