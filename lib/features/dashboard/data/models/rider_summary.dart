/// Summary stats from `GET /rider/summary?period=today|week|all`.
class RiderSummary {
  final int completedDeliveries;
  final double cashCollected;
  final double onlinePayments;
  final double distanceTravelledKm;
  final int ordersInProgress;

  const RiderSummary({
    required this.completedDeliveries,
    required this.cashCollected,
    required this.onlinePayments,
    required this.distanceTravelledKm,
    required this.ordersInProgress,
  });

  factory RiderSummary.fromJson(Map<String, dynamic> json) {
    return RiderSummary(
      completedDeliveries:
          (json['completedDeliveries'] as num?)?.toInt() ?? 0,
      cashCollected:
          (json['cashCollected'] as num?)?.toDouble() ?? 0,
      onlinePayments:
          (json['onlinePayments'] as num?)?.toDouble() ?? 0,
      distanceTravelledKm:
          (json['distanceTravelledKm'] as num?)?.toDouble() ?? 0,
      ordersInProgress:
          (json['ordersInProgress'] as num?)?.toInt() ?? 0,
    );
  }
}
