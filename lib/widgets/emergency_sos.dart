import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Floating SOS button — sits above the bottom sheet on job screens and
/// opens a radial menu of emergency options.
class EmergencySosButton extends StatelessWidget {
  const EmergencySosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showEmergencyPanel(context),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF9E9E9E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.shield_rounded,
          color: Colors.black87,
          size: 26,
        ),
      ),
    );
  }
}

/// Opens the emergency options radial menu, anchored where the SOS
/// button sits (bottom-right), over a dimmed/blurred backdrop.
Future<void> showEmergencyPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Emergency',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => const _EmergencyOverlay(),
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Future<void> _call(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

class _EmergencyOverlay extends StatelessWidget {
  const _EmergencyOverlay();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: const Color(0x803B3B3B),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  right: 20,
                  bottom: 90,
                  child: GestureDetector(
                    onTap: () {}, // absorb taps on the menu itself
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _EmergencyPill(
                          icon: Icons.medical_services_rounded,
                          label: 'Medical Emergency',
                          onTap: () => _call('108'),
                        ),
                        const SizedBox(height: 10),
                        _EmergencyPill(
                          icon: Icons.local_police_rounded,
                          label: 'Police Help',
                          onTap: () => _call('100'),
                        ),
                        const SizedBox(height: 10),
                        _EmergencyPill(
                          icon: Icons.warning_amber_rounded,
                          label: 'Accident',
                          onTap: () => _call('108'),
                        ),
                        const SizedBox(height: 10),
                        _EmergencyPill(
                          icon: Icons.two_wheeler_rounded,
                          label: 'Vehicle Breakdown',
                          onTap: () => _call('1073'),
                        ),
                        const SizedBox(height: 10),
                        _EmergencyPill(
                          icon: Icons.support_agent_rounded,
                          label: 'Call Support',
                          onTap: () => _call('18001234567'),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Color(0xFF9E9E9E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.black87,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
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

class _EmergencyPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _EmergencyPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF010101),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
