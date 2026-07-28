import 'geo_point.dart';

/// Delivery address with coordinates and optional customer block info.
class DeliveryAddress {
  final String? fullAddress;
  final String? area;
  final String? city;
  final String? pincode;
  final String? landmark;
  final GeoPoint? location;

  const DeliveryAddress({
    this.fullAddress,
    this.area,
    this.city,
    this.pincode,
    this.landmark,
    this.location,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    GeoPoint? loc;
    final locData = json['location'];
    if (locData is Map<String, dynamic>) {
      final coords = locData['coordinates'];
      if (coords is List && coords.length >= 2) {
        loc = GeoPoint.fromGeoJson(coords);
      }
    }

    return DeliveryAddress(
      fullAddress: json['fullAddress'] as String? ?? json['address'] as String?,
      area: json['area'] as String?,
      city: json['city'] as String?,
      pincode: json['pincode'] as String?,
      landmark: json['landmark'] as String?,
      location: loc,
    );
  }

  /// Human-readable single-line address.
  String get displayAddress {
    final parts = [fullAddress, area, landmark, city, pincode]
        .where((s) => s != null && s.isNotEmpty);
    return parts.join(', ');
  }
}
