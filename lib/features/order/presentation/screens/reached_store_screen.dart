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
import '../widgets/handoff_id_card.dart';

const _cardGrey = Color(0xFFD9D9D9);
const _outlineGrey = Color(0xFFB3B3B3);

/// Reached-store screen — pickup map, handoff ID, and status-driven
/// action buttons (reached → picked up).
class ReachedStoreScreen extends StatelessWidget {
  const ReachedStoreScreen({super.key});

  Future<void> _callStore(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderBloc, OrderState>(
      listenWhen: (previous, current) =>
          previous.isLoading && !current.isLoading && current.failure != null,
      listener: (context, state) =>
          showErrorSnackBar(context, state.failure!.message),
      child: BlocBuilder<OrderBloc, OrderState>(
        builder: (context, orderState) {
          final order = orderState.order;

          // If no order or it's past pickup, redirect.
          if (order == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If picked up, navigate to delivery.
          if (order.status == 'PICKED_UP') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/job/delivery');
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If delivered, go home.
          if (order.status == 'DELIVERED') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final storeLatLng = order.storeLocation?.toLatLng() ??
              const LatLng(19.0760, 72.8777); // fallback Mumbai
          final isReached = order.status == 'REACHED_STORE';

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
                            initialCenter: storeLatLng,
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
                                  point: storeLatLng,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.store_rounded,
                                    color: Color(0xFFE74C3C),
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Back button
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
                        // Status badge
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
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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

                            // Store info
                            Row(
                              children: [
                                const Icon(Icons.store_rounded,
                                    size: 20, color: Colors.black87),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.storeName ?? 'Store',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (order.orderNumber != null)
                                        Text(
                                          'Order #${order.orderNumber}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Call + Chat
                            Row(
                              children: [
                                if (order.storePhone != null)
                                  Expanded(
                                    child: _outlineButton(
                                      icon: Icons.call_rounded,
                                      label: 'Call',
                                      onTap: () =>
                                          _callStore(order.storePhone!),
                                    ),
                                  ),
                                if (order.storePhone != null)
                                  const SizedBox(width: 10),
                                Expanded(
                                  child: _outlineButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    label: 'Chat',
                                    onTap: () => showQuickMessageSheet(
                                      context,
                                      phone: order.storePhone,
                                      recipientLabel:
                                          order.storeName ?? 'Store',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Packing status note
                            if (order.status == 'PACKING') ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _cardGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.hourglass_top_rounded,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        order.packingEtaMinutes != null
                                            ? 'Store is packing — ~${order.packingEtaMinutes} min'
                                            : 'Store is still packing your order',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Handoff ID card (when at store)
                            if (isReached && order.pickupToken != null) ...[
                              HandoffIdCard(pickupToken: order.pickupToken!),
                              const SizedBox(height: 16),
                            ],

                            // Pickup token preview (before reaching)
                            if (!isReached && order.pickupToken != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _cardGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.tag_rounded,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Handoff ID: ${order.pickupToken}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Action button
                            if (!isReached) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: orderState.isLoading
                                      ? null
                                      : () => context.read<OrderBloc>().add(
                                            const OrderReachedStoreRequested(),
                                          ),
                                  icon: const Icon(Icons.location_on_rounded),
                                  label: const Text(
                                    'I\'ve Reached the Store',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],

                            if (isReached) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Quote the handoff ID to the store, collect the bag, then mark picked up.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: orderState.isLoading
                                      ? null
                                      : () => context.read<OrderBloc>().add(
                                            const OrderPickedUpRequested(),
                                          ),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text(
                                    'Mark Picked Up',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
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
}
