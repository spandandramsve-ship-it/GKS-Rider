import '../../../core/api_client.dart';
import '../../../core/location_service.dart';
import '../../auth/data/auth_repository.dart';
import 'models/rider_summary.dart';

/// Wraps the rider-summary endpoint and the go-online/go-offline flows.
///
/// `goOffline()` is delegated to [AuthRepository] since it's the same
/// `/rider/auth/offline` endpoint the auth feature's logout flow also hits
/// (mirrors the original `OnlineState`/`AuthState` coupling).
class DashboardRepository {
  final AuthRepository _authRepository;

  DashboardRepository({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  Future<RiderSummary> getSummary({String period = 'today'}) async {
    final res = await ApiClient.instance.dio.get(
      '/rider/summary',
      queryParameters: {'period': period},
    );
    return RiderSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// Posts current GPS location to go online. Returns `true` on success.
  Future<bool> goOnline() => LocationService.instance.postGoOnline();

  Future<void> goOffline() async {
    await _authRepository.goOffline();
    LocationService.instance.stopTracking();
  }
}
