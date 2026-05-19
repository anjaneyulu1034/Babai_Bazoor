import 'package:babai_bazor_app/core/localization/app_localizations.dart';
import 'package:babai_bazor_app/core/models/api_models.dart';
import 'package:babai_bazor_app/core/services/home_service.dart';
import 'package:babai_bazor_app/features/home/presentation/screens/service_details_screen.dart';
import 'package:flutter/material.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, required this.language});

  final AppLanguage language;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final HomeService _homeService = const HomeService();

  bool _isLoading = true;
  String? _error;
  List<ServiceSummary> _services = const [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _homeService.getServices(language: widget.language);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _services = response.data;
      if (!response.isSuccess && response.data.isEmpty) {
        _error = response.message ?? 'Unable to load services.';
      }
    });
  }

  String _formatRupees(double? value) {
    if (value == null) {
      return 'NA';
    }
    if (value == value.roundToDouble()) {
      return '₹${value.toStringAsFixed(0)}';
    }
    return '₹${value.toStringAsFixed(2)}';
  }

  String _discountText(ServiceSummary service) {
    final discount = service.discount;
    if (discount != null && discount > 0) {
      return '$discount% OFF';
    }
    final mrp = service.mrp;
    final price = service.price;
    if (mrp == null || price == null || mrp <= 0 || price >= mrp) {
      return 'Best Price';
    }
    final pct = ((mrp - price) / mrp) * 100;
    return '${pct.round()}% OFF';
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
      body: RefreshIndicator(
        onRefresh: _loadServices,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _services.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
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
                ],
              )
            : _services.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: const Center(
                      child: Text(
                        'No services available right now',
                        style: TextStyle(
                          color: Color(0xFF6D6D6D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                itemCount: _services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final service = _services[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => ServiceDetailsScreen(
                              language: widget.language,
                              service: service,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E6EF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F2F8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                service.emoji ?? '🔧',
                                style: const TextStyle(fontSize: 30),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service.localizedName(widget.language),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '⭐ ${(service.rating ?? 0).toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      color: Color(0xFF6A7289),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '⏱ ${service.durationLabel?.trim().isNotEmpty == true ? service.durationLabel!.trim() : '30-60 min'}',
                                    style: const TextStyle(
                                      color: Color(0xFF6A7289),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 86,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatRupees(service.price),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatRupees(service.mrp),
                                  style: const TextStyle(
                                    color: Color(0xFF9BA1B5),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF6EE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _discountText(service),
                                    style: const TextStyle(
                                      color: Color(0xFF1C8E53),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
