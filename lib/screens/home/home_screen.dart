import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../state/auth_state.dart';
import '../../state/online_state.dart';
import '../../state/active_order_state.dart';
import '../../widgets/summary_tile.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_overlay.dart';

/// Home screen — online/offline toggle, current job card, today's summary.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial data load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnlineState>().fetchSummary();
      context.read<ActiveOrderState>().fetchActiveOrder();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconcile on app resume — mandatory per §6.
      context.read<ActiveOrderState>().fetchActiveOrder();
      context.read<OnlineState>().fetchSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthState, OnlineState, ActiveOrderState>(
      builder: (context, auth, online, orderState, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: LoadingOverlay(
            isLoading: online.isLoading,
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  await orderState.fetchActiveOrder();
                  await online.fetchSummary();
                },
                child: CustomScrollView(
                  slivers: [
                    // Header
                    SliverToBoxAdapter(child: _buildHeader(auth, online)),

                    // Online toggle
                    SliverToBoxAdapter(
                      child: _buildOnlineToggle(online, orderState),
                    ),

                    // Active job card
                    if (orderState.hasOrder)
                      SliverToBoxAdapter(
                        child: _buildJobCard(orderState),
                      ),

                    // Waiting message
                    if (!orderState.hasOrder && online.isOnline)
                      SliverToBoxAdapter(child: _buildWaitingCard()),

                    // Summary tiles
                    SliverToBoxAdapter(child: _buildSummary(online)),

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNav(context),
        );
      },
    );
  }

  Widget _buildHeader(AuthState auth, OnlineState online) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.delivery_dining_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${auth.rider?.name ?? 'Rider'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online.isOnline
                            ? const Color(0xFF27AE60)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        color: online.isOnline
                            ? const Color(0xFF27AE60)
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle(OnlineState online, ActiveOrderState orderState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: online.isOnline
                ? [const Color(0xFF27AE60), const Color(0xFF2ECC71)]
                : [const Color(0xFF2C3E50), const Color(0xFF34495E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (online.isOnline
                      ? const Color(0xFF27AE60)
                      : const Color(0xFF2C3E50))
                  .withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online.isOnline
                        ? 'You\'re Online'
                        : 'You\'re Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    online.isOnline
                        ? 'Ready to receive orders'
                        : 'Go online to start delivering',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 1.2,
              child: Switch(
                value: online.isOnline,
                onChanged: online.isLoading
                    ? null
                    : (val) async {
                        if (val) {
                          final ok = await online.goOnline();
                          if (ok && mounted) {
                            await orderState.fetchActiveOrder();
                          }
                          if (!ok && mounted && online.error != null) {
                            showErrorSnackBar(context, online.error!);
                          }
                        } else {
                          final ok = await online.goOffline();
                          if (!ok && mounted && online.error != null) {
                            showErrorSnackBar(context, online.error!);
                          }
                        }
                      },
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 40,
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 12),
            const Text(
              'Waiting for an order...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You\'ll be notified when one is assigned',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(ActiveOrderState orderState) {
    final order = orderState.order!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () => _navigateToJob(order.status),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_rounded,
                    color: Color(0xFF6C63FF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 14),
              if (order.orderNumber != null)
                Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.store_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.storeName ?? 'Store',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (order.customerName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Deliver to ${order.customerName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToJob(order.status),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _jobButtonLabel(order.status),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToJob(String status) {
    switch (status.toUpperCase()) {
      case 'PACKING':
      case 'PACKED':
      case 'REACHED_STORE':
        context.push('/job/store');
        break;
      case 'PICKED_UP':
        context.push('/job/delivery');
        break;
      case 'DELIVERED':
        // Delivered — just refetch, order will be null soon.
        context.read<ActiveOrderState>().fetchActiveOrder();
        break;
      default:
        context.push('/job/store');
    }
  }

  String _jobButtonLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PACKING':
      case 'PACKED':
        return 'Navigate to Store';
      case 'REACHED_STORE':
        return 'Collect Order';
      case 'PICKED_UP':
        return 'Complete Delivery';
      case 'DELIVERED':
        return 'View Summary';
      default:
        return 'View Order';
    }
  }

  Widget _buildSummary(OnlineState online) {
    final summary = online.summary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              SummaryTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'Deliveries',
                value: '${summary?.completedDeliveries ?? 0}',
                iconColor: const Color(0xFF27AE60),
              ),
              SummaryTile(
                icon: Icons.payments_outlined,
                label: 'Cash Collected',
                value: summary != null
                    ? _currencyFormat.format(summary.cashCollected)
                    : '₹0',
                iconColor: const Color(0xFFE67E22),
              ),
              SummaryTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Online Payments',
                value: summary != null
                    ? _currencyFormat.format(summary.onlinePayments)
                    : '₹0',
                iconColor: const Color(0xFF3498DB),
              ),
              SummaryTile(
                icon: Icons.route_rounded,
                label: 'Distance',
                value: summary != null && summary.distanceTravelledKm > 0
                    ? '${summary.distanceTravelledKm.toStringAsFixed(1)} km'
                    : '—',
                iconColor: const Color(0xFF9B59B6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF6C63FF),
      unselectedItemColor: Colors.grey,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      onTap: (i) {
        switch (i) {
          case 0:
            break; // Already on home
          case 1:
            context.push('/history');
            break;
          case 2:
            context.push('/profile');
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}
