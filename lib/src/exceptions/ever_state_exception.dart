/// Represents an exception related to the state within the EverCache system.
///
/// This exception is thrown when an unexpected or invalid state is encountered
/// during the operation of the EverCache. It encapsulates a message that describes
/// the specific state issue encountered, providing more context for debugging and
/// error handling.
///
/// Example usage:
/// ```dart
/// throw EverStateException('Value is being evaluated.');
/// ```
///
/// The exception message should be descriptive enough to identify the nature of
/// the state issue, facilitating easier diagnosis and resolution of the problem.
final class EverStateException implements Exception {
  /// Constructs an [EverStateException] with a descriptive message.
  ///
  /// The `message` parameter should clearly describe the nature of the state
  /// error encountered, including any relevant details that might aid in
  /// troubleshooting the issue.
  ///
  /// Parameters:
  /// - `message`: A string describing the specific state error.
  const EverStateException(this.message);

  /// The message describing the state error.
  final String message;

  /// Returns a string representation of the exception.
  ///
  /// Overrides the [toString] method to return the `message` provided at
  /// construction. This ensures that when the exception is printed or logged,
  /// the descriptive error message is displayed, making it clear what state
  /// issue was encountered.
  ///
  /// Example output:
  /// ```
  /// Value is being evaluated.
  /// ```
  @override
  String toString() => 'A state exception occured: $message';
}
