import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../state/auth_state.dart';
import '../../state/online_state.dart';
import '../../state/active_order_state.dart';
import '../../widgets/loading_overlay.dart';

/// Profile screen — read-only rider info + logout.
///
/// Sensitive PII (Aadhaar, PAN) is masked. Editing is admin-only.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    // Refresh profile data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthState>().refreshProfile();
    });
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    final authState = context.read<AuthState>();
    final onlineState = context.read<OnlineState>();
    final orderState = context.read<ActiveOrderState>();

    // Try to go offline first.
    await onlineState.goOffline();
    orderState.clear();
    await authState.logout();

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        final rider = auth.rider;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.go('/home'),
            ),
            title: const Text(
              'Profile',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            centerTitle: true,
            elevation: 0,
          ),
          body: LoadingOverlay(
            isLoading: _isLoggingOut,
            message: 'Logging out…',
            child: rider == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        // Avatar + name
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              rider.name.isNotEmpty
                                  ? rider.name[0].toUpperCase()
                                  : 'R',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          rider.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(rider.availabilityStatus)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(rider.availabilityStatus),
                            style: TextStyle(
                              color:
                                  _statusColor(rider.availabilityStatus),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Info cards
                        _infoTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: rider.phone,
                        ),
                        _infoTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: rider.email ?? '—',
                        ),
                        if (rider.vehicleNumber != null)
                          _infoTile(
                            icon: Icons.two_wheeler_rounded,
                            label: 'Vehicle',
                            value:
                                '${rider.vehicleType ?? ''} ${rider.vehicleNumber ?? ''}'
                                    .trim(),
                          ),
                        // Masked PII
                        if (rider.aadharNumber != null)
                          _infoTile(
                            icon: Icons.badge_outlined,
                            label: 'Aadhaar',
                            value: _maskPii(rider.aadharNumber!),
                          ),
                        if (rider.panNumber != null)
                          _infoTile(
                            icon: Icons.credit_card_outlined,
                            label: 'PAN',
                            value: _maskPii(rider.panNumber!),
                          ),
                        _infoTile(
                          icon: Icons.verified_outlined,
                          label: 'Verified',
                          value: rider.isVerified == true ? 'Yes' : 'No',
                        ),

                        const SizedBox(height: 32),

                        // Logout
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoggingOut ? null : _logout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE74C3C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Profile changes can only be made by an admin.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mask PII: show last 4 digits only.
  String _maskPii(String value) {
    if (value.length <= 4) return '••••';
    return '${'•' * (value.length - 4)}${value.substring(value.length - 4)}';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active-free':
        return const Color(0xFF27AE60);
      case 'active-busy':
        return const Color(0xFFE67E22);
      case 'offline':
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active-free':
        return 'Online — Free';
      case 'active-busy':
        return 'Online — Busy';
      case 'offline':
        return 'Offline';
      default:
        return status ?? 'Unknown';
    }
  }
}
