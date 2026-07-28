import 'package:latlong2/latlong.dart';

/// Converts a GeoJSON `[longitude, latitude]` coordinate pair to
/// a [LatLng] usable by flutter_map and other mapping widgets.
///
/// The backend always sends coordinates as GeoJSON `[lng, lat]`.
/// We always flip to `LatLng(lat, lng)` before display.
class GeoPoint {
  final double longitude;
  final double latitude;

  const GeoPoint({required this.longitude, required this.latitude});

  /// Parse from a GeoJSON `coordinates` array: `[lng, lat]`.
  factory GeoPoint.fromGeoJson(List<dynamic> coords) {
    return GeoPoint(
      longitude: (coords[0] as num).toDouble(),
      latitude: (coords[1] as num).toDouble(),
    );
  }

  /// Convert to [LatLng] for mapping (note the flip).
  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {'lat': latitude, 'lng': longitude};
}
