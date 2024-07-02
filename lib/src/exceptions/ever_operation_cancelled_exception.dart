/// An exception that indicates a cancellation of an operation within the EverCache system.
///
/// This exception is thrown when an operation (such as a computation or a scheduled task)
/// is cancelled before it completes. This can be used to signal to the calling code that
/// the operation was intentionally stopped, rather than failing due to an error.
///
/// Example usage:
/// ```dart
/// try {
///   // Attempt an operation that may be cancelled
/// } on EverOperationCancelledException catch (e) {
///   print(e); // Prints: Operation cancelled
/// }
/// ```
///
/// This exception is particularly useful in scenarios where tasks are cancelled due to
/// changing conditions or in response to user actions, allowing for graceful handling
/// of such cancellations.
final class EverOperationCancelledException implements Exception {
  /// Constructs a [EverOperationCancelledException].
  ///
  /// Optionally includes the type of operation that was cancelled and a reason for the cancellation.
  ///
  /// Parameters:
  /// - `operation`: A string describing the operation that was cancelled (e.g., "data fetch", "long computation").
  /// - `reason`: A string providing more context on why the operation was cancelled.
  const EverOperationCancelledException({this.operation, this.reason});

  /// The type of operation that was cancelled.
  final String? operation;

  /// The reason for the cancellation.
  final String? reason;

  /// Returns a string representation of the exception.
  ///
  /// Overrides the [toString] method to provide a more descriptive message
  /// when the exception is converted to a string. This can be helpful for
  /// logging or displaying an error message to the user.
  @override
  String toString() {
    var message = 'Operation cancelled';

    if (operation != null) {
      message += ' during $operation';
    }

    if (reason != null) {
      message += ' due to: $reason';
    }

    return message;
  }
}
