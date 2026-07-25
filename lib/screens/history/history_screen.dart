import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/history_item.dart';
import '../../models/rider_summary.dart';
import '../../services/dashboard_service.dart';
import '../../core/api_client.dart';
import '../../widgets/rider_bottom_nav.dart';

/// History screen — cursor-paginated infinite scroll with status tabs
/// and a Payments sub-view.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DashboardService _dashService = DashboardService();
  final ScrollController _scrollCtrl = ScrollController();
  final _timeFormat = DateFormat('h:mm a');
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  final List<HistoryItem> _items = [];
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  // Tabs: null = All, or specific status
  static const _tabs = [
    (null, 'All'),
    ('ONGOING', 'Ongoing'),
    ('COMPLETED', 'Completed'),
    ('FAILED', 'Failed'),
  ];
  int _selectedTab = 0;
  bool _showPayments = false;
  int _fetchToken = 0;

  RiderSummary? _paymentsSummary;
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetchPage();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchPage();
    }
  }

  Future<void> _fetchPage() async {
    if (_isLoading) return;
    final token = ++_fetchToken;
    setState(() => _isLoading = true);

    try {
      final status = _tabs[_selectedTab].$1;
      final res = await _dashService.getHistory(
        status: status,
        cursor: _nextCursor,
      );
      // Drop stale responses from a tab that's no longer selected.
      if (!mounted || token != _fetchToken) return;
      setState(() {
        _items.addAll(res.orders);
        _nextCursor = res.pagination.nextCursor;
        _hasMore = res.pagination.hasMore;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || token != _fetchToken) return;
      setState(() {
        _error = extractApiException(e).message;
        _isLoading = false;
      });
    }
  }

  void _switchTab(int index) {
    // Invalidate any in-flight request for the previous tab so its
    // response can't land on top of this tab's (possibly empty) list.
    _fetchToken++;
    setState(() {
      _selectedTab = index;
      _items.clear();
      _nextCursor = null;
      _hasMore = true;
      _isLoading = false;
    });
    _fetchPage();
  }

  void _setPayments(bool showPayments) {
    if (_showPayments == showPayments) return;
    setState(() => _showPayments = showPayments);
    if (showPayments && _paymentsSummary == null && !_isLoadingSummary) {
      _fetchPaymentsSummary();
    }
  }

  Future<void> _fetchPaymentsSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final summary = await _dashService.getSummary(period: 'all');
      if (!mounted) return;
      setState(() {
        _paymentsSummary = summary;
        _isLoadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: const RiderBottomNav(isHistorySelected: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.black, size: 24),
                    onPressed: () => context.go('/home'),
                  ),
                  const Text(
                    'History Section',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _segment('All', !_showPayments, () => _setPayments(false)),
                  const SizedBox(width: 40),
                  _segment('Payments', _showPayments, () => _setPayments(true)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFD9D9D9)),

            if (!_showPayments) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final isSelected = _selectedTab == i;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(_tabs[i].$2),
                      selectedColor: const Color(0xFFD9D9D9),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: Colors.black,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13,
                      ),
                      side: const BorderSide(color: Color(0xFFD9D9D9)),
                      onSelected: (_) => _switchTab(i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (_showPayments)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Cash in hand',
                        _paymentsSummary?.cashCollected,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Online Payments',
                        _paymentsSummary?.onlinePayments,
                      ),
                    ),
                  ],
                ),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFE74C3C)),
                ),
              ),

            Expanded(
              child: _items.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 48,
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No orders yet',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _items.length + (_isLoading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return _showPayments
                            ? _buildPaymentCard(_items[i])
                            : _buildOrderCard(_items[i]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD9D9D9) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: selected ? Colors.black : Colors.black.withValues(alpha: 0.6),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, double? value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingSummary && value == null
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _currencyFormat.format(value ?? 0),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
        ],
      ),
    );
  }

  String _bucketLabel(String bucket) {
    switch (bucket.toUpperCase()) {
      case 'ONGOING':
        return 'Ongoing';
      case 'COMPLETED':
        return 'Delivery Completed';
      case 'FAILED':
        return 'Delivery Failed';
      default:
        return bucket;
    }
  }

  // Pastel bg + solid border, matching the Figma history cards.
  (Color, Color) _bucketPalette(String bucket) {
    switch (bucket.toUpperCase()) {
      case 'ONGOING':
        return (const Color(0xFFFFFFC0), const Color(0xFFA25C00));
      case 'COMPLETED':
        return (const Color(0xFFCAFFC0), const Color(0xFF3C6235));
      case 'FAILED':
        return (const Color(0xFFFFC0C1), const Color(0xFF6D1314));
      default:
        return (const Color(0xFFE0E0E0), const Color(0xFF666666));
    }
  }

  Widget _buildOrderCard(HistoryItem item) {
    final (bg, border) = _bucketPalette(item.bucket);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag_outlined, color: border, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.orderNumber != null)
                  Text(
                    'Order #${item.orderNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                const SizedBox(height: 6),
                _buildLabeledLine('From', item.storeName ?? '—'),
                const SizedBox(height: 2),
                _buildLabeledLine(
                  'Deliver to',
                  item.customerName ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(item.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _bucketLabel(item.bucket),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: border,
                ),
              ),
              if (item.displayTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  _timeFormat.format(item.displayTime!.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledLine(String label, String value) {
    return RichText(
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(HistoryItem item) {
    const border = Color(0xFF3C6235);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFCAFFC0).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(
              item.collectionMethod?.toLowerCase() == 'cash'
                  ? Icons.money_rounded
                  : Icons.qr_code_rounded,
              color: Colors.black87,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.orderNumber != null)
                  Text(
                    'Order #${item.orderNumber}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                const SizedBox(height: 2),
                const Text(
                  'Order Completed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  item.collectionMethod ?? item.paymentMode ?? '—',
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(item.amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
