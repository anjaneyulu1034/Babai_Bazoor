import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  static const String _mapsApiKey = 'AIzaSyAT3wIjV73qVXPAlgkyifnns38GztnbNF4';

  final TextEditingController _phoneController = TextEditingController();
  late AppLanguage _screenLanguage;
  bool _isSendingOtp = false;

  void _log(String message) {
    debugPrint('[MobileLoginScreen] $message');
  }

  String _maskPhone(String phone) {
    if (phone.length < 4) {
      return phone;
    }
    final tail = phone.substring(phone.length - 4);
    return '******$tail';
  }

  @override
  void initState() {
    super.initState();
    _screenLanguage = widget.language;
  }

  @override
  void didUpdateWidget(covariant MobileLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _screenLanguage = widget.language;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<Map<String, String>?> _resolveCurrentLocation() async {
    final t = AppLocalizations.tr;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await _showErrorDialog(t(_screenLanguage, 'location_service_disabled'));
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        await _showErrorDialog(
          t(_screenLanguage, 'location_permission_denied'),
        );
      }
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_mapsApiKey',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      if (mounted) {
        await _showErrorDialog(t(_screenLanguage, 'location_fetch_failed'));
      }
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status']?.toString() ?? '';
    final results = body['results'] as List<dynamic>?;

    if (status != 'OK' || results == null || results.isEmpty) {
      if (mounted) {
        await _showErrorDialog(t(_screenLanguage, 'location_not_found'));
      }
      return null;
    }

    final first = results.first as Map<String, dynamic>;
    final formattedAddress = first['formatted_address']?.toString() ?? '';
    final components =
        first['address_components'] as List<dynamic>? ?? const [];

    String pincode = '';
    for (final item in components) {
      final map = item as Map<String, dynamic>;
      final types = (map['types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (types.contains('postal_code')) {
        pincode = map['long_name']?.toString() ?? '';
        break;
      }
    }

    if (pincode.trim().length != 6) {
      if (mounted) {
        await _showErrorDialog(t(_screenLanguage, 'location_not_found'));
      }
      return null;
    }

    return {'pincode': pincode.trim(), 'location': formattedAddress};
  }

  Future<bool> _checkPincode(String pincode) async {
    final t = AppLocalizations.tr;

    final response = await http
        .post(
          LocationApiEndpoints.checkPincode(),
          headers: {
            ApiHeaders.contentType: ApiHeaders.applicationJson,
            ApiHeaders.acceptLanguage: _screenLanguage.code,
          },
          body: jsonEncode({'pincode': pincode}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = t(_screenLanguage, 'location_not_serviceable');
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final apiMessage = body['message']?.toString();
        if (apiMessage != null && apiMessage.trim().isNotEmpty) {
          message = apiMessage.trim();
        }
      } catch (_) {}

      if (mounted) {
        await _showErrorDialog(message);
      }
      return false;
    }

    return true;
  }

  Future<void> _goToOtp() async {
    final t = AppLocalizations.tr;
    final phone = _phoneController.text.trim();
    _log(
      'Get OTP tapped. phone=${_maskPhone(phone)} lang=${_screenLanguage.code}',
    );

    if (phone.length != 10) {
      _log('Validation failed: mobile length is ${phone.length}.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(_screenLanguage, 'invalid_mobile'))),
      );
      return;
    }

    if (_isSendingOtp) {
      _log('Skipped request: OTP request already in progress.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSendingOtp = true;
    });

    try {
      _log('Resolving current location and pincode.');
      final locationData = await _resolveCurrentLocation();
      if (locationData == null) {
        _log('Aborted: unable to resolve current location/pincode.');
        return;
      }

      final pincode = locationData['pincode']!;
      final currentLocation = locationData['location'];

      _log('Checking pincode serviceability. pincode=$pincode');
      final serviceable = await _checkPincode(pincode);
      if (!serviceable) {
        _log('Aborted: pincode not serviceable.');
        return;
      }

      _log('Sending OTP request to ${AuthApiEndpoints.sendOtp()}');
      final response = await http
          .post(
            AuthApiEndpoints.sendOtp(),
            headers: {
              ApiHeaders.contentType: ApiHeaders.applicationJson,
              ApiHeaders.acceptLanguage: _screenLanguage.code,
            },
            body: jsonEncode({
              'mobile': phone,
              'pincode': pincode,
              'location': currentLocation,
            }),
          )
          .timeout(const Duration(seconds: 15));

      _log(
        'OTP response received. statusCode=${response.statusCode} body=${response.body}',
      );

      final apiResponse = SendOtpApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );

      if (apiResponse.isSuccess) {
        if (!mounted) {
          return;
        }

        final prefilledOtp = apiResponse.otpCode;
        if (prefilledOtp != null) {
          _log('Extracted DEV OTP from response: $prefilledOtp');
        } else {
          _log('No DEV OTP found in response payload.');
        }

        _log('OTP sent successfully. Navigating to OTP screen.');

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              language: _screenLanguage,
              phoneNumber: phone,
              prefilledOtp: prefilledOtp,
              deliveryLocation: currentLocation,
            ),
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      final message =
          apiResponse.message ?? t(_screenLanguage, 'send_otp_failed');
      _log('OTP send failed. message="$message"');
      await _showErrorDialog(message);
    } on TimeoutException {
      _log('Request failed: timeout.');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(_screenLanguage, 'request_timeout'));
    } on SocketException {
      _log('Request failed: socket/network error.');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(_screenLanguage, 'network_error'));
    } on http.ClientException {
      _log('Request failed: HTTP client exception.');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(_screenLanguage, 'network_error'));
    } catch (_) {
      _log('Request failed: unexpected exception.');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(_screenLanguage, 'unexpected_error'));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
      _log('OTP request cycle finished.');
    }
  }

  Future<void> _showErrorDialog(String message) {
    final t = AppLocalizations.tr;
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t(_screenLanguage, 'error_title')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t(_screenLanguage, 'ok')),
          ),
        ],
      ),
    );
  }

  void _continueAsGuest() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          language: _screenLanguage,
          currentLocation: 'Guest Mode',
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.tr;
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _isSendingOtp ? null : _continueAsGuest,
                    child: Text(
                      t(_screenLanguage, 'skip'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    t(AppLanguage.en, 'login_welcome_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  if (_screenLanguage == AppLanguage.te) ...[
                    const SizedBox(height: 4),
                    Text(
                      t(AppLanguage.te, 'login_welcome_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    22,
                    20,
                    20 + mq.padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(_screenLanguage, 'mobile_number'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF525252),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            height: 54,
                            width: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              '+91',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE4E4E4),
                                  width: 1.4,
                                ),
                              ),
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                enableSuggestions: false,
                                autocorrect: false,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 10,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '9XXXXXXXXX',
                                  hintStyle: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF101010),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: _isSendingOtp ? null : _goToOtp,
                          child: _isSendingOtp
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(t(_screenLanguage, 'sending_otp')),
                                  ],
                                )
                              : Text(t(_screenLanguage, 'get_otp')),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          t(_screenLanguage, 'no_password'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
