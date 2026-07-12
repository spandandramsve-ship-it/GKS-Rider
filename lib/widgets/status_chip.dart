import 'package:flutter/material.dart';

/// Color-coded order status badge.
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static (Color, String) _statusStyle(String status) {
    switch (status.toUpperCase()) {
      case 'PACKING':
        return (const Color(0xFFE67E22), 'Packing');
      case 'PACKED':
        return (const Color(0xFFF39C12), 'Packed');
      case 'REACHED_STORE':
        return (const Color(0xFF3498DB), 'At Store');
      case 'PICKED_UP':
        return (const Color(0xFF9B59B6), 'Picked Up');
      case 'DELIVERED':
        return (const Color(0xFF27AE60), 'Delivered');
      case 'CANCELLED':
      case 'FAILED':
        return (const Color(0xFFE74C3C), 'Failed');
      case 'ONGOING':
        return (const Color(0xFFE67E22), 'Ongoing');
      case 'COMPLETED':
        return (const Color(0xFF27AE60), 'Completed');
      default:
        return (Colors.grey, status);
    }
  }

  /// Returns the color for a bucket (used in history).
  static Color bucketColor(String bucket) {
    switch (bucket.toUpperCase()) {
      case 'ONGOING':
        return const Color(0xFFE67E22);
      case 'COMPLETED':
        return const Color(0xFF27AE60);
      case 'FAILED':
        return (const Color(0xFFE74C3C));
      default:
        return Colors.grey;
    }
  }
}
