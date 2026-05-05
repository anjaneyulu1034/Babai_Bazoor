import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:babai_bazor_app/core/widgets/bb_primary_button.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.language,
    required this.phoneNumber,
    this.prefilledOtp,
    this.deliveryLocation,
  });

  final AppLanguage language;
  final String phoneNumber;
  final String? prefilledOtp;
  final String? deliveryLocation;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  Timer? _timer;
  int _remainingSeconds = 10 * 60;
  bool _isVerifyingOtp = false;

  void _log(String message) {
    debugPrint('[OtpVerificationScreen] $message');
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
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _startTimer();

    final prefilledOtp = _normalizeOtp(widget.prefilledOtp);
    if (prefilledOtp != null) {
      _applyPrefilledOtp(prefilledOtp);
      _log(
        'Prefilled OTP applied from previous response. Waiting for manual verify tap.',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
    });
  }

  void _resendOtp() {
    final t = AppLocalizations.tr;
    setState(() {
      _remainingSeconds = 10 * 60;
      for (final c in _controllers) {
        c.clear();
      }
    });
    _startTimer();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t(widget.language, 'resend_done'))));
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _applyPrefilledOtp(String otp) {
    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = otp[i];
    }
    _focusNodes.last.requestFocus();
  }

  String? _normalizeOtp(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final match = RegExp(r'\b(\d{6})\b').firstMatch(raw);
    return match?.group(1);
  }

  Future<void> _verifyOtp() async {
    final t = AppLocalizations.tr;
    final otp = _otp;
    _log(
      'Verify OTP tapped. phone=${_maskPhone(widget.phoneNumber)} otpLength=${otp.length} lang=${widget.language.code}',
    );

    if (_isVerifyingOtp) {
      _log('Skipped request: OTP verification already in progress.');
      return;
    }

    if (otp.length != 6) {
      _log('Validation failed: OTP length is ${otp.length}.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(widget.language, 'invalid_otp'))),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      _log('Sending verify OTP request to ${AuthApiEndpoints.verifyOtp()}');
      final response = await http
          .post(
            AuthApiEndpoints.verifyOtp(),
            headers: {
              ApiHeaders.contentType: ApiHeaders.applicationJson,
              ApiHeaders.acceptLanguage: widget.language.code,
            },
            body: jsonEncode({'mobile': widget.phoneNumber, 'otpCode': otp}),
          )
          .timeout(const Duration(seconds: 15));

      _log(
        'Verify OTP response received. statusCode=${response.statusCode} body=${response.body}',
      );

      final apiResponse = VerifyOtpApiResponse.fromHttp(
        response.statusCode,
        response.body,
      );

      if (apiResponse.isSuccess) {
        final token = apiResponse.accessToken;
        if (token != null && token.trim().isNotEmpty) {
          try {
            await AuthSessionService.instance.saveToken(token);
            _log('Access token saved from verify OTP response.');
          } catch (e, st) {
            _log('Token save failed but continuing login. error=$e stack=$st');
          }
        } else {
          _log('Verify OTP response success but no token found.');
        }

        if (!mounted) {
          return;
        }

        final successMessage =
            apiResponse.message ?? t(widget.language, 'otp_verified');
        _log('OTP verification successful. Navigating to home placeholder.');
        await _showSuccessDialog(successMessage);
        return;
      }

      if (!mounted) {
        return;
      }

      final message =
          apiResponse.message ?? t(widget.language, 'verify_otp_failed');
      _log('OTP verification failed. message="$message"');
      await _showErrorDialog(message);
    } on TimeoutException {
      _log('Verify OTP failed: timeout.');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(widget.language, 'request_timeout'));
    } on SocketException {
      _log('Verify OTP failed: socket/network error.');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(widget.language, 'network_error'));
    } on http.ClientException {
      _log('Verify OTP failed: HTTP client exception.');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(widget.language, 'network_error'));
    } catch (e, st) {
      _log('Verify OTP failed: unexpected exception. error=$e stack=$st');
      if (!mounted) {
        return;
      }
      await _showErrorDialog(t(widget.language, 'unexpected_error'));
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
      _log('Verify OTP request cycle finished.');
    }
  }

  Future<void> _showErrorDialog(String message) {
    final t = AppLocalizations.tr;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(t(widget.language, 'error_title')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t(widget.language, 'ok')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialog(String message) {
    final t = AppLocalizations.tr;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(t(widget.language, 'otp_verified')),
          content: Text(
            '$message\n\n${t(widget.language, 'otp_verified_for')} +91 ${widget.phoneNumber}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(
                      language: widget.language,
                      currentLocation: widget.deliveryLocation,
                    ),
                  ),
                  (route) => false,
                );
              },
              child: Text(t(widget.language, 'continue')),
            ),
          ],
        );
      },
    );
  }

  String _timeLabel() {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.tr;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: AppColors.primaryOrange,
              padding: const EdgeInsets.fromLTRB(20, 58, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    t(widget.language, 'verify_otp'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      '${t(widget.language, 'sent_to')} +91 ${widget.phoneNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6E7480),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        t(widget.language, 'change_number'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      const Color borderColor = Color(0xFF5BAA64);
                      const Color fillColor = Color(0xFFF2F9F3);
                      return SizedBox(
                        width: 44,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 1,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: fillColor,
                            contentPadding: const EdgeInsets.only(bottom: 2),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primaryOrange,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        '⏱ ${t(widget.language, 'expires_in')} ${_timeLabel()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6E7480),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _remainingSeconds == 0 ? _resendOtp : null,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          t(widget.language, 'resend_otp'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  BbPrimaryButton(
                    label: _isVerifyingOtp
                        ? t(widget.language, 'verifying_otp')
                        : t(widget.language, 'verify'),
                    onPressed: _verifyOtp,
                    backgroundColor: AppColors.softOrange,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      t(widget.language, 'ten_minutes'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
