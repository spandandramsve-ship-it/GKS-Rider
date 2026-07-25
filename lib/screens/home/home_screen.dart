import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/auth_state.dart';
import '../../state/online_state.dart';
import '../../state/active_order_state.dart';
import '../../widgets/summary_tile.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/emergency_sos.dart';
import '../../widgets/quick_message_sheet.dart';
import '../../widgets/rider_bottom_nav.dart';

const _cardGrey = Color(0xFFD9D9D9);
const _outlineGrey = Color(0xFFB3B3B3);

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

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthState, OnlineState, ActiveOrderState>(
      builder: (context, auth, online, orderState, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: LoadingOverlay(
            isLoading: online.isLoading,
            child: SafeArea(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      await orderState.fetchActiveOrder();
                      await online.fetchSummary();
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader(auth)),
                        SliverToBoxAdapter(
                          child: _buildShiftCard(online),
                        ),
                        SliverToBoxAdapter(
                          child: orderState.hasOrder
                              ? _buildJobCard(orderState)
                              : _buildNoOrderCard(online),
                        ),
                        SliverToBoxAdapter(child: _buildSummary(online)),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
                  if (orderState.hasOrder)
                    const Positioned(
                      bottom: 16,
                      right: 20,
                      child: EmergencySosButton(),
                    ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const RiderBottomNav(isHistorySelected: false),
        );
      },
    );
  }

  Widget _buildHeader(AuthState auth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black, size: 26),
            onPressed: () => context.push('/profile'),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: const TextStyle(fontSize: 10, color: Colors.black),
              ),
              Text(
                auth.rider?.name.split(' ').first ?? 'Rider',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(OnlineState online) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardGrey.withValues(alpha: 0.3),
          border: Border.all(color: _cardGrey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFBDBDBD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Shift',
                    style: TextStyle(fontSize: 12, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    online.isOnline ? 'You are Online' : 'You are Offline',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    online.isOnline ? 'You are on Duty' : 'Go online to start',
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ],
              ),
            ),
            Switch(
              value: online.isOnline,
              onChanged: online.isLoading
                  ? null
                  : (val) async {
                      if (val) {
                        final ok = await online.goOnline();
                        if (ok && mounted) {
                          await context
                              .read<ActiveOrderState>()
                              .fetchActiveOrder();
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
              activeTrackColor: Colors.black,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: _outlineGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOrderCard(OnlineState online) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.black87,
                size: 24,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              online.isOnline
                  ? 'You don\'t have any active orders right now.\nNew pickup requests will appear here.'
                  : 'Go online to start receiving pickup requests.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                border: Border.all(color: const Color(0xFFD9D9D9)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stay Ready!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          'We will notify you as soon as a new order is assigned',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(ActiveOrderState orderState) {
    final order = orderState.order!;
    final beforePickup = order.status != 'PICKED_UP' && order.status != 'DELIVERED';
    final destination = beforePickup
        ? order.storeLocation?.toLatLng()
        : order.delivery?.location?.toLatLng();
    final phone = beforePickup ? order.storePhone : order.customerPhone;
    final contactLabel = beforePickup
        ? (order.storeName ?? 'Store')
        : (order.customerName ?? 'Customer');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _cardGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Active Order',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (order.orderNumber != null)
                          Text(
                            'Order #${order.orderNumber}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.store_rounded,
                                size: 17, color: Colors.black87),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order.storeName ?? 'Store',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusLine(order.status),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (order.customerName != null) ...[
                          const Text(
                            'Deliver to',
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                          Text(
                            order.customerName!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildMiniMap(destination),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _outlineButton(
              icon: Icons.map_rounded,
              label: 'Navigate',
              fullWidth: true,
              onTap: destination == null
                  ? null
                  : () => _openInMaps(destination.latitude, destination.longitude),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _outlineButton(
                    icon: Icons.call_rounded,
                    label: 'Call',
                    onTap: phone == null ? null : () => _callNumber(phone),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _outlineButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                    onTap: () => showQuickMessageSheet(
                      context,
                      phone: phone,
                      recipientLabel: contactLabel,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _outlineButton(
              icon: Icons.check_circle_outline_rounded,
              label: _jobButtonLabel(order.status),
              fullWidth: true,
              onTap: () => _navigateToJob(order.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMap(LatLng? destination) {
    final center = destination ?? const LatLng(19.0760, 72.8777);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 130,
        height: 150,
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gks.rider',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFE74C3C),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLine(String status) {
    switch (status.toUpperCase()) {
      case 'PACKING':
        return 'Store is packing';
      case 'PACKED':
        return 'Ready for pickup';
      case 'REACHED_STORE':
        return 'At store';
      case 'PICKED_UP':
        return 'Pickup Complete';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return status;
    }
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: Colors.black),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: _outlineGrey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        return 'Arrived at location';
      case 'DELIVERED':
        return 'View Summary';
      default:
        return 'View Order';
    }
  }

  static const _summaryPeriods = [
    ('today', 'Today'),
    ('week', 'This Week'),
    ('all', 'All Time'),
  ];

  String _summaryTitle(String period) {
    switch (period) {
      case 'week':
        return 'This Week\'s Summary';
      case 'all':
        return 'All Time Summary';
      case 'today':
      default:
        return 'Today\'s Summary';
    }
  }

  Widget _buildSummary(OnlineState online) {
    final summary = online.summary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _summaryTitle(online.summaryPeriod),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                initialValue: online.summaryPeriod,
                onSelected: (value) => online.fetchSummary(period: value),
                itemBuilder: (_) => [
                  for (final (value, label) in _summaryPeriods)
                    PopupMenuItem(value: value, child: Text(label)),
                ],
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 143,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SummaryTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Completed\nDeliveries',
                  value: '${summary?.completedDeliveries ?? 0}',
                ),
                const SizedBox(width: 10),
                SummaryTile(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Cash\nCollected',
                  value: summary != null
                      ? _currencyFormat.format(summary.cashCollected)
                      : '₹0',
                ),
                const SizedBox(width: 10),
                SummaryTile(
                  icon: Icons.description_outlined,
                  label: 'Online\nPayments',
                  value: summary != null
                      ? _currencyFormat.format(summary.onlinePayments)
                      : '₹0',
                ),
                const SizedBox(width: 10),
                SummaryTile(
                  icon: Icons.route_rounded,
                  label: 'Distance\nTravelled',
                  value: summary != null && summary.distanceTravelledKm > 0
                      ? summary.distanceTravelledKm.toStringAsFixed(1)
                      : '—',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
