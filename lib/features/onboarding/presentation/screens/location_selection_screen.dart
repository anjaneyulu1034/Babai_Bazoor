import 'dart:async';
import 'dart:convert';

import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/widgets/bb_primary_button.dart';
import 'package:babai_bazor_app/features/auth/presentation/screens/mobile_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({
    super.key,
    required this.language,
    required this.onLanguageChanged,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  static const String _mapsApiKey = 'AIzaSyAT3wIjV73qVXPAlgkyifnns38GztnbNF4';

  final TextEditingController _areaController = TextEditingController();
  late AppLanguage _screenLanguage;
  bool _isFetching = false;
  bool _isLoadingSuggestions = false;
  List<String> _suggestions = const [];
  Timer? _debounce;
  int _activeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _screenLanguage = widget.language;
    _areaController.addListener(_onAreaInputChanged);
  }

  @override
  void didUpdateWidget(covariant LocationSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _screenLanguage = widget.language;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _areaController.removeListener(_onAreaInputChanged);
    _areaController.dispose();
    super.dispose();
  }

  void _onAreaInputChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = _areaController.text.trim();
      if (query.length < 4) {
        if (_suggestions.isNotEmpty || _isLoadingSuggestions) {
          setState(() {
            _isLoadingSuggestions = false;
            _suggestions = const [];
          });
        }
        return;
      }
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final int requestId = ++_activeRequestId;
    if (mounted) {
      setState(() {
        _isLoadingSuggestions = true;
      });
    }

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {'input': query, 'key': _mapsApiKey, 'components': 'country:in'},
      );

      final response = await http.get(uri);
      if (response.statusCode != 200 ||
          requestId != _activeRequestId ||
          !mounted) {
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status']?.toString() ?? '';
      final predictions = body['predictions'] as List<dynamic>? ?? const [];

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        setState(() {
          _suggestions = const [];
        });
        return;
      }

      final items = predictions
          .map(
            (e) => (e as Map<String, dynamic>)['description']?.toString() ?? '',
          )
          .where((e) => e.isNotEmpty)
          .take(5)
          .toList();

      setState(() {
        _suggestions = items;
      });
    } catch (_) {
      if (!mounted || requestId != _activeRequestId) {
        return;
      }
      setState(() {
        _suggestions = const [];
      });
    } finally {
      if (mounted && requestId == _activeRequestId) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _selectSuggestion(String value) {
    _areaController
      ..text = value
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: value.length),
      );
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
    });
  }

  Future<void> _autoFetchLocation() async {
    final t = AppLocalizations.tr;
    setState(() {
      _isFetching = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(_screenLanguage, 'location_service_disabled')),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(_screenLanguage, 'location_permission_denied')),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_mapsApiKey',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(_screenLanguage, 'location_fetch_failed'))),
        );
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status']?.toString() ?? '';
      final results = body['results'] as List<dynamic>?;

      if (status != 'OK' || results == null || results.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(_screenLanguage, 'location_not_found'))),
        );
        return;
      }

      final formattedAddress =
          (results.first as Map<String, dynamic>)['formatted_address']
              ?.toString() ??
          '';

      if (formattedAddress.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(_screenLanguage, 'location_not_found'))),
        );
        return;
      }

      _areaController.text = formattedAddress;
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(_screenLanguage, 'location_fetch_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  void _continue() {
    final t = AppLocalizations.tr;
    final area = _areaController.text.trim();
    if (area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(_screenLanguage, 'enter_delivery_area'))),
      );
      return;
    }

    widget.onLanguageChanged(_screenLanguage);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MobileLoginScreen(
          language: _screenLanguage,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.tr;
    final inputLength = _areaController.text.trim().length;
    final shouldShowMinCharsHint = inputLength > 0 && inputLength < 4;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3E8), Color(0xFFF6F9FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    Expanded(
                      child: Text(
                        t(_screenLanguage, 'select_location'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.deepBlue,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: TextButton(
                        onPressed: () {
                          final nextLanguage = _screenLanguage == AppLanguage.en
                              ? AppLanguage.te
                              : AppLanguage.en;
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x140D47A1),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0x1FFF6F00),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.pin_drop_rounded,
                                color: AppColors.primaryOrange,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t(_screenLanguage, 'delivery_area_label'),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t(_screenLanguage, 'delivery_area_hint'),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE7EAF0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _areaController,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: t(
                                  _screenLanguage,
                                  'delivery_area_placeholder',
                                ),
                                prefixIcon: const Icon(
                                  Icons.home_work_rounded,
                                  color: AppColors.deepBlue,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF9FBFF),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  14,
                                  12,
                                  14,
                                ),
                              ),
                            ),
                            if (shouldShowMinCharsHint) ...[
                              const SizedBox(height: 8),
                              Text(
                                t(_screenLanguage, 'type_4_chars_hint'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (_isLoadingSuggestions) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(minHeight: 2),
                            ],
                            if (_suggestions.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                t(_screenLanguage, 'suggested_areas'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.deepBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._suggestions.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () => _selectSuggestion(item),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        10,
                                        10,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4F8FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFDCE7FF),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 18,
                                            color: AppColors.deepBlue,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isFetching ? null : _autoFetchLocation,
                          icon: _isFetching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            t(_screenLanguage, 'auto_fetch_location'),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: AppColors.deepBlue),
                            foregroundColor: AppColors.deepBlue,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                color: Colors.transparent,
                child: BbPrimaryButton(
                  label: t(_screenLanguage, 'continue_to_login'),
                  onPressed: _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
