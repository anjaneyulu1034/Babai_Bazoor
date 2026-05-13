import 'dart:async';
import 'dart:convert';

import 'package:babai_bazor_app/core/constants/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SavedAddressResult {
  const SavedAddressResult({
    required this.label,
    required this.icon,
    required this.line1,
    required this.line2,
    required this.pincode,
  });

  final String label;
  final String icon;
  final String line1;
  final String line2;
  final String pincode;
}

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key, required this.current});

  final SavedAddressResult current;

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _line1Controller = TextEditingController();
  final TextEditingController _line2Controller = TextEditingController();

  final List<_AddressItem> _addresses = <_AddressItem>[];
  List<String> _suggestions = const <String>[];
  bool _isLoadingSuggestions = false;
  Timer? _debounce;
  int _requestId = 0;
  bool _showAddForm = false;
  _AddressKind _newKind = _AddressKind.home;

  @override
  void initState() {
    super.initState();

    _addresses
      ..add(
        _AddressItem(
          kind: _AddressKind.home,
          line1: 'Flat 4B, Sunrise Apartments',
          line2: 'Sector 21, Gurugram, HR 122016',
          isDefault: widget.current.label.toLowerCase() == 'home',
        ),
      )
      ..add(
        _AddressItem(
          kind: _AddressKind.work,
          line1: 'WeWork, Cyber City Tower',
          line2: 'DLF Phase 2, Gurugram, HR 122002',
          isDefault: widget.current.label.toLowerCase() == 'work',
        ),
      );

    if (!_addresses.any((item) => item.isDefault)) {
      _addresses.first.isDefault = true;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(value.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 3) {
      if (_suggestions.isNotEmpty || _isLoadingSuggestions) {
        setState(() {
          _isLoadingSuggestions = false;
          _suggestions = const <String>[];
        });
      }
      return;
    }

    final currentReq = ++_requestId;
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final uri = ApiConstants.googlePlacesAutocomplete(input: query);
      final response = await http.get(uri);
      if (currentReq != _requestId || !mounted) {
        return;
      }

      if (response.statusCode != 200) {
        setState(() {
          _isLoadingSuggestions = false;
          _suggestions = const <String>[];
        });
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status']?.toString() ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        setState(() {
          _isLoadingSuggestions = false;
          _suggestions = const <String>[];
        });
        return;
      }

      final predictions = body['predictions'] as List<dynamic>? ?? const [];
      final items = predictions
          .whereType<Map<String, dynamic>>()
          .map((map) => map['description']?.toString().trim() ?? '')
          .where((text) => text.isNotEmpty)
          .take(6)
          .toList();

      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = items;
      });
    } catch (_) {
      if (!mounted || currentReq != _requestId) {
        return;
      }
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = const <String>[];
      });
    }
  }

  Future<void> _pickSuggestion(String description) async {
    _searchController
      ..text = description
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: description.length),
      );

    setState(() {
      _suggestions = const <String>[];
    });

    try {
      final uri = ApiConstants.googleGeocodeByAddress(address: description);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status']?.toString() ?? '';
      final results = body['results'] as List<dynamic>?;
      if (status != 'OK' || results == null || results.isEmpty) {
        return;
      }

      final first = results.first as Map<String, dynamic>;
      final formatted = first['formatted_address']?.toString().trim() ?? '';
      if (formatted.isEmpty) {
        return;
      }

      final parts = formatted.split(',').map((e) => e.trim()).toList();
      if (parts.isNotEmpty) {
        _line1Controller.text = parts.first;
        _line2Controller.text = parts.skip(1).join(', ').trim();
      } else {
        _line1Controller.text = formatted;
      }
    } catch (_) {
      // Keep manual input mode if geocode fails.
    }
  }

  void _markDefault(int index) {
    setState(() {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i].isDefault = i == index;
      }
    });
  }

  void _deleteAddress(int index) {
    if (_addresses[index].isDefault) {
      return;
    }

    setState(() {
      _addresses.removeAt(index);
      if (!_addresses.any((item) => item.isDefault) && _addresses.isNotEmpty) {
        _addresses.first.isDefault = true;
      }
    });
  }

  void _startEditAddress(int index) {
    final item = _addresses[index];
    setState(() {
      _newKind = item.kind;
      _line1Controller.text = item.line1;
      _line2Controller.text = item.line2;
      _showAddForm = true;
    });

    _addresses[index] = item.copyWith(isDefault: false);
  }

  void _saveAddress() {
    final line1 = _line1Controller.text.trim();
    final line2 = _line2Controller.text.trim();
    if (line1.isEmpty || line2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter full address details')),
      );
      return;
    }

    setState(() {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i].isDefault = false;
      }
      _addresses.add(
        _AddressItem(
          kind: _newKind,
          line1: line1,
          line2: line2,
          isDefault: true,
        ),
      );
      _showAddForm = false;
      _line1Controller.clear();
      _line2Controller.clear();
      _newKind = _AddressKind.home;
    });
  }

  SavedAddressResult _currentDefault() {
    final item = _addresses.firstWhere(
      (entry) => entry.isDefault,
      orElse: () => _addresses.first,
    );

    final pincodeMatch = RegExp(r'(\d{6})').firstMatch(item.line2);
    return SavedAddressResult(
      label: item.kind.label,
      icon: item.kind.icon,
      line1: item.line1,
      line2: item.line2,
      pincode: pincodeMatch?.group(1) ?? '500001',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pop(_currentDefault()),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFE9EBF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            ),
          ),
        ),
        titleSpacing: 8,
        title: const Row(
          children: [
            Text('📍', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text(
              'Saved Addresses',
              style: TextStyle(
                color: Color(0xFF14192D),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
        children: [
          ...List.generate(_addresses.length, (index) {
            final item = _addresses[index];
            final isDefault = item.isDefault;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDefault
                      ? const Color(0xFFF44700)
                      : const Color(0xFFDEE3EE),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8EFEA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          item.kind.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.kind.label,
                                  style: const TextStyle(
                                    color: Color(0xFF14192D),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 26,
                                  ),
                                ),
                                const Spacer(),
                                if (isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEEE8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'DEFAULT',
                                      style: TextStyle(
                                        color: Color(0xFFF44700),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              item.line1,
                              style: const TextStyle(
                                color: Color(0xFF4B5470),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.line2,
                              style: const TextStyle(
                                color: Color(0xFF8D95AA),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _AddressActionButton(
                          text: '🖍 Edit',
                          onTap: () => _startEditAddress(index),
                        ),
                      ),
                      if (!isDefault) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AddressActionButton(
                            text: 'Set Default',
                            highlight: true,
                            onTap: () => _markDefault(index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DeleteButton(onTap: () => _deleteAddress(index)),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
          if (!_showAddForm)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _showAddForm = true;
                });
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF9B199),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '+ Add New Address',
                    style: TextStyle(
                      color: Color(0xFFF44700),
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                    ),
                  ),
                ),
              ),
            ),
          if (_showAddForm)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF9B199)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '+ New Address',
                    style: TextStyle(
                      color: Color(0xFF14192D),
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AddressInput(
                    controller: _searchController,
                    hint: 'Search address using Google Maps',
                    onChanged: _onSearchChanged,
                  ),
                  if (_isLoadingSuggestions)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE1E5EF)),
                      ),
                      child: Column(
                        children: _suggestions
                            .map(
                              (text) => ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Color(0xFF7D879E),
                                ),
                                title: Text(
                                  text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () => _pickSuggestion(text),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _AddressKind.values.map((kind) {
                      final selected = _newKind == kind;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _newKind = kind;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFF1EC)
                                : const Color(0xFFF2F4F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFF44700)
                                  : const Color(0xFFE1E5EF),
                            ),
                          ),
                          child: Text(
                            '${kind.icon} ${kind.label}',
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFFF44700)
                                  : const Color(0xFF4A4E5E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  _AddressInput(
                    controller: _line1Controller,
                    hint: 'Street address / Building name',
                  ),
                  const SizedBox(height: 10),
                  _AddressInput(
                    controller: _line2Controller,
                    hint: 'Area, City, Pincode',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveAddress,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: const Color(0xFFF44700),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Address',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showAddForm = false;
                              _line1Controller.clear();
                              _line2Controller.clear();
                              _newKind = _AddressKind.home;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: const Color(0xFFF2F4F9),
                            foregroundColor: const Color(0xFF4A4E5E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_currentDefault()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Use Selected Address',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AddressKind {
  home('Home', '🏠'),
  work('Work', '🏢'),
  parents('Parents', '👨‍👩‍👧'),
  other('Other', '📍');

  const _AddressKind(this.label, this.icon);

  final String label;
  final String icon;
}

class _AddressItem {
  _AddressItem({
    required this.kind,
    required this.line1,
    required this.line2,
    this.isDefault = false,
  });

  final _AddressKind kind;
  final String line1;
  final String line2;
  bool isDefault;

  _AddressItem copyWith({
    _AddressKind? kind,
    String? line1,
    String? line2,
    bool? isDefault,
  }) {
    return _AddressItem(
      kind: kind ?? this.kind,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class _AddressActionButton extends StatelessWidget {
  const _AddressActionButton({
    required this.text,
    required this.onTap,
    this.highlight = false,
  });

  final String text;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFFF1EC) : const Color(0xFFF2F4F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight
                ? const Color(0xFFF9B199)
                : const Color(0xFFE1E5EF),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: highlight
                ? const Color(0xFFF44700)
                : const Color(0xFF4A4E5E),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE1E5EF)),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Color(0xFF8B91A6),
          size: 20,
        ),
      ),
    );
  }
}

class _AddressInput extends StatelessWidget {
  const _AddressInput({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E5EF)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF9AA3B8),
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
