import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../widgets/status_chip.dart';
import '../../../../widgets/error_banner.dart';
import '../../../../widgets/loading_overlay.dart';
import '../../../../widgets/emergency_sos.dart';
import '../../../../widgets/quick_message_sheet.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';

const _cardGrey = Color(0xFFD9D9D9);
const _outlineGrey = Color(0xFFB3B3B3);

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
    return MultiBlocListener(
      listeners: [
        BlocListener<OrderBloc, OrderState>(
          listenWhen: (previous, current) =>
              previous.isLoading &&
              !current.isLoading &&
              current.failure != null,
          listener: (context, state) =>
              showErrorSnackBar(context, state.failure!.message),
        ),
        BlocListener<OrderBloc, OrderState>(
          listenWhen: (previous, current) =>
              current.deliveryOtpMessage != null &&
              current.deliveryOtpMessage != previous.deliveryOtpMessage,
          listener: (context, state) =>
              showSuccessSnackBar(context, state.deliveryOtpMessage!.message),
        ),
      ],
      child: BlocBuilder<OrderBloc, OrderState>(
        builder: (context, orderState) {
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
          final canEnterCode =
              !isCod || isPaid || orderState.canCompleteDelivery;

          return Scaffold(
            backgroundColor: Colors.white,
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
                                    color: Color(0xFFE74C3C),
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
                        const Positioned(
                          bottom: 16,
                          right: 16,
                          child: EmergencySosButton(),
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
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 12,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Active order badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _cardGrey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Active Order',
                                style: TextStyle(fontSize: 12, color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Customer info
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Deliver to',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.black),
                                      ),
                                      Text(
                                        order.customerName ?? 'Customer',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (order.delivery != null)
                                        Text(
                                          order.delivery!.displayAddress,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
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

                            // Navigate — full width
                            _outlineButton(
                              icon: Icons.map_rounded,
                              label: 'Navigate',
                              fullWidth: true,
                              onTap: () => _openInMaps(
                                deliveryLatLng.latitude,
                                deliveryLatLng.longitude,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Call + Chat
                            Row(
                              children: [
                                if (order.customerPhone != null)
                                  Expanded(
                                    child: _outlineButton(
                                      icon: Icons.call_rounded,
                                      label: 'Call',
                                      onTap: () =>
                                          _callCustomer(order.customerPhone!),
                                    ),
                                  ),
                                if (order.customerPhone != null)
                                  const SizedBox(width: 10),
                                Expanded(
                                  child: _outlineButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: 'Chat',
                                    onTap: () => showQuickMessageSheet(
                                      context,
                                      phone: order.customerPhone,
                                      recipientLabel:
                                          order.customerName ?? 'Customer',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // COD Payment Panel
                            if (isCod &&
                                !isPaid &&
                                !orderState.canCompleteDelivery) ...[
                              _buildPaymentPanel(context, orderState),
                              const SizedBox(height: 18),
                            ],

                            // COD paid indicator
                            if (isCod &&
                                (isPaid || orderState.canCompleteDelivery)) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _cardGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: Colors.black, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'Payment collected',
                                      style: TextStyle(
                                        color: Colors.black,
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
      ),
    );
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
        icon: Icon(icon, size: 16, color: Colors.black),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
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
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildPaymentPanel(
    BuildContext context,
    OrderState orderState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Text(
                'Collect Payment (COD)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _pillButton(
                  icon: Icons.money_rounded,
                  label: 'Cash',
                  onTap: orderState.isLoading
                      ? null
                      : () => context
                          .read<OrderBloc>()
                          .add(const OrderCollectCashRequested()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pillButton(
                  icon: Icons.qr_code_2_rounded,
                  label: 'UPI QR',
                  onTap: orderState.isLoading
                      ? null
                      : () => context.push('/job/payment-qr'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _outlineGrey),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCodeEntry(
    BuildContext context,
    OrderState orderState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4B4A4A), style: BorderStyle.solid),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Enter the OTP:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask the customer to read their delivery code aloud',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),

          // Request delivery OTP button (optional)
          if (!_otpRequested && !_showCodeEntry)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  context
                      .read<OrderBloc>()
                      .add(const OrderDeliveryOtpRequested());
                  setState(() {
                    _otpRequested = true;
                    _showCodeEntry = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: _outlineGrey),
                  backgroundColor: Colors.white,
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
                color: Colors.black,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '- - - - - -',
                hintStyle: TextStyle(
                  color: Colors.black.withValues(alpha: 0.3),
                  letterSpacing: 8,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _outlineGrey),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: orderState.isLoading
                    ? null
                    : () {
                        final code = _codeCtrl.text.trim();
                        if (code.length != 6) {
                          showErrorSnackBar(
                            context,
                            'Enter the full 6-digit delivery code',
                          );
                          return;
                        }
                        context
                            .read<OrderBloc>()
                            .add(OrderCompleteDeliveryRequested(code));
                        // If success, the BlocBuilder will show DELIVERED state.
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF888888),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
    OrderState orderState,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: _cardGrey,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.black,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Delivered!',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order delivered successfully',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.6),
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
                      context.read<OrderBloc>().add(const OrderActiveRequested());
                      context.go('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
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
    );
  }
}
