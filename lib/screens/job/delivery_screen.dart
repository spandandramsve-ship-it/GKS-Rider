import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/active_order_state.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_overlay.dart';

/// Delivery screen — customer map, call, payment panel (COD), delivery-code entry.
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _codeCtrl = TextEditingController();
  bool _showCodeEntry = false;
  bool _otpRequested = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _callCustomer(String phone) async {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveOrderState>(
      builder: (context, orderState, _) {
        final order = orderState.order;

        if (order == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/home');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If not picked up yet, go to store screen.
        if (order.status != 'PICKED_UP' && order.status != 'DELIVERED') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/job/store');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Delivered success.
        if (order.status == 'DELIVERED') {
          return _buildDeliveredSuccess(context, orderState);
        }

        final deliveryLatLng = order.delivery?.location?.toLatLng() ??
            const LatLng(19.0760, 72.8777);
        final isCod = order.payment?.isCod ?? false;
        final isPaid = order.isPaymentSettled;
        // Can enter delivery code if ONLINE or COD paid.
        final canEnterCode = !isCod || isPaid || orderState.canCompleteDelivery;

        return Scaffold(
          body: LoadingOverlay(
            isLoading: orderState.isLoading,
            child: Column(
              children: [
                // Map
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: deliveryLatLng,
                          initialZoom: 15,
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
                                point: deliveryLatLng,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFF27AE60),
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: Colors.black87,
                            ),
                            onPressed: () => context.go('/home'),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        right: 12,
                        child: StatusChip(status: order.status),
                      ),
                    ],
                  ),
                ),

                // Bottom panel
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer info
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27AE60)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF27AE60),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Deliver to ${order.customerName ?? 'Customer'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (order.delivery != null)
                                      Text(
                                        order.delivery!.displayAddress,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.6),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Action buttons: Call + Open in Maps
                          Row(
                            children: [
                              if (order.customerPhone != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _callCustomer(order.customerPhone!),
                                    icon: const Icon(Icons.call_rounded,
                                        size: 18),
                                    label: const Text('Call'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF27AE60),
                                      side: const BorderSide(
                                        color: Color(0xFF27AE60),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              if (order.customerPhone != null)
                                const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openInMaps(
                                    deliveryLatLng.latitude,
                                    deliveryLatLng.longitude,
                                  ),
                                  icon: const Icon(Icons.map_rounded,
                                      size: 18),
                                  label: const Text('Navigate'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF3498DB),
                                    side: const BorderSide(
                                      color: Color(0xFF3498DB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // COD Payment Panel
                          if (isCod && !isPaid && !orderState.canCompleteDelivery) ...[
                            _buildPaymentPanel(context, orderState),
                            const SizedBox(height: 18),
                          ],

                          // COD paid indicator
                          if (isCod && (isPaid || orderState.canCompleteDelivery)) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF27AE60)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF27AE60), size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Payment collected ✓',
                                    style: TextStyle(
                                      color: Color(0xFF27AE60),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Delivery code entry
                          if (canEnterCode) ...[
                            _buildDeliveryCodeEntry(context, orderState),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentPanel(
    BuildContext context,
    ActiveOrderState orderState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE67E22).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE67E22).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined,
                  color: Color(0xFFE67E22), size: 20),
              SizedBox(width: 8),
              Text(
                'Collect Payment (COD)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE67E22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: orderState.isLoading
                      ? null
                      : () async {
                          final ok = await orderState.collectCash();
                          if (!ok &&
                              context.mounted &&
                              orderState.error != null) {
                            showErrorSnackBar(context, orderState.error!);
                          }
                        },
                  icon: const Icon(Icons.money_rounded, size: 18),
                  label: const Text('Cash'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: orderState.isLoading
                      ? null
                      : () => context.push('/job/payment-qr'),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('UPI QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCodeEntry(
    BuildContext context,
    ActiveOrderState orderState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pin_rounded, color: Color(0xFF6C63FF), size: 20),
              SizedBox(width: 8),
              Text(
                'Delivery Code',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ask the customer to read their delivery code aloud',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),

          // Request delivery OTP button (optional)
          if (!_otpRequested && !_showCodeEntry)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final msg = await orderState.requestDeliveryOtp();
                  if (context.mounted && msg != null) {
                    showSuccessSnackBar(context, msg);
                  }
                  setState(() {
                    _otpRequested = true;
                    _showCodeEntry = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Request & Enter Code'),
              ),
            ),

          if (_showCodeEntry || _otpRequested) ...[
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • • • •',
                hintStyle: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.3),
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: orderState.isLoading
                    ? null
                    : () async {
                        final code = _codeCtrl.text.trim();
                        if (code.length != 6) {
                          showErrorSnackBar(
                            context,
                            'Enter the full 6-digit delivery code',
                          );
                          return;
                        }
                        final ok = await orderState.completeDelivery(code);
                        if (!ok &&
                            context.mounted &&
                            orderState.error != null) {
                          showErrorSnackBar(context, orderState.error!);
                        }
                        // If success, the Consumer will show DELIVERED state.
                      },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'Confirm Delivery',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveredSuccess(
    BuildContext context,
    ActiveOrderState orderState,
  ) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF27AE60),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Delivered!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order delivered successfully',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        orderState.fetchActiveOrder();
                        context.go('/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
