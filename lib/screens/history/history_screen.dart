import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/history_item.dart';
import '../../services/dashboard_service.dart';
import '../../core/api_client.dart';
import '../../widgets/status_chip.dart';

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
  final _dateFormat = DateFormat('d MMM, h:mm a');
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
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
      _showPayments = false;
      _items.clear();
      _nextCursor = null;
      _hasMore = true;
      _isLoading = false;
    });
    _fetchPage();
  }

  void _togglePayments() {
    setState(() => _showPayments = !_showPayments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Order History',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _togglePayments,
            icon: Icon(
              _showPayments
                  ? Icons.list_rounded
                  : Icons.payments_outlined,
              size: 18,
            ),
            label: Text(_showPayments ? 'Orders' : 'Payments'),
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab chips
          if (!_showPayments)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isSelected = _selectedTab == i;
                  return FilterChip(
                    selected: isSelected,
                    label: Text(_tabs[i].$2),
                    selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF6C63FF),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.6),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                          : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    ),
                    onSelected: (_) => _switchTab(i),
                  );
                },
              ),
            ),
          if (!_showPayments) const SizedBox(height: 8),

          // Payments header
          if (_showPayments)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      color: Color(0xFF6C63FF), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Payment History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE74C3C)),
              ),
            ),

          // List
          Expanded(
            child: _items.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 48,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No orders yet',
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }

  Widget _buildOrderCard(HistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.orderNumber != null)
                Text(
                  '#${item.orderNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              const Spacer(),
              StatusChip(status: item.bucket),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.store_rounded, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.storeName ?? '—',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.customerName ?? '—',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _currencyFormat.format(item.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (item.displayTime != null) ...[
            const SizedBox(height: 6),
            Text(
              _dateFormat.format(item.displayTime!.toLocal()),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCard(HistoryItem item) {
    // Only show items with payment info.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (item.paymentStatus?.toUpperCase() == 'PAID'
                      ? const Color(0xFF27AE60)
                      : const Color(0xFFE67E22))
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.collectionMethod?.toLowerCase() == 'cash'
                  ? Icons.money_rounded
                  : Icons.account_balance_wallet_rounded,
              color: item.paymentStatus?.toUpperCase() == 'PAID'
                  ? const Color(0xFF27AE60)
                  : const Color(0xFFE67E22),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.storeName ?? 'Order',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.collectionMethod ?? item.paymentMode ?? '—'}'
                  '${item.collectedAt != null ? ' • ${_dateFormat.format(item.collectedAt!.toLocal())}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(item.amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
