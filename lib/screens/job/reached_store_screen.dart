import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../state/active_order_state.dart';
import '../../widgets/handoff_id_card.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_overlay.dart';

/// Reached-store screen — pickup map, handoff ID, and status-driven
/// action buttons (reached → picked up).
class ReachedStoreScreen extends StatelessWidget {
  const ReachedStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveOrderState>(
      builder: (context, orderState, _) {
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
                    ],
                  ),
                ),

                // Bottom panel
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                          // Store info
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE74C3C)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.store_rounded,
                                  color: Color(0xFFE74C3C),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.storeName ?? 'Store',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (order.orderNumber != null)
                                      Text(
                                        'Order #${order.orderNumber}',
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
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Packing status note
                          if (order.status == 'PACKING') ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.hourglass_top_rounded,
                                    color: Colors.amber,
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
                                        color: Color(0xFFD4A017),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.tag_rounded,
                                    color: Color(0xFF6C63FF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Handoff ID: ${order.pickupToken}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
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
                                    : () async {
                                        final ok =
                                            await orderState.reachedStore();
                                        if (!ok &&
                                            context.mounted &&
                                            orderState.error != null) {
                                          showErrorSnackBar(
                                            context,
                                            orderState.error!,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.location_on_rounded),
                                label: const Text(
                                  'I\'ve Reached the Store',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3498DB),
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
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: orderState.isLoading
                                    ? null
                                    : () async {
                                        final ok =
                                            await orderState.pickedUp();
                                        if (ok && context.mounted) {
                                          context.go('/job/delivery');
                                        }
                                        if (!ok &&
                                            context.mounted &&
                                            orderState.error != null) {
                                          showErrorSnackBar(
                                            context,
                                            orderState.error!,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text(
                                  'Mark Picked Up',
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
}
