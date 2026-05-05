import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/models/profile_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:http/http.dart' as http;

class ProfileService {
  const ProfileService();

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

  Future<UserProfileApiResponse> getProfile({
    required AppLanguage language,
  }) async {
    try {
      final response = await http
          .get(ProfileApiEndpoints.profile(), headers: await _headers(language))
          .timeout(const Duration(seconds: 15));

      return UserProfileApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const UserProfileApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const UserProfileApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const UserProfileApiResponse(
        isSuccess: false,
        message: 'Unable to load profile.',
      );
    }
  }

  Future<UserProfileApiResponse> updateProfile({
    required AppLanguage language,
    required UpdateProfileRequest request,
  }) async {
    try {
      final response = await http
          .put(
            ProfileApiEndpoints.profile(),
            headers: await _headers(language, json: true),
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      return UserProfileApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );
    } on TimeoutException {
      return const UserProfileApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const UserProfileApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const UserProfileApiResponse(
        isSuccess: false,
        message: 'Unable to update profile.',
      );
    }
  }

  Future<AddressesApiResponse> getAddresses({
    required AppLanguage language,
  }) async {
    try {
      final response = await http
          .get(
            ProfileApiEndpoints.addresses(),
            headers: await _headers(language),
          )
          .timeout(const Duration(seconds: 15));

      return AddressesApiResponse.fromHttp(response.statusCode, response.body);
    } on TimeoutException {
      return const AddressesApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const AddressesApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const AddressesApiResponse(
        isSuccess: false,
        message: 'Unable to load addresses.',
      );
    }
  }

  Future<AddressApiResponse> addAddress({
    required AppLanguage language,
    required AddAddressRequest request,
  }) async {
    try {
      final response = await http
          .post(
            ProfileApiEndpoints.addresses(),
            headers: await _headers(language, json: true),
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      return AddressApiResponse.fromHttp(response.statusCode, response.body);
    } on TimeoutException {
      return const AddressApiResponse(
        isSuccess: false,
        message: 'Request timed out. Try again.',
      );
    } on SocketException {
      return const AddressApiResponse(
        isSuccess: false,
        message: 'No internet connection.',
      );
    } catch (_) {
      return const AddressApiResponse(
        isSuccess: false,
        message: 'Unable to add address.',
      );
    }
  }

  Future<StringDataApiResponse> deleteAddress({
    required AppLanguage language,
    required int id,
  }) async {
    try {
      final response = await http
          .delete(
            ProfileApiEndpoints.deleteAddress(id),
            headers: await _headers(language),
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
        message: 'Unable to delete address.',
      );
    }
  }
}
