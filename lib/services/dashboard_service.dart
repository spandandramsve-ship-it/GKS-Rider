import '../core/api_client.dart';
import '../models/history_item.dart';
import '../models/rider_summary.dart';

/// Dashboard-related API calls (endpoints #16–#17).
class DashboardService {
  final _dio = ApiClient.instance.dio;

  /// #16 GET /rider/orders/history
  /// [status]: ONGOING | COMPLETED | FAILED (omit for all)
  /// [limit]: page size (default 20)
  /// [cursor]: pagination cursor (omit for first page)
  Future<HistoryResponse> getHistory({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;

    final res = await _dio.get(
      '/rider/orders/history',
      queryParameters: params,
    );
    return HistoryResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// #17 GET /rider/summary
  /// [period]: today | week | all
  Future<RiderSummary> getSummary({String period = 'today'}) async {
    final res = await _dio.get(
      '/rider/summary',
      queryParameters: {'period': period},
    );
    return RiderSummary.fromJson(res.data as Map<String, dynamic>);
  }
}
