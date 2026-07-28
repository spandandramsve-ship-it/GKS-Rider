import '../../../core/api_client.dart';
import 'models/history_item.dart';

/// GET /rider/orders/history — split out of the old combined
/// `DashboardService` since it's an unrelated endpoint/model from the
/// rider-summary one (now `DashboardRepository.getSummary`).
class HistoryRepository {
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

    final res = await ApiClient.instance.dio.get(
      '/rider/orders/history',
      queryParameters: params,
    );
    return HistoryResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
