import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/auth_session_service.dart';
import 'package:babai_bazor_app/features/onboarding/presentation/screens/post_otp_location_screen.dart';
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
  static const int _otpLength = 4;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  Timer? _timer;
  int _remainingSeconds = 27;
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
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
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
      _remainingSeconds = 30;
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
    for (var i = 0; i < _controllers.length && i < otp.length; i++) {
      _controllers[i].text = otp[i];
    }
    _focusNodes.last.requestFocus();
  }

  String? _normalizeOtp(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < _otpLength) {
      return null;
    }
    return digits.substring(0, _otpLength);
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

    if (otp.length != _otpLength) {
      _log('Validation failed: OTP length is ${otp.length}.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 4-digit OTP.')),
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
            body: jsonEncode({
              'phone': widget.phoneNumber,
              'otp': otp,
              'name': '',
            }),
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
        _log(
          'OTP verification successful. Navigating to post-OTP location screen.',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PostOtpLocationScreen(language: widget.language),
          ),
          (route) => false,
        );
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

  String _timeLabel() {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  bool get _canVerify => _otp.length == _otpLength && !_isVerifyingOtp;

  @override
  Widget build(BuildContext context) {
    final inputWidth =
        ((MediaQuery.of(context).size.width - 68 - ((_otpLength - 1) * 10)) /
                _otpLength)
            .clamp(44.0, 52.0)
            .toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 64, 28, 34),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4D2233), Color(0xFFEC3A03)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(52),
                  bottomRight: Radius.circular(52),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 2,
                        height: 58,
                        color: const Color(0xCC0D0D0D),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 38,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C65CB),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.dialpad_rounded,
                          size: 22,
                          color: Color(0xFFFFC232),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Verify your',
                    style: TextStyle(
                      color: Color(0xFFF7F3EF),
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'number',
                    style: TextStyle(
                      color: Color(0xFFFFBE1A),
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'OTP sent to +91 ${widget.phoneNumber}',
                    style: const TextStyle(
                      color: Color(0xFFD7B6AE),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 36, 34, 22),
              child: Column(
                children: [
                  Text.rich(
                    const TextSpan(
                      text: 'Enter 4-digit OTP\n',
                      style: TextStyle(
                        color: Color(0xFF2E3D64),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        TextSpan(
                          text: 'Type the code sent to your mobile',
                          style: TextStyle(
                            color: Color(0xFF7F8BA9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_otpLength, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == _otpLength - 1 ? 0 : 10,
                        ),
                        child: SizedBox(
                          width: inputWidth,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF2A3558),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 1,
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFFF2F2F8),
                              contentPadding: const EdgeInsets.only(bottom: 2),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD5D5E1),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFEC3A03),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {});
                              if (value.isNotEmpty && index < _otpLength - 1) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    width: double.infinity,
                    height: 68,
                    child: ElevatedButton(
                      onPressed: _canVerify ? _verifyOtp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC3A03),
                        disabledBackgroundColor: const Color(0xFFD7D7E1),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF7E88A5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(
                        _isVerifyingOtp
                            ? 'Verifying...'
                            : 'Verify and Continue',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _remainingSeconds == 0 ? _resendOtp : null,
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7E88A5),
                        ),
                        children: [
                          const TextSpan(text: 'Resend in '),
                          TextSpan(
                            text: _timeLabel(),
                            style: TextStyle(
                              color: _remainingSeconds == 0
                                  ? const Color(0xFFEC3A03)
                                  : const Color(0xFFEC3A03),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
