import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Floating pill-shaped Home/History bottom nav shared by the Home and
/// History screens, matching the Figma nav bar.
class RiderBottomNav extends StatelessWidget {
  final bool isHistorySelected;

  const RiderBottomNav({super.key, required this.isHistorySelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 20),
      child: Container(
        height: 55,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAEA),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: !isHistorySelected,
                onTap: () {
                  if (isHistorySelected) context.go('/home');
                },
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.history_rounded,
                label: 'History',
                selected: isHistorySelected,
                onTap: () {
                  if (!isHistorySelected) context.push('/history');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: selected ? Colors.black87 : Colors.black.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.black87 : Colors.black.withValues(alpha: 0.6),
          ),
        ),
      ],
    );

    if (!selected) {
      return InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: content,
    );
  }
}
