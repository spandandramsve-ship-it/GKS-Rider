import 'package:equatable/equatable.dart';

sealed class OnlineEvent extends Equatable {
  const OnlineEvent();

  @override
  List<Object?> get props => [];
}

class OnlineGoOnlineRequested extends OnlineEvent {
  const OnlineGoOnlineRequested();
}

class OnlineGoOfflineRequested extends OnlineEvent {
  const OnlineGoOfflineRequested();
}

class OnlineSummaryRequested extends OnlineEvent {
  final String? period;

  const OnlineSummaryRequested({this.period});

  @override
  List<Object?> get props => [period];
}

/// Sets online status without an API call (session restore, 401 handler,
/// post-OTP-verify bootstrap, profile logout).
class OnlineStatusChanged extends OnlineEvent {
  final bool isOnline;

  const OnlineStatusChanged(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class OnlineErrorCleared extends OnlineEvent {
  const OnlineErrorCleared();
}
