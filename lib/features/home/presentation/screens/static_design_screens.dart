import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/home_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Color _offerColorFromHex(String? rawHex, {Color fallback = const Color(0xFFF24A0D)}) {
  final value = rawHex?.trim() ?? '';
  if (value.isEmpty) {
    return fallback;
  }
  var hex = value.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length != 8) {
    return fallback;
  }
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return fallback;
  }
  return Color(parsed);
}

class StaticOffersScreen extends StatefulWidget {
  const StaticOffersScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  State<StaticOffersScreen> createState() => _StaticOffersScreenState();
}

class _StaticOffersScreenState extends State<StaticOffersScreen> {
  final HomeService _homeService = const HomeService();
  final TextEditingController _couponController = TextEditingController();

  static const _filters = ['All', 'Grocery', 'Services', 'Payment'];

  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'All';
  List<OfferSummary> _offers = const [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _homeService.getOffers(language: widget.language);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _offers = response.data;
      if (!response.isSuccess && response.data.isEmpty) {
        _error = response.message ?? 'Unable to load offers.';
      }
    });
  }

  List<OfferSummary> get _visibleOffers {
    if (_selectedFilter == 'All') {
      return _offers;
    }

    final filter = _selectedFilter.toLowerCase();
    return _offers.where((offer) {
      final category = offer.categoryLabel().toLowerCase();
      return category.contains(filter);
    }).toList();
  }

  void _applyCouponCode() {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a coupon code')),
      );
      return;
    }

    final match = _offers.where(
      (offer) => (offer.code ?? '').trim().toUpperCase() == code.toUpperCase(),
    );
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coupon $code is not available')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $code')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleOffers = _visibleOffers;
    final countLabel = visibleOffers.length == 1
        ? '1 coupon available'
        : '${visibleOffers.length} coupons available';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F8),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF161A2B)),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coupons & Offers',
              style: TextStyle(
                color: Color(0xFF14192D),
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _isLoading ? 'Loading offers...' : countLabel,
              style: const TextStyle(color: Color(0xFF8E93A7), fontSize: 13),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < _filters.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _Chip(
                            selected: _selectedFilter == _filters[i],
                            text: _filters[i],
                            onTap: () {
                              setState(() => _selectedFilter = _filters[i]);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD8CCFF)),
                    ),
                    child: Row(
                      children: [
                        const Text('🎟️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _couponController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'Enter coupon code',
                              hintStyle: TextStyle(
                                color: Color(0xFF9AA0B6),
                                fontWeight: FontWeight.w600,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _applyCouponCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C3AE8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_error != null && visibleOffers.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.35,
                      child: Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFF6D6D6D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else if (visibleOffers.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.35,
                      child: Center(
                        child: Text(
                          _selectedFilter == 'All'
                              ? 'No offers available right now'
                              : 'No offers in $_selectedFilter',
                          style: const TextStyle(
                            color: Color(0xFF6D6D6D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final offer in visibleOffers)
                      _OfferTile(offer: offer, language: widget.language),
                ],
              ),
      ),
    );
  }
}

class StaticServicesScreen extends StatelessWidget {
  const StaticServicesScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final services = _mockServices;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF151A2D)),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            Text('🔧', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Services',
              style: TextStyle(
                color: Color(0xFF14192D),
                fontWeight: FontWeight.w800,
                fontSize: 30,
              ),
            ),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final service = services[index];
          return _ServiceCard(
            service: service,
            onTapBook: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StaticServiceDetailsScreen(
                    language: language,
                    service: service,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StaticServiceDetailsScreen extends StatelessWidget {
  const StaticServiceDetailsScreen({
    super.key,
    required this.language,
    required this.service,
  });

  final AppLanguage language;
  final _ServiceItem service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF151A2D)),
        ),
        title: const Text(
          'Service Details',
          style: TextStyle(
            color: Color(0xFF14192D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2758D6), Color(0xFF6C3AE8)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        service.emoji,
                        style: const TextStyle(fontSize: 44),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '⭐ ${service.rating}',
                            style: const TextStyle(
                              color: Color(0xFFFFC53A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _Pill(
                                text: service.duration,
                                background: Colors.white.withValues(alpha: 0.2),
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              _Pill(
                                text: 'Insured',
                                background: Colors.white.withValues(alpha: 0.2),
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE6E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SERVICE PRICE',
                              style: TextStyle(
                                color: Color(0xFF8A90A4),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              service.price,
                              style: const TextStyle(
                                color: Color(0xFF14192D),
                                fontWeight: FontWeight.w900,
                                fontSize: 52,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${service.strikePrice} · ${service.off}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🛡️', style: TextStyle(fontSize: 28)),
                            SizedBox(height: 4),
                            Text(
                              'Insured Pro',
                              style: TextStyle(
                                color: Color(0xFF157347),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: _WhiteSection(
                  title: "What's Included",
                  icon: '✅',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: service.highlights
                        .map(
                          (text) => _Pill(
                            text: text,
                            background: const Color(0xFFE5F4EC),
                            color: const Color(0xFF2F5A4A),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF4DF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0CC7E)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Text('📋'),
                          SizedBox(width: 8),
                          Text(
                            'Before You Book',
                            style: TextStyle(
                              color: Color(0xFF151A2D),
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      _RuleBullet(
                        number: '1',
                        text: 'Clear countertops before arrival',
                      ),
                      _RuleBullet(
                        number: '2',
                        text: 'Keep pets in separate room',
                      ),
                      _RuleBullet(
                        number: '3',
                        text: 'Professionals bring all supplies',
                      ),
                      _RuleBullet(
                        number: '4',
                        text: '30-min arrival notification',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StaticSlotSelectionScreen(
                          language: language,
                          service: service,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFFE1E2EE),
                    foregroundColor: const Color(0xFF8A90A4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Select Date & Time to Book',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaticSlotSelectionScreen extends StatefulWidget {
  const StaticSlotSelectionScreen({
    super.key,
    required this.language,
    required this.service,
  });

  final AppLanguage language;
  final _ServiceItem service;

  @override
  State<StaticSlotSelectionScreen> createState() =>
      _StaticSlotSelectionScreenState();
}

class _StaticSlotSelectionScreenState extends State<StaticSlotSelectionScreen> {
  int _selectedDateIndex = 0;
  String? _selectedTime;

  static const List<_DateSlot> _dates = [
    _DateSlot(day: 'Today', date: '13', month: 'May', weekday: 'Wednesday'),
    _DateSlot(day: 'Tomorrow', date: '14', month: 'May', weekday: 'Thursday'),
    _DateSlot(day: 'Fri', date: '15', month: 'May', weekday: 'Friday'),
    _DateSlot(day: 'Sat', date: '16', month: 'May', weekday: 'Saturday'),
    _DateSlot(day: 'Sun', date: '17', month: 'May', weekday: 'Sunday'),
  ];

  static const List<_TimeSlot> _times = [
    _TimeSlot('08:00 AM'),
    _TimeSlot('09:00 AM', booked: true),
    _TimeSlot('10:00 AM'),
    _TimeSlot('11:00 AM'),
    _TimeSlot('12:00 PM', booked: true),
    _TimeSlot('02:00 PM'),
    _TimeSlot('03:00 PM'),
    _TimeSlot('04:00 PM', booked: true),
    _TimeSlot('05:00 PM'),
    _TimeSlot('06:00 PM'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedDate = _dates[_selectedDateIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF151A2D)),
        ),
        title: const Text(
          'Choose Date & Time',
          style: TextStyle(
            color: Color(0xFF14192D),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 98),
            children: [
              _WhiteSection(
                title: 'Choose Date',
                icon: '🗓️',
                child: Column(
                  children: [
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final item = _dates[index];
                          final selected = index == _selectedDateIndex;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDateIndex = index),
                            child: Container(
                              width: 72,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFF44700)
                                    : const Color(0xFFF1F2F7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE1E4EF),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    item.day,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF8A90A4),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.date,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF151A2D),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 36,
                                    ),
                                  ),
                                  Text(
                                    item.month,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF8A90A4),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: _dates.length,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('🗓️'),
                        const SizedBox(width: 8),
                        Text(
                          '${selectedDate.weekday}, May ${selectedDate.date}',
                          style: const TextStyle(
                            color: Color(0xFF2C3252),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _WhiteSection(
                title: 'Choose Time Slot',
                icon: '⏰',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _times.map((slot) {
                    final selected = _selectedTime == slot.time;
                    return GestureDetector(
                      onTap: slot.booked
                          ? null
                          : () => setState(() => _selectedTime = slot.time),
                      child: Container(
                        width: (MediaQuery.of(context).size.width - 52) / 3,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF4B48E2)
                              : slot.booked
                              ? const Color(0xFFF4F5FA)
                              : const Color(0xFFF6F7FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE4E7F1)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              slot.time,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : slot.booked
                                    ? const Color(0xFFC2C5D1)
                                    : const Color(0xFF14192D),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (slot.booked || selected)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  slot.booked ? 'Booked' : 'Selected ✓',
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white70
                                        : const Color(0xFFC2C5D1),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _WhiteSection(
                title: 'Our Professionals',
                icon: '👷',
                child: const Column(
                  children: [
                    _ProTile(
                      name: 'Ravi Kumar',
                      rating: '4.9',
                      reviews: '(342)',
                      tag: 'TOP RATED',
                      emoji: '👷',
                    ),
                    SizedBox(height: 10),
                    _ProTile(
                      name: 'Amit Sharma',
                      rating: '4.8',
                      reviews: '(218)',
                      tag: 'EXPERT',
                      emoji: '🧑‍🔧',
                    ),
                  ],
                ),
              ),
              if (_selectedTime != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '🗓️ ${selectedDate.weekday}, May ${selectedDate.date} at $_selectedTime',
                    style: const TextStyle(
                      color: Color(0xFF2758D6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedTime == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StaticBookingTrackingScreen(
                                language: widget.language,
                                service: widget.service,
                                timeText:
                                    '${selectedDate.weekday}, ${selectedDate.date} May at $_selectedTime',
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: _selectedTime == null
                        ? const Color(0xFFE1E2EE)
                        : const Color(0xFF4B48E2),
                    foregroundColor: _selectedTime == null
                        ? const Color(0xFF8A90A4)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _selectedTime == null
                        ? 'Select Date & Time to Book'
                        : 'Book Now · ${widget.service.price}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaticBookingHistoryScreen extends StatefulWidget {
  const StaticBookingHistoryScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  State<StaticBookingHistoryScreen> createState() =>
      _StaticBookingHistoryScreenState();
}

class _StaticBookingHistoryScreenState
    extends State<StaticBookingHistoryScreen> {
  final HomeService _homeService = const HomeService();

  bool _upcoming = true;
  bool _isLoading = true;
  String? _error;
  List<ServiceBookingSummary> _upcomingBookings = const [];
  List<ServiceBookingSummary> _pastBookings = const [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final pendingFuture = _homeService.getServiceBookings(
      language: widget.language,
      status: 'PENDING',
    );
    final confirmedFuture = _homeService.getServiceBookings(
      language: widget.language,
      status: 'CONFIRMED',
    );
    final completedFuture = _homeService.getServiceBookings(
      language: widget.language,
      status: 'COMPLETED',
    );
    final cancelledFuture = _homeService.getServiceBookings(
      language: widget.language,
      status: 'CANCELLED',
    );

    final results = await Future.wait([
      pendingFuture,
      confirmedFuture,
      completedFuture,
      cancelledFuture,
    ]);

    if (!mounted) {
      return;
    }

    final upcoming = <ServiceBookingSummary>[
      ...results[0].data,
      ...results[1].data,
    ];
    final past = <ServiceBookingSummary>[
      ...results[2].data,
      ...results[3].data,
    ];

    String? error;
    if (upcoming.isEmpty &&
        past.isEmpty &&
        results.any((response) => !response.isSuccess)) {
      for (final response in results) {
        final message = response.message?.trim();
        if (!response.isSuccess && message != null && message.isNotEmpty) {
          error = message;
          break;
        }
      }
      error ??= 'Unable to load bookings.';
    }

    setState(() {
      _isLoading = false;
      _upcomingBookings = upcoming;
      _pastBookings = past;
      _error = error;
    });
  }

  String _formatRupees(double? value) {
    if (value == null) {
      return '₹--';
    }
    if (value == value.roundToDouble()) {
      return '₹${value.toStringAsFixed(0)}';
    }
    return '₹${value.toStringAsFixed(2)}';
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'CONFIRMED':
        return const Color(0xFF2758D6);
      case 'COMPLETED':
        return const Color(0xFF1FB165);
      case 'CANCELLED':
        return const Color(0xFFE8420A);
      default:
        return const Color(0xFF6A7289);
    }
  }

  Color _statusBackground(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFFF0C8);
      case 'CONFIRMED':
        return const Color(0xFFE4EAFB);
      case 'COMPLETED':
        return const Color(0xFFEAF6EE);
      case 'CANCELLED':
        return const Color(0xFFFFEFE7);
      default:
        return const Color(0xFFF0F2F8);
    }
  }

  List<Widget> _buildBookingList() {
    final bookings = _upcoming ? _upcomingBookings : _pastBookings;

    if (_error != null && bookings.isEmpty) {
      return [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Center(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF6D6D6D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ];
    }

    if (bookings.isEmpty) {
      return [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Center(
            child: Text(
              _upcoming ? 'No upcoming bookings' : 'No past bookings',
              style: const TextStyle(
                color: Color(0xFF6D6D6D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ];
    }

    if (_upcoming) {
      return [
        for (var i = 0; i < bookings.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _UpcomingCard(
            title: bookings[i].serviceName ?? 'Service booking',
            subtitle: bookings[i].scheduleLabel,
            pro: bookings[i].professionalName ?? 'Professional pending',
            amount: _formatRupees(bookings[i].amount),
            status: (bookings[i].status ?? 'PENDING').toUpperCase(),
            statusColor: _statusColor(bookings[i].status),
            statusBackground: _statusBackground(bookings[i].status),
            emoji: bookings[i].emoji ?? '🔧',
            onTrack: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tracking will be available soon')),
              );
            },
          ),
        ],
      ];
    }

    return [
      for (var i = 0; i < bookings.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _PastCard(
          title: bookings[i].serviceName ?? 'Service booking',
          subtitle: bookings[i].scheduleLabel,
          pro: bookings[i].professionalName ?? '—',
          amount: _formatRupees(bookings[i].amount),
          status: (bookings[i].status ?? 'COMPLETED').toUpperCase(),
          stars: bookings[i].rating ?? 0,
          emoji: bookings[i].emoji ?? '🔧',
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF151A2D)),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            Text('🗓️', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Booking History',
              style: TextStyle(
                color: Color(0xFF14192D),
                fontWeight: FontWeight.w800,
                fontSize: 32,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _HistoryTab(
                    text: 'Upcoming Bookings',
                    selected: _upcoming,
                    onTap: () {
                      if (_upcoming) {
                        return;
                      }
                      setState(() => _upcoming = true);
                    },
                  ),
                ),
                Expanded(
                  child: _HistoryTab(
                    text: 'Past Bookings',
                    selected: !_upcoming,
                    onTap: () {
                      if (!_upcoming) {
                        return;
                      }
                      setState(() => _upcoming = false);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBookings,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 88),
                      children: _buildBookingList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaticBookingTrackingScreen extends StatelessWidget {
  const StaticBookingTrackingScreen({
    super.key,
    required this.language,
    required this.service,
    required this.timeText,
  });

  final AppLanguage language;
  final _ServiceItem service;
  final String timeText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1FB165),
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 26, 12, 22),
            decoration: const BoxDecoration(color: Color(0xFF1FB165)),
            child: const Column(
              children: [
                Text('🎉', style: TextStyle(fontSize: 58)),
                SizedBox(height: 8),
                Text(
                  'Booking Confirmed!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ID: #BB854263',
                  style: TextStyle(
                    color: Color(0xFFCFFBE1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: _WhiteSection(
              title: 'Live Status',
              icon: '📍',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0C8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ETA: 12 min',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StepDot(
                    label: 'Booking\nConfirmed',
                    active: true,
                    done: true,
                  ),
                  _StepDot(
                    label: 'Professional\nAssigned',
                    active: true,
                    done: true,
                  ),
                  _StepDot(
                    label: 'On the Way',
                    active: true,
                    done: false,
                    index: '3',
                  ),
                  _StepDot(
                    label: 'Arrived',
                    active: false,
                    done: false,
                    index: '4',
                  ),
                  _StepDot(
                    label: 'In Progress',
                    active: false,
                    done: false,
                    index: '5',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: _WhiteSection(
              title: 'Live Tracking',
              icon: '🗺️',
              trailing: const Text(
                '• Live',
                style: TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    height: 190,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E6E2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '🛵   Ravi Kumar   🏠',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Professional is on the way',
                          style: TextStyle(
                            color: Color(0xFF2C3252),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '12 min away',
                        style: TextStyle(
                          color: Color(0xFF2758D6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: _WhiteSection(
              title: 'Your Professional',
              icon: '👷',
              child: Column(
                children: [
                  const _ProTile(
                    name: 'Ravi Kumar',
                    rating: '4.9',
                    reviews: '(342)',
                    tag: 'TOP RATED',
                    emoji: '👷',
                    secondaryTag: 'VERIFIED',
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EEF9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '🔐 Booking OTP',
                              style: TextStyle(
                                color: Color(0xFF2758D6),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '7 8 4 2',
                              style: TextStyle(
                                color: Color(0xFF14192D),
                                fontWeight: FontWeight.w900,
                                fontSize: 42,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Share this OTP only with your assigned professional to confirm service start.',
                          style: TextStyle(
                            color: Color(0xFF52597A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          text: '📞 Call',
                          color: Color(0xFF1FB165),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          text: '💬 Chat',
                          color: Color(0xFF4B48E2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _SquareDanger(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: _WhiteSection(
              title: 'Booking Details',
              icon: '📋',
              child: Column(
                children: [
                  _kv('Service', service.title),
                  _kv('Scheduled', timeText),
                  _kv('Duration', service.duration),
                  _kv('Amount', service.price),
                  _kv('Payment', 'Pay after service'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StaticBookingHistoryScreen(language: language),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFFF44700),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'View Booking History →',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: const TextStyle(
                color: Color(0xFF8A90A4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF14192D),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StaticProfileMenuScreen extends StatelessWidget {
  const StaticProfileMenuScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 44, 10, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF332242), Color(0xFFF44700)],
              ),
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Color(0x66FFFFFF),
                  child: Text('👤', style: TextStyle(fontSize: 42)),
                ),
                SizedBox(height: 10),
                Text(
                  'Babai User',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 42,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '+91 9010931034',
                  style: TextStyle(
                    color: Color(0xFFFDE5D8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CountItem(value: '3', label: 'Orders'),
                    _CountItem(value: '0', label: 'Bookings'),
                    _CountItem(value: '240', label: 'Points'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
              children: const [
                _MenuItem(icon: '📦', title: 'My Orders'),
                _MenuItem(icon: '🗓️', title: 'Bookings'),
                _MenuItem(icon: '💗', title: 'Wishlist'),
                _MenuItem(icon: '🎟️', title: 'Coupons', count: '5'),
                _MenuItem(icon: '📍', title: 'Addresses'),
                _MenuItem(icon: '💳', title: 'Payment Methods'),
                _MenuItem(icon: '⭐', title: 'My Reviews'),
                _MenuItem(icon: '🔔', title: 'Notifications'),
                _MenuItem(icon: '🔒', title: 'Privacy'),
                _MenuItem(icon: '🚪', title: 'Logout'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.title,
    required this.emoji,
    required this.price,
    required this.strikePrice,
    required this.off,
    required this.rating,
    required this.duration,
    required this.highlights,
  });

  final String title;
  final String emoji;
  final String price;
  final String strikePrice;
  final String off;
  final String rating;
  final String duration;
  final List<String> highlights;
}

const List<_ServiceItem> _mockServices = [
  _ServiceItem(
    title: 'Full Home Deep Clean',
    emoji: '🏠',
    price: '₹999',
    strikePrice: '₹1399',
    off: '29% off',
    rating: '4.8 (2341)',
    duration: '4-5 hrs',
    highlights: [
      'All rooms vacuumed',
      'Kitchen degreased',
      'Bathrooms sanitized',
      'Windows wiped',
      'Floor mopped',
    ],
  ),
  _ServiceItem(
    title: 'Bathroom Deep Clean',
    emoji: '🚿',
    price: '₹299',
    strikePrice: '₹449',
    off: '33% off',
    rating: '4.7 (1892)',
    duration: '1-1.5 hrs',
    highlights: ['Toilet sanitized', 'Tiles scrubbed', 'Mirror cleaned'],
  ),
  _ServiceItem(
    title: 'Kitchen Deep Clean',
    emoji: '🍳',
    price: '₹449',
    strikePrice: '₹599',
    off: '25% off',
    rating: '4.9 (987)',
    duration: '2-3 hrs',
    highlights: [
      'Stove degreased',
      'Chimney cleaned',
      'Cabinet exterior wiped',
    ],
  ),
];

class _DateSlot {
  const _DateSlot({
    required this.day,
    required this.date,
    required this.month,
    required this.weekday,
  });

  final String day;
  final String date;
  final String month;
  final String weekday;
}

class _TimeSlot {
  const _TimeSlot(this.time, {this.booked = false});

  final String time;
  final bool booked;
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer, required this.language});

  final OfferSummary offer;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final accent = _offerColorFromHex(offer.color);
    final code = (offer.code ?? '').trim();
    final validTill = offer.validTillLabel();
    final emoji = (offer.emoji ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6F0)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji.isNotEmpty ? emoji : '🎟️',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.localizedTitle(language),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        offer.contextLabel(),
                        style: const TextStyle(
                          color: Color(0xFFEAF4FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (code.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.discountLabel(),
                        style: const TextStyle(
                          color: Color(0xFF2C3252),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (validTill.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          validTill,
                          style: const TextStyle(
                            color: Color(0xFF9AA0B6),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (code.isNotEmpty)
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied $code')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent.withValues(alpha: 0.45)),
                      foregroundColor: accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Copy Code'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTapBook});

  final _ServiceItem service;
  final VoidCallback onTapBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  service.emoji,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: const TextStyle(
                        color: Color(0xFF14192D),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '⭐ ${service.rating}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '⏱ ${service.duration}',
                      style: const TextStyle(
                        color: Color(0xFF8A90A4),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    service.price,
                    style: const TextStyle(
                      color: Color(0xFF14192D),
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                    ),
                  ),
                  Text(
                    service.strikePrice,
                    style: const TextStyle(
                      color: Color(0xFFA2A8BC),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: service.highlights.take(3).map((text) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF4E8),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '✓ $text',
                  style: const TextStyle(
                    color: Color(0xFF1B8C57),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTapBook,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: const Color(0xFF2758D6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Book Now →',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteSection extends StatelessWidget {
  const _WhiteSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF14192D),
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.color,
  });

  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _RuleBullet extends StatelessWidget {
  const _RuleBullet({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFF8B500),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2C3252),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProTile extends StatelessWidget {
  const _ProTile({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.tag,
    required this.emoji,
    this.secondaryTag,
  });

  final String name;
  final String rating;
  final String reviews;
  final String tag;
  final String emoji;
  final String? secondaryTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF14192D),
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '⭐ $rating $reviews',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SmallTag(
                text: tag,
                color: const Color(0xFF2758D6),
                bg: const Color(0xFFE4EAFB),
              ),
              if (secondaryTag != null) ...[
                const SizedBox(height: 6),
                _SmallTag(
                  text: secondaryTag!,
                  color: const Color(0xFF16A34A),
                  bg: const Color(0xFFE2F4E9),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.text, required this.color, required this.bg});

  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _SquareDanger extends StatelessWidget {
  const _SquareDanger();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD6C7)),
      ),
      alignment: Alignment.center,
      child: const Text('🆘'),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.active,
    required this.done,
    this.index,
  });

  final String label;
  final bool active;
  final bool done;
  final String? index;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? const Color(0xFF2758D6)
        : active
        ? const Color(0xFFF8B500)
        : const Color(0xFFE6E8F2);
    final textColor = done || active ? Colors.white : const Color(0xFFA1A6BC);

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            done ? '✓' : (index ?? ''),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: done || active
                  ? const Color(0xFF2758D6)
                  : const Color(0xFFA1A6BC),
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFFF44700) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? const Color(0xFFF44700) : const Color(0xFF8A90A4),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.title,
    required this.subtitle,
    required this.pro,
    required this.amount,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.emoji,
    required this.onTrack,
  });

  final String title;
  final String subtitle;
  final String pro;
  final String amount;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final String emoji;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF14192D),
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🕒 $subtitle',
                      style: const TextStyle(
                        color: Color(0xFF8A90A4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '👷 $pro',
                      style: const TextStyle(
                        color: Color(0xFF8A90A4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallTag(
                text: status,
                color: statusColor,
                bg: statusBackground,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                color: Color(0xFF14192D),
                fontWeight: FontWeight.w900,
                fontSize: 40,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onTrack,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFFE9EEF9),
                    foregroundColor: const Color(0xFF2758D6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '📍 Track',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFFFFF0EA),
                    foregroundColor: const Color(0xFFF44700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
    );
  }
}

class _PastCard extends StatelessWidget {
  const _PastCard({
    required this.title,
    required this.subtitle,
    required this.pro,
    required this.amount,
    required this.status,
    required this.stars,
    required this.emoji,
  });

  final String title;
  final String subtitle;
  final String pro;
  final String amount;
  final String status;
  final int stars;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final completed = status == 'COMPLETED';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF14192D),
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🕒 $subtitle',
                      style: const TextStyle(
                        color: Color(0xFF8A90A4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '👷 $pro',
                      style: const TextStyle(
                        color: Color(0xFF8A90A4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallTag(
                text: status,
                color: completed
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFF44700),
                bg: completed
                    ? const Color(0xFFE2F4E9)
                    : const Color(0xFFFFE9E1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                color: Color(0xFF14192D),
                fontWeight: FontWeight.w900,
                fontSize: 40,
              ),
            ),
          ),
          const Divider(height: 16, color: Color(0xFFE8EAF2)),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rate your experience:',
              style: TextStyle(
                color: Color(0xFF8A90A4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                Icons.star,
                size: 22,
                color: index < stars
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFD4D8E6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF44700),
                side: const BorderSide(color: Color(0xFFF9C1AB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '🔁 Book Again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    this.selected = false,
    required this.text,
    this.onTap,
  });

  final bool selected;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C3AE8) : const Color(0xFFF3F4F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF6C3AE8) : const Color(0xFFD7DBE8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4F5675),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  const _CountItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 40,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFCE8DE),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.title, this.count});

  final String icon;
  final String title;
  final String? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E6F0)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF14192D),
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEE8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count!,
                style: const TextStyle(
                  color: Color(0xFFF44700),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Color(0xFFD4D8E6)),
        ],
      ),
    );
  }
}
