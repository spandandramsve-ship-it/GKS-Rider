import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api_client.dart';
import '../../../../core/failure.dart';
import '../../data/dashboard_repository.dart';
import 'online_event.dart';
import 'online_state.dart';

class OnlineBloc extends Bloc<OnlineEvent, OnlineState> {
  final DashboardRepository _repository;

  OnlineBloc({DashboardRepository? repository})
      : _repository = repository ?? DashboardRepository(),
        super(const OnlineState()) {
    on<OnlineGoOnlineRequested>(_onGoOnlineRequested, transformer: droppable());
    on<OnlineGoOfflineRequested>(_onGoOfflineRequested, transformer: droppable());
    on<OnlineSummaryRequested>(_onSummaryRequested, transformer: droppable());
    on<OnlineStatusChanged>(
      (event, emit) => emit(state.copyWith(isOnline: event.isOnline)),
    );
    on<OnlineErrorCleared>(
      (event, emit) => emit(state.copyWith(failure: null)),
    );
  }

  Future<void> _onGoOnlineRequested(
    OnlineGoOnlineRequested event,
    Emitter<OnlineState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      final ok = await _repository.goOnline();
      if (!ok) {
        emit(state.copyWith(
          isLoading: false,
          failure: Failure(
            'Could not get your location. Enable GPS and try again.',
          ),
        ));
        return;
      }
      emit(state.copyWith(isLoading: false, isOnline: true));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        failure: Failure(extractApiException(e).message),
      ));
    }
  }

  Future<void> _onGoOfflineRequested(
    OnlineGoOfflineRequested event,
    Emitter<OnlineState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, failure: null));
    try {
      await _repository.goOffline();
      emit(state.copyWith(isLoading: false, isOnline: false));
    } catch (e) {
      // 409 = active job, can't go offline.
      emit(state.copyWith(
        isLoading: false,
        failure: Failure(extractApiException(e).message),
      ));
    }
  }

  Future<void> _onSummaryRequested(
    OnlineSummaryRequested event,
    Emitter<OnlineState> emit,
  ) async {
    final period = event.period ?? state.summaryPeriod;
    try {
      final summary = await _repository.getSummary(period: period);
      emit(state.copyWith(summary: summary, summaryPeriod: period));
    } catch (_) {
      // Silent — a failed summary refresh just leaves stale tiles on
      // screen rather than surfacing an error banner for a non-critical
      // read.
    }
  }
}
