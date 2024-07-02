/// A class that encapsulates event callbacks for various cache operations.
///
/// This class allows clients of the cache to subscribe to different events
/// that occur during the lifecycle of cache operations. These events include
/// when a computation starts, completes, is invalidated, or encounters an error.
///
/// Example usage:
/// ```dart
/// EverEvents(
///   onComputing: () => print('Computation started'),
///   onComputed: () => print('Computation completed'),
///   onInvalidated: () => print('Cache invalidated'),
///   onError: (error, stackTrace) => print('Error: $error'),
/// )
/// ```
///
/// Callbacks:
/// - `onComputing`: Called when a computation starts.
/// - `onComputed`: Called when a computation successfully completes.
/// - `onInvalidated`: Called when the cache is invalidated, indicating that
///   the data needs to be recomputed.
/// - `onError`: Called when an error occurs during computation. It provides
///   the error object and stack trace for debugging purposes.
final class EverEvents {
  /// Constructs an instance of [EverEvents] with optional callback functions
  /// for different cache events.
  ///
  /// Parameters:
  /// - `onComputing`: A callback function that is called when computation starts.
  /// - `onComputed`: A callback function that is called when computation completes.
  /// - `onInvalidated`: A callback function that is called when the cache is invalidated.
  /// - `onError`: A callback function that is called when an error occurs during computation.
  const EverEvents({
    this.onComputing,
    this.onComputed,
    this.onInvalidated,
    this.onError,
  });

  /// A callback that is invoked when a computation starts.
  final void Function()? onComputing;

  /// A callback that is invoked when a computation successfully completes.
  final void Function()? onComputed;

  /// A callback that is invoked when the cache is invalidated.
  final void Function()? onInvalidated;

  /// A callback that is invoked when an error occurs during computation.
  /// It provides the error object and stack trace for debugging purposes.
  final void Function(Object error, StackTrace stackTrace)? onError;
}
