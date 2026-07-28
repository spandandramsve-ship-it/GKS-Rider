/// Sentinel for `copyWith` methods so nullable fields can be explicitly
/// reset to `null` (as opposed to "not provided, keep the old value").
///
/// Usage in a `copyWith`:
/// ```dart
/// SomeState copyWith({Object? rider = unset}) => SomeState(
///   rider: identical(rider, unset) ? this.rider : rider as Rider?,
/// );
/// ```
class Unset {
  const Unset._();
}

const unset = Unset._();
