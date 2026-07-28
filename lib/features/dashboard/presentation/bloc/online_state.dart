import 'package:equatable/equatable.dart';
import '../../../../core/failure.dart';
import '../../../../core/unset.dart';
import '../../data/models/rider_summary.dart';

class OnlineState extends Equatable {
  final bool isLoading;
  final Failure? failure;
  final bool isOnline;
  final RiderSummary? summary;
  final String summaryPeriod;

  const OnlineState({
    this.isLoading = false,
    this.failure,
    this.isOnline = false,
    this.summary,
    this.summaryPeriod = 'today',
  });

  OnlineState copyWith({
    bool? isLoading,
    Object? failure = unset,
    bool? isOnline,
    Object? summary = unset,
    String? summaryPeriod,
  }) {
    return OnlineState(
      isLoading: isLoading ?? this.isLoading,
      failure: identical(failure, unset) ? this.failure : failure as Failure?,
      isOnline: isOnline ?? this.isOnline,
      summary:
          identical(summary, unset) ? this.summary : summary as RiderSummary?,
      summaryPeriod: summaryPeriod ?? this.summaryPeriod,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, failure, isOnline, summary, summaryPeriod];
}
