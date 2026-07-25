import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Floating SOS button — sits above the bottom sheet on job screens and
/// opens the emergency options panel.
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
          color: const Color(0xFFE74C3C),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE74C3C).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.shield_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

/// Opens the emergency options bottom sheet.
Future<void> showEmergencyPanel(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _EmergencyPanel(),
  );
}

Future<void> _call(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

class _EmergencyPanel extends StatelessWidget {
  const _EmergencyPanel();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFFE74C3C)),
                const SizedBox(width: 8),
                const Text(
                  'Emergency',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select an option to get help right away',
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
            _EmergencyOption(
              icon: Icons.medical_services_rounded,
              label: 'Medical Emergency',
              color: const Color(0xFFE74C3C),
              onTap: () => _call('108'),
            ),
            const SizedBox(height: 10),
            _EmergencyOption(
              icon: Icons.local_police_rounded,
              label: 'Police Help',
              color: const Color(0xFF3498DB),
              onTap: () => _call('100'),
            ),
            const SizedBox(height: 10),
            _EmergencyOption(
              icon: Icons.warning_amber_rounded,
              label: 'Accident',
              color: const Color(0xFFE67E22),
              onTap: () => _call('108'),
            ),
            const SizedBox(height: 10),
            _EmergencyOption(
              icon: Icons.two_wheeler_rounded,
              label: 'Vehicle Breakdown',
              color: const Color(0xFF9B59B6),
              onTap: () => _call('1073'),
            ),
            const SizedBox(height: 10),
            _EmergencyOption(
              icon: Icons.support_agent_rounded,
              label: 'Call Support',
              color: const Color(0xFF27AE60),
              onTap: () => _call('18001234567'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _EmergencyOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
