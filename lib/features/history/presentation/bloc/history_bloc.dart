import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api_client.dart';
import '../../../../core/failure.dart';
import '../../data/history_repository.dart';
import 'history_event.dart';
import 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final HistoryRepository _repository;

  String? _currentStatus;

  HistoryBloc({HistoryRepository? repository})
      : _repository = repository ?? HistoryRepository(),
        super(const HistoryState()) {
    // restartable(): switching tabs cancels any in-flight fetch for the
    // previously selected tab, so a stale response can never land on top
    // of the newly selected (and possibly still-empty) tab's list.
    on<HistoryTabChanged>(_onTabChanged, transformer: restartable());
    // droppable(): scroll-triggered pagination ignores a new request while
    // one is already in flight (equivalent to the old `if (_isLoading)
    // return;` guard).
    on<HistoryPageRequested>(_onPageRequested, transformer: droppable());
    on<HistoryPaymentsViewToggled>((event, emit) {
      if (event.showPayments == state.showPayments) return;
      emit(state.copyWith(showPayments: event.showPayments));
    });
  }

  Future<void> _onTabChanged(
    HistoryTabChanged event,
    Emitter<HistoryState> emit,
  ) async {
    _currentStatus = event.status;
    emit(state.copyWith(
      selectedTab: event.tabIndex,
      showPayments: false,
      items: const [],
      nextCursor: null,
      hasMore: true,
      isLoading: true,
      failure: null,
    ));
    await _fetchPage(emit);
  }

  Future<void> _onPageRequested(
    HistoryPageRequested event,
    Emitter<HistoryState> emit,
  ) async {
    if (!state.hasMore || state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    await _fetchPage(emit);
  }

  Future<void> _fetchPage(Emitter<HistoryState> emit) async {
    try {
      final res = await _repository.getHistory(
        status: _currentStatus,
        cursor: state.nextCursor,
      );
      emit(state.copyWith(
        items: [...state.items, ...res.orders],
        nextCursor: res.pagination.nextCursor,
        hasMore: res.pagination.hasMore,
        isLoading: false,
        failure: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: Failure(extractApiException(e).message),
      ));
    }
  }
}
