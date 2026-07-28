import 'package:equatable/equatable.dart';
import '../../../../core/failure.dart';
import '../../../../core/unset.dart';
import '../../data/models/history_item.dart';

class HistoryState extends Equatable {
  final List<HistoryItem> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final Failure? failure;
  final int selectedTab;
  final bool showPayments;

  const HistoryState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoading = false,
    this.failure,
    this.selectedTab = 0,
    this.showPayments = false,
  });

  HistoryState copyWith({
    List<HistoryItem>? items,
    Object? nextCursor = unset,
    bool? hasMore,
    bool? isLoading,
    Object? failure = unset,
    int? selectedTab,
    bool? showPayments,
  }) {
    return HistoryState(
      items: items ?? this.items,
      nextCursor:
          identical(nextCursor, unset) ? this.nextCursor : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, unset) ? this.failure : failure as Failure?,
      selectedTab: selectedTab ?? this.selectedTab,
      showPayments: showPayments ?? this.showPayments,
    );
  }

  @override
  List<Object?> get props => [
        items,
        nextCursor,
        hasMore,
        isLoading,
        failure,
        selectedTab,
        showPayments,
      ];
}
