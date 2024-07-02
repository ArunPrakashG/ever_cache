import 'dart:async';

import 'exceptions/ever_operation_cancelled_exception.dart';

@Deprecated('This is not being used at the moment.')
class CancellableOperation<T> {
  final Completer<T?> _completer = Completer<T?>();
  bool _isCancelled = false;

  Future<T?> execute(
    Future<T> Function() fetch, {
    void Function()? onComputing,
    void Function()? onComputed,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    _isCancelled = false; // Reset the flag for each execution

    onComputing?.call();

    try {
      final value = await fetch();
      if (_isCancelled) {
        throw const EverOperationCancelledException();
      }

      onComputed?.call();
      return value;
    } catch (e, stackTrace) {
      if (!_isCancelled || e is! EverOperationCancelledException) {
        onError?.call(e, stackTrace);
      }

      if (!_completer.isCompleted) {
        _completer.completeError(e, stackTrace);
      }

      return _completer.future;
    }
  }

  void cancel() {
    if (_isCancelled) {
      return;
    }

    _isCancelled = true;
    if (!_completer.isCompleted) {
      _completer.completeError(
        const EverOperationCancelledException(),
        StackTrace.current,
      );
    }
  }
}
