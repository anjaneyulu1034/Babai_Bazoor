import 'dart:convert';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PostOtpLocationScreen extends StatefulWidget {
  const PostOtpLocationScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  State<PostOtpLocationScreen> createState() => _PostOtpLocationScreenState();
}

class _PostOtpLocationScreenState extends State<PostOtpLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isFetchingCurrentLocation = false;
  bool _hasResolvedLocation = false;
  String _resolvedLocation = '';
  _AddressTag _selectedTag = _AddressTag.home;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final t = AppLocalizations.tr;
    if (_isFetchingCurrentLocation) {
      return;
    }

    setState(() {
      _isFetchingCurrentLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(widget.language, 'location_service_disabled')),
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
            content: Text(t(widget.language, 'location_permission_denied')),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationTag =
          await _resolveAddressFromCoordinates(
            latitude: position.latitude,
            longitude: position.longitude,
          ) ??
          'Lat ${position.latitude.toStringAsFixed(4)}, Lng ${position.longitude.toStringAsFixed(4)}';
      if (!mounted) {
        return;
      }

      setState(() {
        _resolvedLocation = locationTag;
        _hasResolvedLocation = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(widget.language, 'location_fetch_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCurrentLocation = false;
        });
      }
    }
  }

  Future<String?> _resolveAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final uri = ApiConstants.googleGeocodeByLatLng(
      latitude: latitude,
      longitude: longitude,
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status']?.toString() ?? '';
    final results = body['results'] as List<dynamic>?;

    if (status != 'OK' || results == null || results.isEmpty) {
      return null;
    }

    final first = results.first as Map<String, dynamic>;
    final formatted = first['formatted_address']?.toString().trim();
    if (formatted == null || formatted.isEmpty) {
      return null;
    }
    return formatted;
  }

  void _continueWithTypedArea() {
    final area = _searchController.text.trim();
    if (area.isEmpty) {
      return;
    }

    setState(() {
      _resolvedLocation = area;
      _hasResolvedLocation = true;
    });
  }

  void _confirmAndContinue() {
    if (_resolvedLocation.isEmpty) {
      return;
    }

    final destinationLabel = '${_tagTitle(_selectedTag)}: $_resolvedLocation';

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          language: widget.language,
          currentLocation: destinationLabel,
        ),
      ),
      (route) => false,
    );
  }

  String _tagTitle(_AddressTag tag) {
    switch (tag) {
      case _AddressTag.home:
        return 'Home';
      case _AddressTag.work:
        return 'Work';
      case _AddressTag.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1DB15F),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 2,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xCC0A0A0A)),
                        ),
                      ),
                      SizedBox(width: 14),
                      Text('📍', style: TextStyle(fontSize: 28)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Where are',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'you?',
                    style: TextStyle(
                      color: Color(0xFFFFC126),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enable location for faster delivery',
                    style: TextStyle(
                      color: Color(0xFFE5FFF1),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 24, 28, 12 + bottomSafeInset),
                child: Column(
                  children: [
                    if (!_hasResolvedLocation)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F2EC),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Column(
                          children: [
                            Text('🗺️', style: TextStyle(fontSize: 42)),
                            SizedBox(height: 12),
                            Text(
                              'Auto-detect your address',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF091535),
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Allow location access for the fastest and most\naccurate delivery',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF8A93AB),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _LocationFoundCard(location: _resolvedLocation),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isFetchingCurrentLocation
                            ? null
                            : _useCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1FA652),
                          disabledBackgroundColor: const Color(0xFF1FA652),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0x331FA652),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _isFetchingCurrentLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _hasResolvedLocation
                                    ? '📍 Update Current Location'
                                    : '📍 Use My Current Location',
                              ),
                      ),
                    ),
                    if (!_hasResolvedLocation) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'or',
                        style: TextStyle(
                          color: Color(0xFF8A93AB),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _continueWithTypedArea(),
                        decoration: InputDecoration(
                          hintText: 'Search area / pincode',
                          hintStyle: const TextStyle(
                            color: Color(0xFF8C93A8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 8),
                            child: Text('🔍', style: TextStyle(fontSize: 18)),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFEFEFF5),
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E3EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1E3EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF1FA652),
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_hasResolvedLocation) ...[
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Save as:',
                          style: TextStyle(
                            color: Color(0xFF0E1735),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AddressTypeTile(
                        title: '🏠 Home',
                        selected: _selectedTag == _AddressTag.home,
                        onTap: () => setState(() {
                          _selectedTag = _AddressTag.home;
                        }),
                      ),
                      const SizedBox(height: 8),
                      _AddressTypeTile(
                        title: '🏢 Work',
                        selected: _selectedTag == _AddressTag.work,
                        onTap: () => setState(() {
                          _selectedTag = _AddressTag.work;
                        }),
                      ),
                      const SizedBox(height: 8),
                      _AddressTypeTile(
                        title: '📍 Other',
                        selected: _selectedTag == _AddressTag.other,
                        onTap: () => setState(() {
                          _selectedTag = _AddressTag.other;
                        }),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _confirmAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF44700),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Confirm & Continue →'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddressTag { home, work, other }

class _LocationFoundCard extends StatelessWidget {
  const _LocationFoundCard({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📍', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location found!',
                  style: TextStyle(
                    color: Color(0xFF0E1735),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(
                    color: Color(0xFF3F4A68),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                const Text(
                  '✓ Fast delivery available',
                  style: TextStyle(
                    color: Color(0xFF189B47),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressTypeTile extends StatelessWidget {
  const _AddressTypeTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEDEEF9) : const Color(0xFFF0F1F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1FA652)
                  : const Color(0xFFE2E4EC),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0E1735),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
