import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    this.selectedLocation,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final String? selectedLocation;

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
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
      _log('Sending OTP request to ${AuthApiEndpoints.sendOtp()}');
      final response = await http
          .post(
            AuthApiEndpoints.sendOtp(),
            headers: {
              ApiHeaders.contentType: ApiHeaders.applicationJson,
              ApiHeaders.acceptLanguage: _screenLanguage.code,
            },
            body: jsonEncode({'mobile': phone}),
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
              deliveryLocation: widget.selectedLocation,
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
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: TextButton(
                      onPressed: () {
                        final nextLanguage = _screenLanguage == AppLanguage.en
                            ? AppLanguage.te
                            : AppLanguage.en;
                        _log(
                          'Language toggled from ${_screenLanguage.code} to ${nextLanguage.code}.',
                        );
                        widget.onLanguageChanged(nextLanguage);
                        setState(() {
                          _screenLanguage = nextLanguage;
                        });
                      },
                      child: Text(
                        _screenLanguage == AppLanguage.en ? 'తెలుగు' : 'EN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
