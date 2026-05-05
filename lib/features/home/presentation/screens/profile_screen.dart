import 'package:babai_bazor_app/core/constants/app_colors.dart';
import 'package:babai_bazor_app/core/localization/app_language_scope.dart';
import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/models/profile_models.dart';
import 'package:babai_bazor_app/core/services/profile_service.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = const ProfileService();
  late AppLanguage _activeLanguage;

  bool _isLoading = true;
  bool _isBusy = false;
  String? _inlineError;
  UserProfileModel? _profile;
  List<AddressModel> _addresses = const [];

  @override
  void initState() {
    super.initState();
    _activeLanguage = widget.language;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scopedLanguage = AppLanguageScope.watch(context);
    if (scopedLanguage != _activeLanguage) {
      _activeLanguage = scopedLanguage;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _inlineError = null;
    });

    final profileRes = await _profileService.getProfile(
      language: _activeLanguage,
    );
    final addressRes = await _profileService.getAddresses(
      language: _activeLanguage,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profileRes.data;
      _addresses = addressRes.data;
      _isLoading = false;
      if (!profileRes.isSuccess && !addressRes.isSuccess) {
        _inlineError = _bestMessage(profileRes.message, addressRes.message);
      }
    });
  }

  String _bestMessage(String? first, String? second) {
    if (first != null && first.trim().isNotEmpty) {
      return first.trim();
    }
    if (second != null && second.trim().isNotEmpty) {
      return second.trim();
    }
    return 'Request completed.';
  }

  String get _displayName {
    final name = _profile?.name?.trim();
    if (name == null || name.isEmpty) {
      return 'Guest';
    }
    return name;
  }

  String _profileInitials() {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'G';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  void _showMessage(String? message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message?.trim().isNotEmpty == true ? message! : 'Done'),
      ),
    );
  }

  Future<void> _showUpdateProfileDialog() async {
    final nameEnCtrl = TextEditingController(text: _profile?.name ?? '');
    final nameTeCtrl = TextEditingController(text: _profile?.name ?? '');
    final villageEnCtrl = TextEditingController(text: _profile?.village ?? '');
    final villageTeCtrl = TextEditingController(text: _profile?.village ?? '');
    final pincodeCtrl = TextEditingController(text: _profile?.pincode ?? '');
    final districtCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameEnCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (English)',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameTeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (Telugu)',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name (Telugu) is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: villageEnCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Village (English)',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Village is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: villageTeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Village (Telugu)',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Village (Telugu) is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: districtCtrl,
                        decoration: const InputDecoration(
                          labelText: 'District',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'District is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: pincodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Pincode'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length != 6 || int.tryParse(text) == null) {
                            return 'Enter a valid 6-digit pincode';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    final response = await _profileService.updateProfile(
      language: _activeLanguage,
      request: UpdateProfileRequest(
        nameEn: nameEnCtrl.text.trim(),
        nameTe: nameTeCtrl.text.trim(),
        villageEn: villageEnCtrl.text.trim(),
        villageTe: villageTeCtrl.text.trim(),
        pincode: pincodeCtrl.text.trim(),
        district: districtCtrl.text.trim(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
      if (response.isSuccess && response.data != null) {
        _profile = response.data;
      }
    });

    _showMessage(response.message ?? 'Profile updated successfully');
  }

  Future<void> _showAddAddressDialog() async {
    final labelEn = TextEditingController();
    final labelTe = TextEditingController();
    final lineEn = TextEditingController();
    final lineTe = TextEditingController();
    final villageEn = TextEditingController();
    final villageTe = TextEditingController();
    final mandalEn = TextEditingController();
    final mandalTe = TextEditingController();
    final districtEn = TextEditingController();
    final districtTe = TextEditingController();
    final pincode = TextEditingController();
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isDefault = true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Add Address'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: labelEn,
                            decoration: const InputDecoration(
                              labelText: 'Label (English)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Label is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: labelTe,
                            decoration: const InputDecoration(
                              labelText: 'Label (Telugu)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Label (Telugu) is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: lineEn,
                            decoration: const InputDecoration(
                              labelText: 'Address Line (English)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Address line is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: lineTe,
                            decoration: const InputDecoration(
                              labelText: 'Address Line (Telugu)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Address line (Telugu) is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: villageEn,
                            decoration: const InputDecoration(
                              labelText: 'Village (English)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Village is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: villageTe,
                            decoration: const InputDecoration(
                              labelText: 'Village (Telugu)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Village (Telugu) is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: mandalEn,
                            decoration: const InputDecoration(
                              labelText: 'Mandal (English)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Mandal is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: mandalTe,
                            decoration: const InputDecoration(
                              labelText: 'Mandal (Telugu)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Mandal (Telugu) is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: districtEn,
                            decoration: const InputDecoration(
                              labelText: 'District (English)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'District is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: districtTe,
                            decoration: const InputDecoration(
                              labelText: 'District (Telugu)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'District (Telugu) is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: pincode,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Pincode',
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.length != 6 ||
                                  int.tryParse(text) == null) {
                                return 'Enter a valid 6-digit pincode';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: latitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                            validator: (value) {
                              if (double.tryParse(value?.trim() ?? '') ==
                                  null) {
                                return 'Enter valid latitude';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: longitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                            validator: (value) {
                              if (double.tryParse(value?.trim() ?? '') ==
                                  null) {
                                return 'Enter valid longitude';
                              }
                              return null;
                            },
                          ),
                          SwitchListTile(
                            value: isDefault,
                            onChanged: (value) =>
                                setLocalState(() => isDefault = value),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Set as default'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) {
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    final lat = double.tryParse(latitude.text.trim()) ?? 0;
    final lng = double.tryParse(longitude.text.trim()) ?? 0;

    setState(() {
      _isBusy = true;
    });

    final response = await _profileService.addAddress(
      language: _activeLanguage,
      request: AddAddressRequest(
        labelEn: labelEn.text.trim(),
        labelTe: labelTe.text.trim(),
        addressLineEn: lineEn.text.trim(),
        addressLineTe: lineTe.text.trim(),
        villageEn: villageEn.text.trim(),
        villageTe: villageTe.text.trim(),
        mandalEn: mandalEn.text.trim(),
        mandalTe: mandalTe.text.trim(),
        districtEn: districtEn.text.trim(),
        districtTe: districtTe.text.trim(),
        pincode: pincode.text.trim(),
        isDefault: isDefault,
        latitude: lat,
        longitude: lng,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
      if (response.isSuccess && response.data != null) {
        _addresses = [
          response.data!,
          ..._addresses,
        ].where((item) => item.id != null).toList();
      }
    });

    if (response.isSuccess) {
      await _load();
    }

    _showMessage(response.message ?? 'Address added successfully');
  }

  Future<void> _deleteAddress(AddressModel address) async {
    if (address.id == null) {
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Address'),
          content: Text(
            'Are you sure you want to delete ${address.label ?? 'this address'}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (approved != true) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    final response = await _profileService.deleteAddress(
      language: _activeLanguage,
      id: address.id!,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
      if (response.isSuccess) {
        _addresses = _addresses.where((a) => a.id != address.id).toList();
      }
    });

    _showMessage(response.message ?? 'Address deleted');
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7EE), Color(0xFFFFE8CF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryOrange,
            child: Text(
              _profileInitials(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Customer Profile',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile?.mobile?.trim().isNotEmpty == true
                      ? _profile!.mobile!
                      : '-',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_profile?.village ?? '-'} • ${_profile?.pincode ?? '-'}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressesList() {
    if (_addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.location_off_outlined,
              color: AppColors.textMuted,
              size: 34,
            ),
            SizedBox(height: 8),
            Text(
              'No saved addresses yet. Tap Add to create one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _addresses
          .map(
            (address) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1E2),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.primaryOrange,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  address.label ?? 'Address',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => _deleteAddress(address),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                                  address.addressLine,
                                  address.village,
                                  address.mandal,
                                  address.district,
                                ]
                                .where((part) => (part ?? '').trim().isNotEmpty)
                                .join(', '),
                            style: const TextStyle(color: AppColors.textDark),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F5F7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'PIN ${address.pincode ?? '-'}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (address.isDefault == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F6EE),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      color: Color(0xFF1D7C4D),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildProfileDetailsSection() {
    final rows = <MapEntry<String, String>>[
      MapEntry('Name', _displayName),
      MapEntry(
        'Mobile',
        _profile?.mobile?.trim().isNotEmpty == true ? _profile!.mobile! : '-',
      ),
      MapEntry(
        'Village',
        _profile?.village?.trim().isNotEmpty == true ? _profile!.village! : '-',
      ),
      MapEntry(
        'Pincode',
        _profile?.pincode?.trim().isNotEmpty == true ? _profile!.pincode! : '-',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Details',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      item.key,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = AppLanguageScope.watch(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppLanguage>(
                value: selectedLanguage,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.language),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  AppLanguageScope.update(context, value);
                },
                items: const [
                  DropdownMenuItem(
                    value: AppLanguage.en,
                    child: Text('English'),
                  ),
                  DropdownMenuItem(
                    value: AppLanguage.te,
                    child: Text('తెలుగు'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 14),
                  _buildProfileDetailsSection(),
                  if (_isBusy) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                  if (_inlineError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEFEF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCFCF)),
                      ),
                      child: Text(
                        _inlineError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Saved Addresses',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isBusy ? null : _showAddAddressDialog,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildAddressesList(),
                  const SizedBox(height: 88),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isBusy ? null : _showUpdateProfileDialog,
            icon: const Icon(Icons.edit_outlined),
            label: const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
