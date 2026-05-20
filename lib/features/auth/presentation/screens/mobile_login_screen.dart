import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/constants/app_assets.dart';
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
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

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
            body: jsonEncode({'phone': phone}),
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
    final canSendOtp =
        !_isSendingOtp && _phoneController.text.trim().length == 10;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: mq.size.height),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(34, 12 + mq.padding.top, 34, 42),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF7F2620),
                      Color(0xFFAA2F14),
                      Color(0xFFE63E00),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(52),
                    bottomRight: Radius.circular(52),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      AppAssets.logo,
                      width: 200,
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t(_screenLanguage, 'login_welcome_to'),
                      style: const TextStyle(
                        color: Color(0xFFF8EFE8),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      t(_screenLanguage, 'login_or_signup_continue'),
                      style: const TextStyle(
                        color: Color(0xFFD8BFB4),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  34,
                  28,
                  34,
                  24 + mq.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(_screenLanguage, 'enter_mobile_number'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0C1633),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t(_screenLanguage, 'login_otp_hint'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A93AB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E9EF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD9D9E2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 70,
                            width: 96,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Color(0xFFD9D9E2)),
                              ),
                            ),
                            child: const Text(
                              'IN +91',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D1330),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              enableSuggestions: false,
                              autocorrect: false,
                              onChanged: (_) => setState(() {}),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 10,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: Color(0xFF919AAF),
                              ),
                              decoration: const InputDecoration(
                                hintText: '98765 43210',
                                hintStyle: TextStyle(
                                  color: Color(0xFF919AAF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                ),
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSendOtp
                              ? const Color(0xFFEC3A03)
                              : const Color(0xFFD7D7E1),
                          foregroundColor: canSendOtp
                              ? Colors.white
                              : const Color(0xFF8A93AB),
                          minimumSize: const Size.fromHeight(68),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: canSendOtp ? _goToOtp : null,
                        child: _isSendingOtp
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
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
                    Row(
                      children: [
                        Text(
                          t(_screenLanguage, 'choose_language_inline'),
                          style: const TextStyle(
                            color: Color(0xFF8A93AB),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD8D8E2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AppLanguage>(
                              value: _screenLanguage,
                              isDense: true,
                              style: const TextStyle(
                                color: Color(0xFF0D1330),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              items: [
                                DropdownMenuItem<AppLanguage>(
                                  value: AppLanguage.en,
                                  child: Text(t(_screenLanguage, 'english')),
                                ),
                                DropdownMenuItem<AppLanguage>(
                                  value: AppLanguage.te,
                                  child: Text(t(_screenLanguage, 'telugu')),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null || value == _screenLanguage) {
                                  return;
                                }
                                setState(() {
                                  _screenLanguage = value;
                                });
                                widget.onLanguageChanged(value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
