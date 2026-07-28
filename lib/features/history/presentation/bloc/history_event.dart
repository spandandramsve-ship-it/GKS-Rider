import 'package:equatable/equatable.dart';

sealed class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Switch tabs (All / Ongoing / Completed / Failed) — resets pagination
/// and loads the first page for the new status filter. Also used for the
/// very first load (tab 0, "All") so that a fast tab switch right after
/// mount goes through the same `restartable()` transformer and correctly
/// supersedes it (this is what fixed the "Completed tab stuck empty"
/// race condition — see HistoryBloc).
class HistoryTabChanged extends HistoryEvent {
  final int tabIndex;
  final String? status;

  const HistoryTabChanged({required this.tabIndex, required this.status});

  @override
  List<Object?> get props => [tabIndex, status];
}

/// Scroll-triggered "load next page" for the current tab.
class HistoryPageRequested extends HistoryEvent {
  const HistoryPageRequested();
}

class HistoryPaymentsViewToggled extends HistoryEvent {
  final bool showPayments;

  const HistoryPaymentsViewToggled(this.showPayments);

  @override
  List<Object?> get props => [showPayments];
}
