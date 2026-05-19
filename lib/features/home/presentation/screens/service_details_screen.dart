import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/home_service.dart';
import 'package:babai_bazor_app/core/services/profile_service.dart';
import 'package:flutter/material.dart';

class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({
    super.key,
    required this.language,
    required this.service,
  });

  final AppLanguage language;
  final ServiceSummary service;

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  final HomeService _homeService = const HomeService();
  final ProfileService _profileService = const ProfileService();

  late ServiceSummary _service;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isBooking = false;
  String? _error;

  List<ServiceSlotSummary> _availableSlots = const [];
  ServiceSlotSummary? _selectedSlot;

  List<ServiceProfessionalSummary> _professionals = const [];
  int? _selectedProfessionalId;

  List<AddressModel> _addresses = const [];
  int? _selectedAddressId;

  String _selectedPaymentMethod = 'UPI';

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final detailsFuture = _homeService.getServiceDetails(
      language: widget.language,
      serviceId: _service.id,
    );
    final slotsFuture = _loadSlots(forDate: _selectedDate, setLoading: false);
    final professionalsFuture = _homeService.getServiceProfessionals(
      language: widget.language,
      serviceId: _service.id,
    );
    final addressesFuture = _profileService.getAddresses(
      language: widget.language,
    );

    final details = await detailsFuture;
    final professionals = await professionalsFuture;
    final addresses = await addressesFuture;
    await slotsFuture;

    if (!mounted) {
      return;
    }

    final selectedService = details ?? _service;
    final profs = professionals.data.where((e) => e.id > 0).toList();
    final addrs = addresses.data.where((e) => (e.id ?? 0) > 0).toList();

    setState(() {
      _isLoading = false;
      _service = selectedService;
      _professionals = profs;
      _selectedProfessionalId = profs.isEmpty
          ? null
          : (profs
                .firstWhere(
                  (e) => e.id == _selectedProfessionalId,
                  orElse: () => profs.first,
                )
                .id);
      _addresses = addrs;
      _selectedAddressId = addrs.isEmpty
          ? null
          : (addrs
                .firstWhere(
                  (e) => e.isDefault == true,
                  orElse: () => addrs.first,
                )
                .id);

      if (_availableSlots.isEmpty) {
        _error = _error ?? 'No available slots for this date.';
      }
    });
  }

  Future<void> _loadSlots({
    required DateTime forDate,
    bool setLoading = true,
  }) async {
    if (setLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final response = await _homeService.getServiceSlots(
      language: widget.language,
      serviceId: _service.id,
      slotDate: _toApiDate(forDate),
    );

    if (!mounted) {
      return;
    }

    final available = response.data
        .where(
          (slot) =>
              (slot.isAvailable ?? true) &&
              slot.id > 0 &&
              slot.slotTime.trim().isNotEmpty,
        )
        .toList();

    setState(() {
      _isLoading = false;
      _availableSlots = available;
      if (available.every((e) => e.id != _selectedSlot?.id)) {
        _selectedSlot = null;
      }
      _error = available.isEmpty
          ? (response.message ?? 'No available slots for this date.')
          : null;
    });
  }

  String _toApiDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatRupees(double? value) {
    if (value == null) {
      return 'NA';
    }
    if (value == value.roundToDouble()) {
      return 'Rs.${value.toStringAsFixed(0)}';
    }
    return 'Rs.${value.toStringAsFixed(2)}';
  }

  Future<void> _bookNow() async {
    final selectedSlot = _selectedSlot;
    final addressId = _selectedAddressId;
    final personId = _selectedProfessionalId;

    if (selectedSlot == null || addressId == null || personId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select address, professional and slot.')),
      );
      return;
    }

    setState(() => _isBooking = true);

    final bookingResponse = await _homeService.bookService(
      language: widget.language,
      serviceId: _service.id,
      addressId: addressId,
      slotDate: _toApiDate(_selectedDate),
      slotTime: selectedSlot.slotTime,
      slotId: selectedSlot.id,
      servicePersonId: personId,
      paymentMethod: _selectedPaymentMethod,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isBooking = false);

    if (bookingResponse.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bookingResponse.bookingId == null
                ? 'Booking confirmed.'
                : 'Booking confirmed. ID: ${bookingResponse.bookingId}',
          ),
        ),
      );
      Navigator.of(context).maybePop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(bookingResponse.message ?? 'Unable to book service.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceName = _service.localizedName(widget.language);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        title: const Text(
          'Service Details',
          style: TextStyle(
            color: Color(0xFF14192D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E6EF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _service.emoji ?? '🔧',
                            style: const TextStyle(fontSize: 30),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              serviceName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _service.description ?? 'Professional home service.',
                        style: const TextStyle(
                          color: Color(0xFF5F667A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_formatRupees(_service.price)}  ${_formatRupees(_service.mrp)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rating: ${(_service.rating ?? 0).toStringAsFixed(1)} (${_service.reviewCount ?? 0})',
                        style: const TextStyle(
                          color: Color(0xFF6A7289),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_service.includes.isNotEmpty)
                  _SectionCard(
                    title: 'What is included',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _service.includes
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• $item'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (_service.includes.isNotEmpty) const SizedBox(height: 12),
                if (_service.instructions.isNotEmpty)
                  _SectionCard(
                    title: 'Before you book',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _service.instructions
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• $item'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (_service.instructions.isNotEmpty)
                  const SizedBox(height: 12),
                _SectionCard(
                  title: 'Select Date',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Date: ${_toApiDate(_selectedDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                            initialDate: _selectedDate,
                          );
                          if (picked == null || !mounted) {
                            return;
                          }
                          setState(() => _selectedDate = picked);
                          await _loadSlots(forDate: picked);
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Available Slots',
                  child: _availableSlots.isEmpty
                      ? Text(
                          _error ?? 'No slots available.',
                          style: const TextStyle(color: Color(0xFF7A8195)),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableSlots.map((slot) {
                            final selected = _selectedSlot?.id == slot.id;
                            return ChoiceChip(
                              label: Text(slot.label ?? slot.slotTime),
                              selected: selected,
                              onSelected: (_) {
                                setState(() => _selectedSlot = slot);
                              },
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Select Professional',
                  child: _professionals.isEmpty
                      ? const Text(
                          'No professional available for this service right now.',
                          style: TextStyle(color: Color(0xFF7A8195)),
                        )
                      : DropdownButtonFormField<int>(
                          value: _selectedProfessionalId,
                          items: _professionals
                              .map(
                                (p) => DropdownMenuItem<int>(
                                  value: p.id,
                                  child: Text(
                                    p.rating == null
                                        ? p.name
                                        : '${p.name} (${p.rating!.toStringAsFixed(1)})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedProfessionalId = value);
                          },
                        ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Select Address',
                  child: _addresses.isEmpty
                      ? const Text(
                          'No address found. Please add an address from profile.',
                          style: TextStyle(color: Color(0xFF7A8195)),
                        )
                      : DropdownButtonFormField<int>(
                          value: _selectedAddressId,
                          items: _addresses
                              .map(
                                (a) => DropdownMenuItem<int>(
                                  value: a.id,
                                  child: Text(
                                    '${a.label ?? 'Address'} - ${a.addressLine ?? ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedAddressId = value);
                          },
                        ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Payment Method',
                  child: DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(
                        value: 'COD',
                        child: Text('Cash On Delivery'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _selectedPaymentMethod = value);
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _bookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF121A2D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text(
                      'Confirm & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
