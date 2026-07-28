import 'package:equatable/equatable.dart';

/// A one-shot error signal for bloc states.
///
/// Two [Failure]s are never `==` even with identical [message]s, so a
/// `BlocListener`'s `listenWhen` re-fires on every new failure — including
/// back-to-back failures with the same text (e.g. entering the same wrong
/// code twice), which a plain `String?` field would silently swallow.
class Failure extends Equatable {
  final String message;
  final Object _nonce = Object();

  Failure(this.message);

  @override
  List<Object?> get props => [_nonce];
}

/// Same one-shot nonce trick as [Failure], for neutral/success one-off
/// messages (e.g. "Delivery code sent") shown via a success-styled snackbar
/// rather than an error one.
class InfoMessage extends Equatable {
  final String message;
  final Object _nonce = Object();

  InfoMessage(this.message);

  @override
  List<Object?> get props => [_nonce];
}
